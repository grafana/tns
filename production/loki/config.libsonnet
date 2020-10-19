{
  _images:: {
    loki: 'grafana/loki:v1.2.0',
  },

  _config+:: {
    loki+: {
      auth_enabled: false,
      ingester: {
        chunk_idle_period: '3m',
        chunk_block_size: 262144,
        chunk_retain_period: '1m',
        lifecycler: {
          ring: {
            kvstore: {
              store: 'inmemory',
            },
            replication_factor: 1,
          },
          /*
           * Different ring configs can be used. E.g. Consul
          ring: {
            store: 'consul',
            replication_factor: 1,
            consul: {
              host: "consul:8500",
              prefix: "",
              httpclienttimeout: "20s",
              consistentreads: true,
            },
          },
          */
        },
      },
      limits_config: {
        enforce_metric_name: false,
        reject_old_samples: true,
        reject_old_samples_max_age: '168h',
      },
      schema_config: {
        configs: [{
          from: '2018-04-15',
          store: 'boltdb',
          object_store: 'filesystem',
          schema: 'v9',
          index: {
            prefix: 'index_',
            period: '168h',
          },
        }],
      },
      server: {
        http_listen_port: 3100,
      },
      storage_config: {
        boltdb: {
          directory: '/data/loki/index',
        },
        filesystem: {
          directory: '/data/loki/chunks',
        },
      },
      chunk_store_config: {
        max_look_back_period: 0,
      },
      table_manager: {
        retention_deletes_enabled: false,
        retention_period: 0,
      },
    },
  },
}
