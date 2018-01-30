FROM nginx

COPY nginx.conf /etc/nginx/nginx.conf
COPY fix-nginx-conf.sh /fix-nginx-conf.sh

VOLUME /hypervisor_etc

EXPOSE 80

CMD /fix-nginx-conf.sh; \
    nginx