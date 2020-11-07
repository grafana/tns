local loki = import 'loki/loki.libsonnet';

loki {
  _images+:: {
    loki: 'grafana/loki:2.0.0',
  },
  _config+:: {
    namespace: 'loki',
  },
}
