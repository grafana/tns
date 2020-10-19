local tempo = import 'tempo/tempo.libsonnet';

tempo {
  local configmap = $.core.v1.configMap,
  local container = $.core.v1.container,

  _images+:: {
    tempo: 'annanay25/tempo:c136583e',
    tempo_query: 'annanay25/tempo-query:c136583e',
    tempo_vulture: 'annanay25/tempo-vulture:c136583e',
    grafana_agent: 'grafana/agent:master-b10f023',
  },

  _config+:: {
    namespace: 'tempo',
    receivers: {
        jaeger: {
            protocols: {
                thrift_compact: {
                    endpoint: '0.0.0.0:6831',
                },
            },
        },
        otlp: {
          protocols: {
            grpc: {
              endpoint: '0.0.0.0:55680',
            },
          },
        },
    },
  },

  agent_config:: {
    server: {
      http_listen_port: 8888,
      log_level: 'info',
    },

    tempo: {
      receivers: {
        jaeger: {
          protocols: {
            thrift_compact: null,
            grpc: null,
          },
        },
      },

      remote_write: {
        endpoint: 'tempo.tempo.svc.cluster.local:55680',
        insecure: true,
        batch: {
          timeout: '5s',
          send_batch_size: 1000,
        },
        queue: {
          retry_on_failure: false,
        },
      },

      scrape_configs: [
        {
          bearer_token_file: '/var/run/secrets/kubernetes.io/serviceaccount/token',
          job_name: 'kubernetes-pods',
          kubernetes_sd_configs: [
            {
              role: 'pod',
            },
          ],
          relabel_configs: [
            {
              action: 'replace',
              source_labels: [
                '__meta_kubernetes_namespace',
              ],
              target_label: 'namespace',
            },
            {
              action: 'replace',
              source_labels: [
                '__meta_kubernetes_pod_name',
              ],
              target_label: 'pod',
            },
            {
              action: 'replace',
              source_labels: [
                '__meta_kubernetes_pod_container_name',
              ],
              target_label: 'container',
            },
          ],
          tls_config: {
            ca_file: '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
            insecure_skip_verify: false,
          },
        },
      ],
    },
  },

  // https://github.com/open-telemetry/opentelemetry-collector#configuration
  agent_configmap:
    configmap.new('jaeger-agent') +
    configmap.withData({
      'config.yaml': $.util.manifestYaml($.agent_config),
    }),

  tempo_container+::
    container.withEnv([
      container.envType.new('JAEGER_AGENT_PORT', ''),
    ]) +
    container.withPortsMixin([
      $.core.v1.containerPort.new('otlp', 55680) +
      $.core.v1.containerPort.withProtocol('TCP'),
    ]),

  tempo_query_container+::
    container.withEnv([
      container.envType.new('JAEGER_AGENT_PORT', ''),
    ]),

  agent_container::
    container.new('agent-collector', $._images.grafana_agent) +
    container.withPorts([
      $.core.v1.containerPort.new('thrift-compact', 6831) +
      $.core.v1.containerPort.withProtocol('UDP'),
      $.core.v1.containerPort.new('prom-metrics', 8888) +
      $.core.v1.containerPort.withProtocol('TCP'),
      $.core.v1.containerPort.new('sampling', 5778) +
      $.core.v1.containerPort.withProtocol('TCP'),
    ]) +
    container.withArgs([
      '--config.file=/etc/agent/config.yaml',
    ]) +
    $.util.resourcesRequests('200m', '200Mi') +
    $.util.resourcesLimits(null, '400Mi'),

  local deployment = $.apps.v1.deployment,
  local volume = $.core.v1.volume,

  jaeger_agent_deployment:
    deployment.new('jaeger-agent', 1, [
      $.agent_container,
    ]) +
    deployment.mixin.spec.template.metadata.withAnnotations({
      strategies_hash: std.md5(std.toString($.agent_config)),
    }) +
    $.util.configVolumeMount('jaeger-agent', '/etc/agent'),

  jaeger_agent_service:
    $.util.serviceFor($.jaeger_agent_deployment),
}