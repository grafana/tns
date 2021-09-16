{
  _images+:: {
    tempo: 'grafana/tempo:latest',
    tempo_vulture: 'grafana/tempo-vulture:latest',
  },

  _config+:: {
    port: 3200,
    pvc_size: error 'Must specify a pvc size',
    pvc_storage_class: error 'Must specify a pvc storage class',
    receivers: error 'Must specify receivers',
    ballast_size_mbs: '1024',
    jaeger_ui: {
      base_path: '/',
    },
  },

  tempo_container+::
    $.util.resourcesRequests('400m', '1Gi') +
    $.util.resourcesLimits('500m', '1Gi'),
}
