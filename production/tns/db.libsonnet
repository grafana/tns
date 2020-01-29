{
  local deployment = $.apps.v1.deployment,
  local container = deployment.mixin.spec.template.spec.containersType,
  local containerPort = $.core.v1.containerPort,
  local service = $.core.v1.service,

  local db_container = container.new('db', $._images.db)
    .withPorts(containerPort.new('http-metrics', 80))
    .withImagePullPolicy('IfNotPresent')
    .withArgs(['-log.level=debug'])
    .withEnv([
        container.envType.new('JAEGER_AGENT_HOST', $._config.tns.jaeger.host),
        container.envType.new('JAEGER_TAGS', $._config.tns.jaeger.tags),
        container.envType.new('JAEGER_SAMPLER_TYPE', $._config.tns.jaeger.sampler_type),
        container.envType.new('JAEGER_SAMPLER_PARAM', $._config.tns.jaeger.sampler_param),
    ])
,

  db_deployment: deployment.new('db', 1, [db_container], {}),

  db_service: $.util.serviceFor($.db_deployment),
}
