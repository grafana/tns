FROM alpine:3.24@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf
ADD loadgen /
ADD stories.json /
EXPOSE 80
ENTRYPOINT  [ "/loadgen" ]
CMD [ "http://app" ]
