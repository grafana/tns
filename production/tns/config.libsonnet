{
  _config+:: {
    tns+: {
      jaeger: {
        host: 'grafana-agent.default.svc.cluster.local',
        tags: 'cluster=tns,namespace=tns',
        sampler_type: 'const',
        sampler_param: '1',
      },
    },
  },

  _images+:: {
    tns_app: 'grafana/tns-app:cad1c20@sha256:0627e75b80d592584670b4850c64894edb2aee089e6004d7bc10b13194dac86a',
    loadgen: 'grafana/tns-loadgen:cad1c20@sha256:418afcf181df189fe55167bc5190ff024b015c32589d71a56d41db78c5fed063',
    db: 'grafana/tns-db:cad1c20@sha256:e2d95dd34d6bafd2a68f6614216d82d4d46af8d8b9f7baa3857287d53e40b5f7',
  },
}
