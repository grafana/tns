local tns = import 'tns/tns.libsonnet';

tns {
  _config+:: {
    namespace: 'tns-cloud',
    tns+: {
      jaeger+: {
        host: 'grafana-agent-traces.default.svc.cluster.local',
        tags: 'cluster=cloud,namespace=tns-cloud',
      },
    },
  },
}
