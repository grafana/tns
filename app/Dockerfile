FROM alpine:3.23@sha256:f3d55900449227ae9e237ede521e7b665d53a253b42065ba90b9db9275e198ad
ADD app /
ADD index.html.tmpl /
EXPOSE 80
ENTRYPOINT [ "/app" ]
CMD [ "http://db" ]
