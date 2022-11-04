{
  local configMap = $.core.v1.configMap,

  mimir_config:: {
    multitenancy_enabled: false,
    server: {
      http_listen_port: $._config.http.port,
      grpc_listen_port: $._config.grpc.port,
    },
    ingester: {
      ring: {
        replication_factor: 1,
      },
    },
  },

  mimir_configmap:
    configMap.new('mimir') +
    configMap.withData({
      'mimir.yaml': $.util.manifestYaml($.mimir_config),
    }),
}
