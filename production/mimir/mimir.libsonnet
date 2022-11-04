(import 'ksonnet-util/kausal.libsonnet') +
(import 'configmap.libsonnet') +
(import 'config.libsonnet') +
{
  local container = $.core.v1.container,
  local containerPort = $.core.v1.containerPort,
  local volumeMount = $.core.v1.volumeMount,
  local deployment = $.apps.v1.deployment,
  local volume = $.core.v1.volume,
  local service = $.core.v1.service,
  local servicePort = service.mixin.spec.portsType,

  local mimir_config_volume = 'mimir-conf',

  namespace: $.core.v1.namespace.new($._config.namespace),

  mimir_container::
    container.new('mimir', $._images.mimir) +
    container.withPorts([
      containerPort.new('prom-metrics', $._config.http.port),
    ]) +
    container.withArgs([
      '-config.file=/conf/mimir.yaml',
    ]) +
    container.withVolumeMounts([
      volumeMount.new(mimir_config_volume, '/conf'),
    ]),

  mimir_deployment:
    deployment.new('mimir', 1, [$.mimir_container], { app: 'mimir' }) +
    deployment.mixin.spec.template.metadata.withAnnotations({
      config_hash: std.md5(std.toString($.mimir_configmap)),
    }) +
    deployment.mixin.spec.strategy.rollingUpdate.withMaxSurge(0) +
    deployment.mixin.spec.strategy.rollingUpdate.withMaxUnavailable(1) +
    deployment.mixin.spec.template.spec.withVolumes([
      volume.fromConfigMap(mimir_config_volume, $.mimir_configmap.metadata.name),
    ]),

  mimir_service:
    $.util.serviceFor($.mimir_deployment) +
    service.mixin.spec.withPortsMixin([
      servicePort.withName('http') + servicePort.withPort(80) + servicePort.withTargetPort($._config.http.port),
      servicePort.withName('grpc') + servicePort.withPort(9095) + servicePort.withTargetPort($._config.grpc.port),
    ]),
}
