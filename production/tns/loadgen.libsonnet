{
  local deployment = $.apps.v1.deployment,
  local container = deployment.mixin.spec.template.spec.containersType,
  local containerPort = $.core.v1.containerPort,
  local service = $.core.v1.service,

  local loadgen_container = container.new('loadgen', $._images.loadgen)
    .withPorts(containerPort.newNamed(80, 'http-metrics'))
    .withImagePullPolicy('IfNotPresent')
    .withArgs(['-log.level=debug', 'http://app'])
    .withEnv([
        container.envType.new('JAEGER_AGENT_HOST', $._config.tns.jaeger.host),
        container.envType.new('JAEGER_TAGS', $._config.tns.jaeger.tags),
        container.envType.new('JAEGER_SAMPLER_TYPE', $._config.tns.jaeger.sampler_type),
        container.envType.new('JAEGER_SAMPLER_PARAM', $._config.tns.jaeger.sampler_param),
   ])
,

  loadgen_deployment: deployment.new('loadgen', 1, [loadgen_container], {}),

  loadgen_service: $.util.serviceFor($.loadgen_deployment),
}
