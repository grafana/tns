local tempo = import 'tempo/tempo.libsonnet';

tempo {
  _images+:: {
    tempo: 'annanay25/tempo:c136583e',
    tempo_query: 'annanay25/tempo-query:c136583e',
    tempo_vulture: 'annanay25/tempo-vulture:c136583e',
  },
  
  _config+:: {
    namespace: 'tempo',
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
