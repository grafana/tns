local tns = import 'tns/tns.libsonnet';

tns {
  _config+:: {
    namespace: 'tns-cloud',
    tns+: {
      jaeger+: {
        host: 'grafana-agent.grafana-cloud.svc.cluster.local',
        tags: 'cluster=tns-cluster,namespace=tns-cloud',
      },
    },
  },
}
