local loki = import 'loki/loki.libsonnet';

loki {
  _config+:: {
    namespace: 'loki',
  },
}
