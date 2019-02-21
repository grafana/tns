FROM alpine:3.9
ADD loadgen /
ADD stories.json /
EXPOSE 80
ENTRYPOINT  [ "/loadgen" ]
CMD [ "http://app" ]
