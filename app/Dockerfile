FROM alpine:3.23@sha256:fd791d74b68913cbb027c6546007b3f0d3bc45125f797758156952bc2d6daf40
ADD app /
ADD index.html.tmpl /
EXPOSE 80
ENTRYPOINT [ "/app" ]
CMD [ "http://db" ]
