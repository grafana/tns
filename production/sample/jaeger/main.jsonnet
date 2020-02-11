local jaeger = import 'jaeger/jaeger.libsonnet';

jaeger + {
  _config+:: {
    namespace: 'jaeger',
  },
}
