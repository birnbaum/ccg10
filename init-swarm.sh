#!/bin/bash

# This matches the STACK name in create-stack.sh
STACK="cc-docker"

# Obtain information from OpenStack. It is important that the last two variables are named LC_* (see last comment in this script).
# The three variables correspond to output variables of the server-landscape.yaml template.
echo "Obtainining information about stack ${STACK}..."
export MASTER_FLOATING=$(openstack stack output show cc-docker floating_ip -c output_value -f value)
export LC_MASTER_PRIVATE=$(openstack stack output show cc-docker private_ip -c output_value -f value)
export LC_BACKEND_IPS=$(openstack stack output show cc-docker backend_ips -c output_value -f value | jq -r @tsv)

# Copy docker-compose files to the frontend server
sudo scp ./frontend/docker-compose.yml ubuntu@$MASTER_FLOATING:/docker-compose-frontend.yml

# Define a multi-line variable containing the script to be executed on the frontend machine.
# The tasks of this script:
# - Initialize the docker swarm leader. The frontend VM will play the role of the leader.
# - Obtain a token to join the docker swarm
# - Connect to the backend machines and make them join the swarm
# - Launch the backend and frontend stacks using the docker-compose files copied earlier
read -d '' INIT_SCRIPT <<'xxxxxxxxxxxxxxxxx'

# Make sure Docker is running
sudo docker ps &> /dev/null || sudo service docker restart

# Initialize the Docker swarm
sudo docker swarm init --advertise-addr $LC_MASTER_PRIVATE

# Make sure the SSH connection to the backend servers works without user interaction
SSHOPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes"
ssh-keyscan $LC_BACKEND_IPS > ~/.ssh/known_hosts

# Obtain a token that can be used to join the swarm as a worker
TOKEN=$(sudo docker swarm join-token -q worker)

# Prepare the script to execute on the backends to join the docker swarm.
# First make sure that docker is running properly...
backend_setup_1="{ sudo docker ps &> /dev/null || sudo service docker restart; }"

# ... then join the docker swarm on the frontend server
backend_setup_2="sudo docker swarm join --token "$TOKEN" $LC_MASTER_PRIVATE:2377"

# Connect to the backend servers and make them join the swarm
for i in $LC_BACKEND_IPS; do ssh $SSHOPTS ubuntu@$i "$backend_setup_1 && $backend_setup_2"; done

# Launch the backend stack
# sudo -E docker [[TODO]]

# Launch the frontend stack
export CC_BACKEND_SERVERS="$LC_BACKEND_IPS"
# sudo -E docker [[TODO]]

xxxxxxxxxxxxxxxxx

# Print the script for debugging purposes
echo -e "\nRunning the following script on $MASTER_FLOATING:\n\n$INIT_SCRIPT\n"

# Execute the script on the frontend server. Make sure to pass along the two variables obtained from OpenStack above.
# Those variables are named LC_* because the default sshd config allows sending variables named like this.
ssh -o SendEnv="LC_MASTER_PRIVATE LC_BACKEND_IPS" -A ubuntu@$MASTER_FLOATING "$INIT_SCRIPT"

echo
echo "If everything worked so far, you can execute the following to test your setup:"
echo "python3 Scripts/test-deployment.py $MASTER_FLOATING"
