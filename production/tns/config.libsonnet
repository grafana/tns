{
  _config+:: {
    tns+: {
      jaeger: {
        host: 'alloy.default.svc.cluster.local',
        tags: 'cluster=tns,namespace=tns',
        sampler_type: 'const',
        sampler_param: '1',
      },
    },
  },

  _images+:: {
    tns_app: 'grafana/tns-app:latest',
    loadgen: 'grafana/tns-loadgen:latest',
    db: 'grafana/tns-db:latest',
  },
}
