FROM alpine:3.23@sha256:8169a308ae899f69285e7214b3c2de1c1f0f091ab228b87a58040c49d8cc2b0d
ADD loadgen /
ADD stories.json /
EXPOSE 80
ENTRYPOINT  [ "/loadgen" ]
CMD [ "http://app" ]
