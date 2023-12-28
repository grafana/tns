local ksm = import 'github.com/grafana/jsonnet-libs/kube-state-metrics/main.libsonnet';
local node_exporter = import 'github.com/grafana/jsonnet-libs/node-exporter/main.libsonnet';
local gragent = import 'grafana-agent/v2/main.libsonnet';
local k = import 'ksonnet-util/kausal.libsonnet';
local tk = import 'tk';
local tns_mixin = import 'tns-mixin/mixin.libsonnet';

{
  _config+:: {
    apiKey: error '$._config.apiKey must be defined',
    clusterName: 'tns-cluster',
    prometheus: {
      endpoint: error '$._config.prometheus.endpoint must be defined',
      user: error '$._config.prometheus.user must be defined',
    },
    loki: {
      endpoint: error '$._config.loki.endpoint must be defined',
      user: error '$._config.tempo.user must be defined',
    },
    tempo: {
      endpoint: error '$._config.tempo.endpoint must be defined',
      user: error '$._config.tempo.user must be defined',
    },
  },

  local configMap = k.core.v1.configMap,
  local containerPort = k.core.v1.containerPort,
  local httpIngressPath = k.networking.v1.httpIngressPath,
  local ingress = k.networking.v1.ingress,
  local ingressRule = k.networking.v1.ingressRule,
  local service = k.core.v1.service,
  local namespace = k.core.v1.namespace,

  ns: namespace.new(tk.env.spec.namespace),
  ksm: ksm.new(tk.env.spec.namespace),
  node_exporter:
    node_exporter.new()
    + node_exporter.mountRoot(),

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
    gragent.new(name='grafana-agent', namespace=tk.env.spec.namespace) +
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
          scrape_interval: '60s',  // limit to 1DPM
          external_labels: {
            cluster: $._config.clusterName,
          },
        },
        wal_directory: '/tmp/agent/prom',
        configs: [
          {
            name: 'kubernetes-metrics',
            remote_write: [
              {
                url: $._config.prometheus.endpoint,
                basic_auth: {
                  username: std.toString($._config.prometheus.user),
                  password: $._config.apiKey,
                },
                send_exemplars: true,
              },
            ],
            scrape_configs: std.map(function(c) c {
              // Rename jobs for k8s-monitoring compat
              job_name: if std.endsWith(c.job_name, 'cadvisor') then 'integrations/kubernetes/cadvisor' else
                if std.endsWith(c.job_name, 'kubelet') then 'integrations/kubernetes/kubelet' else
                  if std.endsWith(c.job_name, 'kube-state-metrics') then 'integrations/kubernetes/kube-state-metrics' else
                    if std.endsWith(c.job_name, 'node-exporter') then 'integrations/node_exporter' else c.job_name,
            }, gragent.newKubernetesMetrics({
              ksm_namespace: tk.env.spec.namespace,
              node_exporter_namespace: tk.env.spec.namespace,
            })),
          },
        ],
      },
      logs+: {
        positions_directory: '/tmp/agent/loki',
        configs: [{
          name: 'kubernetes-logs',
          clients: [{
            url: $._config.loki.endpoint,
            basic_auth: {
              username: std.toString($._config.loki.user),
              password: $._config.apiKey,
            },
            external_labels: {
              cluster: $._config.clusterName,
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
            endpoint: $._config.tempo.endpoint,
            retry_on_failure: {
              enabled: true,
            },
            basic_auth: {
              username: std.toString($._config.tempo.user),
              password: $._config.apiKey,
            },
          }],
          scrape_configs: gragent.newKubernetesTraces({}),
        }],
      },
    }),
} + (import 'config.jsonnet')
