local prometheus = import 'prometheus-ksonnet/prometheus-ksonnet.libsonnet';
local promtail = import 'promtail/promtail.libsonnet';
local tns_mixin = import 'tns-mixin/mixin.libsonnet';

prometheus + promtail + {
  // A known data source UID is necessary to configure the Loki datasource such that users can pivot
  // from Loki logs to Jaeger traces on traceID.
  local service = $.core.v1.service,
  _images+:: {
    grafana: 'grafana/grafana:8.2.2',
    prometheus: 'prom/prometheus:v2.30.3',
  },
  _config+:: {
    namespace: 'default',
    cluster_name: 'docker',
    admin_services+: [
      { title: 'TNS Demo', path: 'tns-demo', url: 'http://app.tns.svc.cluster.local/', subfilter: true },
    ],
    promtail_config+: {
      clients: [{
        username:: '',
        password:: '',
        scheme:: 'http',
        hostname:: 'loki.loki.svc.cluster.local:3100',
        external_labels: {
          cluster: 'tns',
        },
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

  nginx_service+:
    service.mixin.spec.withType('ClusterIP') +
    service.mixin.spec.withPorts({
      port: 80,
      targetPort: 80,
    }),

  grafana_config+:: {
    sections+: {
      feature_toggles+: {
        enable: 'traceToLogs',
      },
    },
  },

  grafana_datasource_config_map+:
    $.core.v1.configMap.withDataMixin({
      'datasources.yml': $.util.manifestYaml({
        apiVersion: 1,
        datasources: [
          {
            name: 'Loki',
            type: 'loki',
            access: 'proxy',
            url: 'http://loki.loki.svc.cluster.local:3100',
            isDefault: false,
            version: 1,
            editable: false,
            basicAuth: false,
            jsonData: {
              maxLines: 1000,
              derivedFields: [{
                matcherRegex: '(?:traceID|trace_id)=(\\w+)',
                name: 'TraceID',
                url: '$${__value.raw}',
                datasourceUid: 'tempo',
              }],
            },
          },
          {
            name: 'prometheus-exemplars',
            type: 'prometheus',
            access: 'proxy',
            url: 'http://prometheus.default.svc.cluster.local/prometheus/',
            isDefault: false,
            version: 1,
            editable: false,
            basicAuth: false,
            jsonData: {
              disableMetricsLookup: false,
              httpMethod: 'POST',
              exemplarTraceIdDestinations: [{
                name: 'traceID',
                datasourceUid: 'tempo'
              }],
            },
          },
          {
            name: 'Tempo',
            type: 'tempo',
            access: 'browser',
            uid: 'tempo',
            url: 'http://tempo.tempo.svc.cluster.local/',
            isDefault: false,
            version: 1,
            editable: false,
            basicAuth: false,
            jsonData: {
              tracesToLogs: {
                datasourceUid: 'Loki',
                tags: ['job', 'instance', 'pod', 'namespace']
              }
            }
          },
        ],
      }),
    }),

  local ingress = $.extensions.v1beta1.ingress,
  local ingressRule = $.extensions.v1beta1.ingressRule,
  local httpIngressPath = $.extensions.v1beta1.httpIngressPath,
  ingress: ingress.new() +
           ingress.mixin.metadata.withName('ingress')
           + ingress.mixin.metadata.withAnnotationsMixin({
             'ingress.kubernetes.io/ssl-redirect': 'false',
           })
           + ingress.mixin.spec.withRules([
             ingressRule.mixin.http.withPaths(
               httpIngressPath.withPath('/') +
               httpIngressPath.backend.withServiceName('nginx') +
               httpIngressPath.backend.withServicePort(80)
             ),
           ])
  ,
  mixins+:: {
    tns_demo: tns_mixin,
  },
}
