{
  local statefulset = $.apps.v1.statefulSet,
  local container = $.core.v1.container,
  local containerPort = $.core.v1.containerPort,
  local mount = $.core.v1.volumeMount,
  local pvc = $.core.v1.persistentVolumeClaim,
  local storageClass = $.storage.v1.storageClass,
  local volume = $.core.v1.volume,
  local volumeMount = $.core.v1.volumeMount,

  loki_pvc::
    pvc.new() +
    pvc.mixin.spec.resources.withRequests({ storage: '10Gi' }) +
    pvc.mixin.spec.withAccessModes(['ReadWriteOnce']) +
    pvc.mixin.metadata.withName('loki-data'),

  local loki_container = container.new('loki', $._images.loki)
                         + container.withArgs(['-config.file=/etc/loki/loki.yaml'])
                         + container.withVolumeMounts([
                           mount.new('loki-config', '/etc/loki'),
                           mount.new('loki-data', '/data'),
                         ])
                         + container.withPorts([
                           containerPort.new(name='http-metrics', port=3100),
                         ])
                         + container.mixin.livenessProbe.httpGet.withPath('/ready')
                         + container.mixin.livenessProbe.httpGet.withPort('http-metrics')
                         + container.mixin.livenessProbe.withInitialDelaySeconds(45)
                         + container.mixin.readinessProbe.httpGet.withPath('/ready')
                         + container.mixin.readinessProbe.httpGet.withPort('http-metrics')
                         + container.mixin.readinessProbe.withInitialDelaySeconds(45)
  ,

  loki_statefulset: statefulset.new('loki', 1, loki_container, [$.loki_pvc])
                    + statefulset.mixin.spec.template.spec.withVolumes([
                      volume.fromPersistentVolumeClaim('loki-data', 'loki-data'),
                      volume.fromSecret('loki-config', 'loki-config'),
                    ])
                    + statefulset.mixin.metadata.withNamespace($._config.namespace)
                    + statefulset.mixin.spec.withServiceName('loki')
                    + statefulset.mixin.spec.template.spec.securityContext.withFsGroup(10001)
                    + statefulset.mixin.spec.template.spec.securityContext.withRunAsGroup(10001)
                    + statefulset.mixin.spec.template.spec.securityContext.withRunAsNonRoot(true)
                    + statefulset.mixin.spec.template.spec.securityContext.withRunAsUser(10001)
  //+ statefulset.mixin.spec.template.spec.securityContext.withReadOnlyRootFilesystem(true)
  ,

  loki_service: $.util.serviceFor($.loki_statefulset)
                + $.core.v1.service.mixin.metadata.withNamespace($._config.namespace),
}
