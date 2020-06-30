(import 'ksonnet-util/kausal.libsonnet') +

{
  _config+:: {
    jaeger+: {
      replicas: 1,
    },
  },

  _images+:: {
    jaeger: 'jaegertracing/all-in-one:1.16.0',
  },

  local deployment = $.apps.v1.deployment,
  local container = $.core.v1.container,
  local containerPort = $.core.v1.containerPort,

  ns: $.core.v1.namespace.new($._config.namespace),

  local jaeger_container = container.new('jaeger', $._images.jaeger)
                           + container.withImagePullPolicy('IfNotPresent')
                           + container.withPorts([
                             containerPort.new('http-server', 16686),
                             containerPort.new('http-metrics', 16687),
                             containerPort.new(name='thrift-compact', port=6831).withProtocol('UDP'),
                           ])
                           + container.withArgs([
                             '--query.base-path=/jaeger',
                           ])
  ,

  jaeger_deployment: deployment.new('jaeger', $._config.jaeger.replicas, jaeger_container),

  jaeger_service: $.util.serviceFor($.jaeger_deployment),
}
