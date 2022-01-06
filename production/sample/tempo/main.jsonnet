local tempo = import 'tempo/tempo.libsonnet';

tempo {
  local container = $.core.v1.container,

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
      otlp: {
        protocols: {
          grpc: {
            endpoint: '0.0.0.0:55680',
          },
        },
      },
    },
  },

  tempo_container+::
    container.withEnv([
      container.envType.new('JAEGER_AGENT_PORT', ''),
    ]) +
    container.withPortsMixin([
      $.core.v1.containerPort.new('otlp', 55680) +
      $.core.v1.containerPort.withProtocol('TCP'),
    ]),

  tempo_query_container+::
    container.withEnv([
      container.envType.new('JAEGER_AGENT_PORT', ''),
    ]),
}
