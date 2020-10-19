local loki = import 'loki/loki.libsonnet';

loki {
  _images+:: {
    loki: 'grafana/loki:logql-parser-1ea917f',
  },
  _config+:: {
    namespace: 'loki',
  },
}
