(import 'ksonnet-util/kausal.libsonnet') +
(import 'configmap.libsonnet') +
(import 'config.libsonnet') +
{
  local container = $.core.v1.container,
  local containerPort = $.core.v1.containerPort,
  local volumeMount = $.core.v1.volumeMount,
  local statefulSet = $.apps.v1.statefulSet,
  local pvc = $.core.v1.persistentVolumeClaim,
  local storageClass = $.storage.v1.storageClass,
  local volume = $.core.v1.volume,
  local service = $.core.v1.service,
  local servicePort = service.mixin.spec.portsType,

  local mimir_pvc_name = 'mimir-data',
  local mimir_config_volume = 'mimir-conf',
  local mimir_config_path = '/conf',

  namespace: $.core.v1.namespace.new($._config.namespace),

  local mimir_pvc =
    pvc.new() +
    pvc.mixin.spec.resources.withRequests({ storage: '1Gi' }) +
    pvc.mixin.spec.withAccessModes(['ReadWriteOnce']) +
    pvc.mixin.metadata.withName(mimir_pvc_name),

  local mimir_container =
    container.new('mimir', $._images.mimir) +
    container.withPorts([
      containerPort.new('prom-metrics', $._config.http.port),
    ]) +
    container.withArgs([
      '-config.file=%s/mimir.yaml' % mimir_config_path,
    ]) +
    container.withVolumeMounts([
      volumeMount.new(mimir_config_volume, mimir_config_path),
      volumeMount.new(mimir_pvc_name, $._config.storage.path),
    ]) +
    container.mixin.readinessProbe.httpGet.withPath('/ready') +
    container.mixin.readinessProbe.httpGet.withPort($._config.http.port) +
    container.mixin.readinessProbe.withInitialDelaySeconds(5) +
    container.mixin.readinessProbe.withTimeoutSeconds(1) +
    container.mixin.livenessProbe.httpGet.withPath('/ready') +
    container.mixin.livenessProbe.httpGet.withPort($._config.http.port) +
    container.mixin.livenessProbe.withInitialDelaySeconds(5) +
    container.mixin.livenessProbe.withTimeoutSeconds(1),

  mimir_statefulset:
    statefulSet.new('mimir', 1, mimir_container, [mimir_pvc], { app: 'mimir' }) +
    statefulSet.mixin.spec.template.metadata.withAnnotations({
      config_hash: std.md5(std.toString($.mimir_configmap)),
    }) +
    statefulSet.mixin.spec.withServiceName('mimir') +
    statefulSet.mixin.spec.template.spec.withTerminationGracePeriodSeconds(60) +
    statefulSet.mixin.spec.template.spec.withVolumes([
      volume.fromConfigMap(mimir_config_volume, $.mimir_configmap.metadata.name),
      volume.fromPersistentVolumeClaim(mimir_pvc_name, mimir_pvc_name),
    ]),

  mimir_service:
    $.util.serviceFor($.mimir_statefulset) +
    service.mixin.spec.withPortsMixin([
      servicePort.withName('http') + servicePort.withPort(80) + servicePort.withTargetPort($._config.http.port),
      servicePort.withName('grpc') + servicePort.withPort(9095) + servicePort.withTargetPort($._config.grpc.port),
    ]),
}
