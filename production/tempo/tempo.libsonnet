// copied from grafana/tempo -> operations/jsonnet/single-binary
(import 'ksonnet-util/kausal.libsonnet') +
(import 'configmap.libsonnet') +
(import 'config.libsonnet') +
{
  local container = $.core.v1.container,
  local containerPort = $.core.v1.containerPort,
  local volumeMount = $.core.v1.volumeMount,
  local pvc = $.core.v1.persistentVolumeClaim,
  local deployment = $.apps.v1.deployment,
  local volume = $.core.v1.volume,
  local service = $.core.v1.service,
  local servicePort = service.mixin.spec.portsType,

  local tempo_config_volume = 'tempo-conf',

  namespace:
    $.core.v1.namespace.new($._config.namespace),

  tempo_container::
    container.new('tempo', $._images.tempo) +
    container.withPorts([
      containerPort.new('prom-metrics', $._config.port),
    ]) +
    container.withArgs([
      '-config.file=/conf/tempo.yaml',
      '-mem-ballast-size-mbs=' + $._config.ballast_size_mbs,
    ]) +
    container.withVolumeMounts([
      volumeMount.new(tempo_config_volume, '/conf'),
    ]),

  tempo_deployment:
    deployment.new('tempo',
                   1,
                   [
                     $.tempo_container,
                   ],
                   { app: 'tempo' }) +
    deployment.mixin.spec.template.metadata.withAnnotations({
      config_hash: std.md5(std.toString($.tempo_configmap)),
    }) +
    deployment.mixin.spec.strategy.rollingUpdate.withMaxSurge(0) +
    deployment.mixin.spec.strategy.rollingUpdate.withMaxUnavailable(1) +
    deployment.mixin.spec.template.spec.withVolumes([
      volume.fromConfigMap(tempo_config_volume, $.tempo_configmap.metadata.name),
    ]),

  tempo_service:
    $.util.serviceFor($.tempo_deployment)
    + service.mixin.spec.withPortsMixin([
      servicePort.withName('http') +
      servicePort.withPort(80) +
      servicePort.withTargetPort($._config.port),
      servicePort.withName('receiver') +
      servicePort.withPort(6831) +
      servicePort.withProtocol('UDP') +
      servicePort.withTargetPort(6831),
    ]),
}
