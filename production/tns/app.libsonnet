{
  local deployment = $.apps.v1.deployment,
  local container = deployment.mixin.spec.template.spec.containersType,
  local containerPort = $.core.v1.containerPort,
  local service = $.core.v1.service,
  local servicePort = $.core.v1.service.mixin.spec.portsType,

  local tns_container = container.new('app', $._images.tns_app)
    .withPorts(containerPort.new('http-metrics', 80))
    .withImagePullPolicy('IfNotPresent')
    .withArgs(['-log.level=debug', 'http://db'])
    .withEnv([
        container.envType.new('JAEGER_AGENT_HOST', $._config.tns.jaeger.host),
        container.envType.new('JAEGER_TAGS', $._config.tns.jaeger.tags),
        container.envType.new('JAEGER_SAMPLER_TYPE', $._config.tns.jaeger.sampler_type),
        container.envType.new('JAEGER_SAMPLER_PARAM', $._config.tns.jaeger.sampler_param),
   ])
   ,

  app_deployment: deployment.new('app', 1, [tns_container], {}),

  tns_service: $.util.serviceFor($.app_deployment),
}
