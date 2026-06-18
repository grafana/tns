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
    tns_app: 'grafana/tns-app:ae5c2f3@sha256:9891c964d6d76d7504dd72732181e73ad04b774d3b8bb9d558afa809a98c5f65',
    loadgen: 'grafana/tns-loadgen:ae5c2f3@sha256:ccfcb20a3551349fa7a79dbc7848e75729c4f149b56258e7bd7846451152cf2f',
    db: 'grafana/tns-db:ae5c2f3@sha256:cf5136b25e6b09024f50681e57e3c11564c1f37c46714ef070f714d9347fa85b',
  },
}
