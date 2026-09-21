FROM alpine:3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6
ADD app /
ADD index.html.tmpl /
EXPOSE 80
ENTRYPOINT [ "/app" ]
CMD [ "http://db" ]
