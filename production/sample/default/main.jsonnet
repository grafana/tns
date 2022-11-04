local gragent = import 'grafana-agent/v2/main.libsonnet';
local k = import 'ksonnet-util/kausal.libsonnet';
local tns_mixin = import 'tns-mixin/mixin.libsonnet';

(import 'ksonnet-util/kausal.libsonnet') +
(import 'prometheus-ksonnet/grafana/grafana.libsonnet') +
(import 'nginx-directory/directory.libsonnet') +
{
  _images+:: {
    grafana: 'grafana/grafana:9.2.3',
  },
  _config+:: {
    namespace: 'default',
    cluster_name: 'docker',
    cluster_dns_tld: 'local.',
    cluster_dns_suffix: 'cluster.' + self.cluster_dns_tld,
    grafana_namespace: self.namespace,
    grafana_root_url: 'http://localhost:8080/grafana',
    admin_services+: [
      { title: 'TNS Demo', path: 'tns-demo', url: 'http://app.tns.svc.cluster.local/', subfilter: true },
    ],
  },

  local configMap = k.core.v1.configMap,
  local containerPort = k.core.v1.containerPort,
  local httpIngressPath = k.networking.v1.httpIngressPath,
  local ingress = k.networking.v1.ingress,
  local ingressRule = k.networking.v1.ingressRule,
  local service = k.core.v1.service,

  // Create a Grafana Agent daemon set to collect metrics, logs, and traces
  //
  // Metrics, logs, and traces are enriched with Kubernetes metadata. Metrics and logs from
  // the local Kubernetes node are collected while traces use a push model (clients send traces
  // to the agent).
  //
  // The agent runs as a privileged container and as root since this is a requirement of
  // collecting logs. The path /var/log on the Kubernetes node is mounted into the container
  // along with /var/lib/docker/containers.
  //
  // A service for the agent is created so that other pods within the cluster can send traces
  // to the agent.
  daemonset_agent:
    gragent.new(name='grafana-agent', namespace='default') +
    gragent.withDaemonSetController() +
    gragent.withService({}) +
    gragent.withLogVolumeMounts({}) +
    gragent.withLogPermissions({}) +
    gragent.withConfigHash(true) +
    gragent.withPortsMixin([
      // Create container ports for the various ways that the agent can collect traces.
      containerPort.new('thrift-compact', 6831) + containerPort.withProtocol('UDP'),
      containerPort.new('thrift-binary', 6832) + containerPort.withProtocol('UDP'),
      containerPort.new('thrift-http', 14268),
      containerPort.new('thrift-grpc', 14250),
    ]) +
    gragent.withAgentConfig({
      server: {
        log_level: 'debug',
      },
      metrics+: {
        global+: {
          scrape_interval: '15s',
          external_labels: {
            cluster: 'tns',
          },
        },
        wal_directory: '/tmp/agent/prom',
        configs: [
          {
            name: 'kubernetes-metrics',
            remote_write: [
              {
                url: 'http://mimir.mimir.svc.cluster.local/api/v1/push',
                send_exemplars: true,
              },
            ],
            scrape_configs: gragent.newKubernetesMetrics({}),
          },
        ],
      },
      logs+: {
        positions_directory: '/tmp/agent/loki',
        configs: [{
          name: 'kubernetes-logs',
          clients: [{
            url: 'http://loki.loki.svc.cluster.local:3100/loki/api/v1/push',
            external_labels: {
              cluster: 'tns',
            },
          }],
          scrape_configs: gragent.newKubernetesLogs({}),
        }],
      },
      traces+: {
        configs: [{
          name: 'kubernetes-traces',
          receivers: {
            jaeger: {
              protocols: {
                grpc: null,
                thrift_binary: null,
                thrift_compact: null,
                thrift_http: null,
              },
            },
          },
          remote_write: [{
            endpoint: 'tempo.tempo.svc.cluster.local:55680',
            insecure: true,
            retry_on_failure: {
              enabled: true,
            },
          }],
          scrape_configs: gragent.newKubernetesTraces({}),
        }],
      },
    }),

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
    configMap.withDataMixin({
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
            name: 'Mimir',
            type: 'prometheus',
            access: 'proxy',
            url: 'http://mimir.mimir.svc.cluster.local/prometheus',
            isDefault: true,
            version: 1,
            editable: false,
            basicAuth: false,
            jsonData: {
              disableMetricsLookup: false,
              httpMethod: 'POST',
              exemplarTraceIdDestinations: [{
                name: 'traceID',
                datasourceUid: 'tempo',
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
                tags: ['job', 'instance', 'pod', 'namespace'],
              },
            },
          },
        ],
      }),
    }),

  ingress: ingress.new('ingress') +
           ingress.mixin.metadata.withAnnotationsMixin({
             'ingress.kubernetes.io/ssl-redirect': 'false',
           })
           + ingress.mixin.spec.withRules([
             ingressRule.mixin.http.withPaths(
               httpIngressPath.withPath('/') +
               httpIngressPath.withPathType('ImplementationSpecific') +
               httpIngressPath.backend.service.withName('nginx') +
               httpIngressPath.backend.service.port.withNumber(80)
             ),
           ])
  ,
  mixins+:: {
    tns_demo: tns_mixin,
  },
}
