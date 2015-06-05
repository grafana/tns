FROM gliderlabs/alpine:3.1
MAINTAINER Weaveworks Inc <help@weave.works>
COPY nginx.conf entrypoint.sh /
RUN apk --update add nginx dnsmasq
RUN mkdir -p /tmp/nginx/client-body
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log
EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
