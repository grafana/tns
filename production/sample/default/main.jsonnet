local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local gragent = import 'grafana-agent/v2/main.libsonnet';
local k = import 'ksonnet-util/kausal.libsonnet';
local tns_mixin = import 'tns-mixin/mixin.libsonnet';
local helm = tanka.helm.new(std.thisFile);

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

  // Deploys Grafana Alloy to collect metrics, logs, and traces
  //
  // Metrics, logs, and traces are enriched with Kubernetes metadata. Metrics and logs from
  // the local Kubernetes node are collected while traces use a push model (clients send traces
  // to the agent).

  alloy_deployment: helm.template('alloy', '../../vendor/github.com/grafana/alloy/operations/helm/charts/alloy', {
    namespace: 'default',
    values: {
      alloy: {
        extraPorts: [
          {
            name: 'thrift-compact',
            port: 6831,
            targetPort: 6831,
            protocol: 'UDP',
          },
          {
            name: 'thrift-binary',
            port: 6832,
            targetPort: 6832,
            protocol: 'UDP',
          },
          {
            name: 'thrift-http',
            port: 14268,
            targetPort: 14268,
            protocol: 'TCP',
          },
          {
            name: 'thrift-grpc',
            port: 14250,
            targetPort: 14250,
            protocol: 'TCP',
          },
        ],
        configMap: {
          content: |||
            discovery.kubernetes "service" {
            	role = "service"
            }

            discovery.kubernetes "pod" {
            	role = "pod"
            }

            discovery.kubernetes "kube_system" {
            	role = "pod"

            	namespaces {
            		names = ["kube-system"]
            	}
            }

            discovery.kubernetes "node" {
            	role = "node"
            }

            discovery.relabel "service" {
            	targets = discovery.kubernetes.service.targets

            	rule {
            		source_labels = ["__meta_kubernetes_service_label_component"]
            		regex         = "apiserver"
            		action        = "keep"
            	}
            }

            discovery.relabel "pod" {
            	targets = discovery.kubernetes.pod.targets

            	rule {
            		source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
            		regex         = "false"
            		action        = "drop"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_container_port_name"]
            		regex         = ".*-metrics"
            		action        = "keep"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scheme"]
            		regex         = "(https?)"
            		target_label  = "__scheme__"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
            		regex         = "(.+)"
            		target_label  = "__metrics_path__"
            	}

            	rule {
            		source_labels = ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"]
            		regex         = "(.+?)(\\:\\d+)?;(\\d+)"
            		target_label  = "__address__"
            		replacement   = "$1:$3"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_label_name"]
            		regex         = ""
            		action        = "drop"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_namespace", "__meta_kubernetes_pod_label_name"]
            		separator     = "/"
            		target_label  = "job"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_namespace"]
            		target_label  = "namespace"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_name"]
            		target_label  = "pod"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_container_name"]
            		target_label  = "container"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_name", "__meta_kubernetes_pod_container_name", "__meta_kubernetes_pod_container_port_name"]
            		separator     = ":"
            		target_label  = "instance"
            	}

            	rule {
            		regex       = "__meta_kubernetes_pod_annotation_prometheus_io_param_(.+)"
            		replacement = "__param_$1"
            		action      = "labelmap"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_phase"]
            		regex         = "Succeeded|Failed"
            		action        = "drop"
            	}
            }

            discovery.relabel "kube_state_metrics" {
            	targets = discovery.kubernetes.kube_system.targets

            	rule {
            		source_labels = ["__meta_kubernetes_pod_label_name"]
            		regex         = "kube-state-metrics"
            		action        = "keep"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_name", "__meta_kubernetes_pod_container_name", "__meta_kubernetes_pod_container_port_name"]
            		separator     = ":"
            		target_label  = "instance"
            	}
            }

            discovery.relabel "node_exporter" {
            	targets = discovery.kubernetes.kube_system.targets

            	rule {
            		source_labels = ["__meta_kubernetes_pod_label_name"]
            		regex         = "node-exporter"
            		action        = "keep"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_node_name"]
            		target_label  = "instance"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_namespace"]
            		target_label  = "namespace"
            	}
            }

            discovery.relabel "kubelet" {
            	targets = discovery.kubernetes.node.targets

            	rule {
            		target_label = "__address__"
            		replacement  = "kubernetes.default.svc.cluster.local:443"
            	}

            	rule {
            		target_label = "__scheme__"
            		replacement  = "https"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_node_name"]
            		regex         = "(.+)"
            		target_label  = "__metrics_path__"
            		replacement   = "/api/v1/nodes/$1/proxy/metrics"
            	}
            }

            discovery.relabel "cadvisor" {
            	targets = discovery.kubernetes.node.targets

            	rule {
            		target_label = "__address__"
            		replacement  = "kubernetes.default.svc.cluster.local:443"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_node_name"]
            		regex         = "(.+)"
            		target_label  = "__metrics_path__"
            		replacement   = "/api/v1/nodes/$1/proxy/metrics/cadvisor"
            	}
            }

            prometheus.scrape "default_kubernetes" {
            	targets         = discovery.relabel.service.output
            	forward_to      = [prometheus.relabel.service.receiver]
            	job_name        = "default/kubernetes"
            	scrape_interval = "15s"
            	scheme          = "https"

            	authorization {
            		type             = "Bearer"
            		credentials_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
            	}

            	tls_config {
            		ca_file     = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
            		server_name = "kubernetes"
            	}
            }

            prometheus.scrape "pods" {
            	targets         = discovery.relabel.pod.output
            	forward_to      = [prometheus.remote_write.kubernetes_metrics.receiver]
            	job_name        = "kubernetes-pods"
            	scrape_interval = "15s"
            }

            prometheus.scrape "kube_state_metrics" {
            	targets         = discovery.relabel.kube_state_metrics.output
            	forward_to      = [prometheus.remote_write.kubernetes_metrics.receiver]
            	job_name        = "kube-system/kube-state-metrics"
            	scrape_interval = "15s"
            }

            prometheus.scrape "node_exporter" {
            	targets         = discovery.relabel.node_exporter.output
            	forward_to      = [prometheus.remote_write.kubernetes_metrics.receiver]
            	job_name        = "kube-system/node-exporter"
            	scrape_interval = "15s"
            }

            prometheus.scrape "kubelet" {
            	targets         = discovery.relabel.kubelet.output
            	forward_to      = [prometheus.remote_write.kubernetes_metrics.receiver]
            	job_name        = "kube-system/kubelet"
            	scrape_interval = "15s"

            	authorization {
            		type             = "Bearer"
            		credentials_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
            	}

            	tls_config {
            		ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
            	}
            }

            prometheus.scrape "cadvisor" {
            	targets         = discovery.relabel.cadvisor.output
            	forward_to      = [prometheus.relabel.cadvisor.receiver]
            	job_name        = "kube-system/cadvisor"
            	scrape_interval = "15s"
            	scheme          = "https"

            	authorization {
            		type             = "Bearer"
            		credentials_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
            	}

            	tls_config {
            		ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
            	}
            }

            prometheus.relabel "service" {
            	forward_to = [prometheus.remote_write.kubernetes_metrics.receiver]

            	rule {
            		source_labels = ["__name__"]
            		regex         = "workqueue_queue_duration_seconds_bucket|process_cpu_seconds_total|process_resident_memory_bytes|workqueue_depth|rest_client_request_duration_seconds_bucket|workqueue_adds_total|up|rest_client_requests_total|apiserver_request_total|go_goroutines"
            		action        = "keep"
            	}
            }

            prometheus.relabel "cadvisor" {
            	forward_to = [prometheus.remote_write.kubernetes_metrics.receiver]

            	rule {
            		source_labels = ["__name__", "image"]
            		regex         = "container_([a-z_]+);"
            		action        = "drop"
            	}

            	rule {
            		source_labels = ["__name__"]
            		regex         = "container_(network_tcp_usage_total|network_udp_usage_total|tasks_state|cpu_load_average_10s)"
            		action        = "drop"
            	}
            }

            prometheus.remote_write "kubernetes_metrics" {
            	external_labels = {
            		cluster = "tns",
            	}

            	endpoint {
            		name = "kubernetes-metrics-9ba231"
            		url  = "http://mimir.mimir.svc.cluster.local/api/v1/push"

            		queue_config { }

            		metadata_config { }
            	}
            }

            discovery.relabel "log_pod" {
            	targets = discovery.kubernetes.pod.targets

            	rule {
            		source_labels = ["__meta_kubernetes_pod_label_name"]
            		target_label  = "__service__"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_node_name"]
            		target_label  = "__host__"
            	}

            	rule {
            		source_labels = ["__service__"]
            		regex         = ""
            		action        = "drop"
            	}

            	rule {
            		regex  = "__meta_kubernetes_pod_label_(.+)"
            		action = "labelmap"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_namespace", "__service__"]
            		separator     = "/"
            		target_label  = "job"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_namespace"]
            		target_label  = "namespace"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_name"]
            		target_label  = "pod"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_container_name"]
            		target_label  = "container"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
            		separator     = "/"
            		target_label  = "__path__"
            		replacement   = "/var/log/pods/*$1/*.log"
            	}
            }

            local.file_match "pod" {
            	path_targets = discovery.relabel.log_pod.output
            }

            loki.process "pod" {
            	forward_to = [loki.write.kubernetes.receiver]

            	stage.docker { }
            }

            loki.source.kubernetes "pod" {
            	targets               = local.file_match.pod.targets
            	forward_to            = [loki.process.pod.receiver]
            }

            discovery.relabel "pods_app" {
            	targets = discovery.kubernetes.pod.targets

            	rule {
            		source_labels = ["__meta_kubernetes_pod_label_name"]
            		regex         = ".+"
            		action        = "drop"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_label_app"]
            		target_label  = "__service__"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_node_name"]
            		target_label  = "__host__"
            	}

            	rule {
            		source_labels = ["__service__"]
            		regex         = ""
            		action        = "drop"
            	}

            	rule {
            		regex  = "__meta_kubernetes_pod_label_(.+)"
            		action = "labelmap"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_namespace", "__service__"]
            		separator     = "/"
            		target_label  = "job"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_namespace"]
            		target_label  = "namespace"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_name"]
            		target_label  = "pod"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_container_name"]
            		target_label  = "container"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
            		separator     = "/"
            		target_label  = "__path__"
            		replacement   = "/var/log/pods/*$1/*.log"
            	}
            }

            local.file_match "pods_app" {
            	path_targets = discovery.relabel.pods_app.output
            }

            loki.process "pods_app" {
            	forward_to = [loki.write.kubernetes.receiver]

            	stage.docker { }
            }

            loki.source.kubernetes "pods_app" {
            	targets               = local.file_match.pods_app.targets
            	forward_to            = [loki.process.pods_app.receiver]
            }

            discovery.relabel "direct_controllers" {
            	targets = discovery.kubernetes.pod.targets

            	rule {
            		source_labels = ["__meta_kubernetes_pod_label_name", "__meta_kubernetes_pod_label_app"]
            		separator     = ""
            		regex         = ".+"
            		action        = "drop"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_controller_name"]
            		regex         = "[0-9a-z-.]+-[0-9a-f]{8,10}"
            		action        = "drop"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_controller_name"]
            		target_label  = "__service__"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_node_name"]
            		target_label  = "__host__"
            	}

            	rule {
            		source_labels = ["__service__"]
            		regex         = ""
            		action        = "drop"
            	}

            	rule {
            		regex  = "__meta_kubernetes_pod_label_(.+)"
            		action = "labelmap"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_namespace", "__service__"]
            		separator     = "/"
            		target_label  = "job"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_namespace"]
            		target_label  = "namespace"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_name"]
            		target_label  = "pod"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_container_name"]
            		target_label  = "container"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
            		separator     = "/"
            		target_label  = "__path__"
            		replacement   = "/var/log/pods/*$1/*.log"
            	}
            }

            local.file_match "direct_controllers" {
            	path_targets = discovery.relabel.direct_controllers.output
            }

            loki.process "direct_controllers" {
            	forward_to = [loki.write.kubernetes.receiver]

            	stage.docker { }
            }

            loki.source.kubernetes "direct_controllers" {
            	targets               = local.file_match.direct_controllers.targets
            	forward_to            = [loki.process.direct_controllers.receiver]
            }

            discovery.relabel "indirect_controller" {
            	targets = discovery.kubernetes.pod.targets

            	rule {
            		source_labels = ["__meta_kubernetes_pod_label_name", "__meta_kubernetes_pod_label_app"]
            		separator     = ""
            		regex         = ".+"
            		action        = "drop"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_controller_name"]
            		regex         = "[0-9a-z-.]+-[0-9a-f]{8,10}"
            		action        = "keep"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_controller_name"]
            		regex         = "([0-9a-z-.]+)-[0-9a-f]{8,10}"
            		target_label  = "__service__"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_node_name"]
            		target_label  = "__host__"
            	}

            	rule {
            		source_labels = ["__service__"]
            		regex         = ""
            		action        = "drop"
            	}

            	rule {
            		regex  = "__meta_kubernetes_pod_label_(.+)"
            		action = "labelmap"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_namespace", "__service__"]
            		separator     = "/"
            		target_label  = "job"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_namespace"]
            		target_label  = "namespace"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_name"]
            		target_label  = "pod"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_container_name"]
            		target_label  = "container"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
            		separator     = "/"
            		target_label  = "__path__"
            		replacement   = "/var/log/pods/*$1/*.log"
            	}
            }

            local.file_match "indirect_controller" {
            	path_targets = discovery.relabel.indirect_controller.output
            }

            loki.process "indirect_controller" {
            	forward_to = [loki.write.kubernetes.receiver]

            	stage.docker { }
            }

            loki.source.kubernetes "indirect_controller" {
            	targets               = local.file_match.indirect_controller.targets
            	forward_to            = [loki.process.indirect_controller.receiver]
            }

            discovery.relabel "pods_static" {
            	targets = discovery.kubernetes.pod.targets

            	rule {
            		source_labels = ["__meta_kubernetes_pod_annotation_kubernetes_io_config_mirror"]
            		regex         = ""
            		action        = "drop"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_label_component"]
            		target_label  = "__service__"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_node_name"]
            		target_label  = "__host__"
            	}

            	rule {
            		source_labels = ["__service__"]
            		regex         = ""
            		action        = "drop"
            	}

            	rule {
            		regex  = "__meta_kubernetes_pod_label_(.+)"
            		action = "labelmap"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_namespace", "__service__"]
            		separator     = "/"
            		target_label  = "job"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_namespace"]
            		target_label  = "namespace"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_name"]
            		target_label  = "pod"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_container_name"]
            		target_label  = "container"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_annotation_kubernetes_io_config_mirror", "__meta_kubernetes_pod_container_name"]
            		separator     = "/"
            		target_label  = "__path__"
            		replacement   = "/var/log/pods/*$1/*.log"
            	}
            }

            local.file_match "pods_static" {
            	path_targets = discovery.relabel.pods_static.output
            }

            loki.process "pods_static" {
            	forward_to = [loki.write.kubernetes.receiver]

            	stage.docker { }
            }

            loki.source.kubernetes "pods_static" {
            	targets               = local.file_match.pods_static.targets
            	forward_to            = [loki.process.pods_static.receiver]
            }

            loki.write "kubernetes" {
            	endpoint {
            		url = "http://loki.loki.svc.cluster.local:3100/loki/api/v1/push"
            	}
            	external_labels = {
            		cluster = "tns",
            	}
            }

            otelcol.receiver.jaeger "default" {
            	protocols {
            		grpc {
            			endpoint = "0.0.0.0:14250"
            		}

            		thrift_http {
            			endpoint = "0.0.0.0:14268"
            		}

            		thrift_binary {
            			endpoint        = "0.0.0.0:6832"
            			max_packet_size = "63KiB488B"
            		}

            		thrift_compact {
            			endpoint        = "0.0.0.0:6831"
            			max_packet_size = "63KiB488B"
            		}
            	}

            	output {
            		traces = [otelcol.processor.discovery.default.input]
            	}
            }

            discovery.relabel "pods_otel" {
            	targets = discovery.kubernetes.pod.targets

            	rule {
            		source_labels = ["__meta_kubernetes_namespace"]
            		target_label  = "namespace"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_name"]
            		target_label  = "pod"
            	}

            	rule {
            		source_labels = ["__meta_kubernetes_pod_container_name"]
            		target_label  = "container"
            	}
            }

            otelcol.processor.discovery "default" {
            	targets          = discovery.relabel.pods_otel.output
            	pod_associations = []

            	output {
            		traces = [otelcol.exporter.otlp.tempo.input]
            	}
            }

            otelcol.exporter.otlp "tempo" {
            	retry_on_failure {
            		max_elapsed_time = "1m0s"
            	}

            	client {
            		endpoint = "tempo.tempo.svc.cluster.local:55680"

            		tls {
            			insecure = true
            		}
            	}
            }
          |||,

        },
      },
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
