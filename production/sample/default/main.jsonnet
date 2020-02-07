local prometheus = import 'prometheus-ksonnet/prometheus-ksonnet.libsonnet';
local promtail = import 'promtail/promtail.libsonnet';
local tns_mixin = import 'tns-mixin/mixin.libsonnet';

prometheus + promtail + tns_mixin + {
  local service = $.core.v1.service,
  _config+:: {
    namespace: 'default',
    cluster_name: 'docker',
    admin_services+: [
      { title: 'TNS Demo', path: 'tns-demo', url: 'http://app.tns.svc.cluster.local/', subfilter: true },
      { title: 'Jaeger', path: 'jaeger', url: 'http://jaeger.jaeger.svc.cluster.local:16686/jaeger/' },
    ],
    promtail_config+: {
      clients: [{
        username:: '',
        password:: '',
        scheme:: 'http',
        hostname:: 'loki.loki.svc.cluster.local:3100',
        external_labels: {},
      }],
      pipeline_stages+: [
        {
          regex: {
            expression: '\\((?P<status_code>\\d{3})\\)',
          },
        },
        {
          labels: {
            status_code: '',
          },
        },
        {
          regex: {
            expression: '(level|lvl|severity)=(?P<level>\\w+)',
          },
        },
        {
          labels: {
            level: '',
          },
        },
      ],
    },
  },

  // Expose the nginx admin frontend on port 30040 of the node.
  nginx_service+:
    service.mixin.spec.withType('ClusterIP') +
    service.mixin.spec.withPorts({
      port: 80,
      targetPort: 80,
    }),

  grafana_datasource_config_map+:
    $.core.v1.configMap.withDataMixin({
      'datasources.yml': $.util.manifestYaml({
        apiVersion: 1,
        datasources: [{
          name: 'Loki',
          type: 'loki',
          access: 'proxy',
          url: 'http://loki.loki.svc.cluster.local:3100',
          isDefault: false,
          version: 1,
          editable: false,
          basicAuth: false,
/*          jsonData: {
            maxLines: 1000,
            derivedFields: [{
              datasourceName: 'Jaeger',
              matcherRegex: 'traceID=(\\w+)',
              name: 'TraceID',
              url: '/jaeger/trace/$${__value.raw}',
            }],
          },*/
        },
        {
          name: 'Jaeger',
          type: 'jaeger',
          access: 'browser',
          url: 'http://jaeger.jaeger.svc.cluster.local:16686',
          isDefault: false,
          version: 1,
          editable: false,
          basicAuth: false,
        }],
      }),
    }),

    local ingress = $.extensions.v1beta1.ingress,
    ingress: ingress.new() +
      ingress.mixin.metadata.withName('ingress')
      + ingress.mixin.metadata.withAnnotationsMixin({
          'ingress.kubernetes.io/ssl-redirect': 'false',
        })
      + ingress.mixin.spec.withRules([
          ingress.mixin.specType.rulesType.mixin.http.withPaths(
              ingress.mixin.spec.rulesType.mixin.httpType.pathsType.withPath('/') +
              ingress.mixin.specType.mixin.backend.withServiceName('nginx') +
              ingress.mixin.specType.mixin.backend.withServicePort(80)
          )
        ])
      ,
}
