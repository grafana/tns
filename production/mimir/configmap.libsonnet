{
  local configMap = $.core.v1.configMap,

  mimir_config:: {
    multitenancy_enabled: false,
    server: {
      http_listen_port: $._config.http.port,
      grpc_listen_port: $._config.grpc.port,
    },

    common: {
      storage: {
        filesystem: {
          dir: $._config.storage.path,
        },
      },
    },
    ingester: {
      ring: {
        replication_factor: 1,
      },
    },
    blocks_storage: {
      storage_prefix: 'blocks',
      tsdb: {
        dir: '%s/tsdb' % $._config.storage.path,
      },
    },
    limits: {
      max_global_exemplars_per_user: 100000,
    },
  },

  mimir_configmap:
    configMap.new('mimir') +
    configMap.withData({
      'mimir.yaml': $.util.manifestYaml($.mimir_config),
    }),
}
