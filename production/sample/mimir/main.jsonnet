local mimir = import 'mimir/mimir.libsonnet';

mimir {
  _images+:: {
    mimir: 'grafana/mimir:2.4.0',
  },
  _config+:: {
    namespace: 'mimir',
  },
}
