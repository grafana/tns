local tempo = import 'tempo/tempo.libsonnet';

tempo {
  _config+:: {
    namespace: 'tempo',
    pvc_size: '1Gi',
    pvc_storage_class: 'standard',
    receivers: {
        jaeger: {
            protocols: {
                thrift_compact: {
                    endpoint: '0.0.0.0:6831',
                },
            },
        },
    },
  },
}
