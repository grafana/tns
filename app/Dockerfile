FROM alpine:3.9
ADD app /
ADD index.html.tmpl /
EXPOSE 80
ENTRYPOINT [ "/app" ]
CMD [ "http://db" ]
