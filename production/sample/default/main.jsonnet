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
    service.mixin.spec.withType('NodePort') +
    service.mixin.spec.withPorts({
      nodePort: 30040,
      port: 8080,
      targetPort: 80,
    }),

  grafana_datasource_config_map+:
    $.core.v1.configMap.withDataMixin({
      'loki.yml': $.util.manifestYaml({
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
          jsonData: {
            derivedFields: [{
              datasourceName: 'Jaeger',
              matcherRegex: 'traceID=(\\w+)',
              name: 'TraceID',
              url: '/jaeger/trace/$${__value.raw}',
            }],
          },
        }],
      }),
    })
    + $.core.v1.configMap.withDataMixin({
      'jaeger.yml': $.util.manifestYaml({
        apiVersion: 1,
        datasources: [{
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
}
