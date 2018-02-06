#!/bin/bash

# Check parameters
test $# = 1 || { echo "Need 1 parameter: The keypair name to use for created VMs"; exit 1; }
KEY_PAIR="$1"
STACK="cc-docker"

# Create the stack using server-landscape.yaml and defining all necessary parameters.
# Important: Use $STACK as the stack name, and $KEY_PAIR as the key pair.

openstack stack create -t ./server-landscape.yaml $STACK --wait \
    --parameter image=ubuntu-16.04 \
    --parameter key_pair=$KEY_PAIR \
    --parameter external_net=tu-internal \
    --parameter flavor="Cloud Computing" \
    --parameter zone="Cloud Computing"
