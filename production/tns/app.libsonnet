{
  tns:: {
    new(name, arg, image):: {
      local deployment = $.apps.v1.deployment,
      local container = deployment.mixin.spec.template.spec.containersType,
      local containerPort = $.core.v1.containerPort,
      local service = $.core.v1.service,
      local _container = container.new(name, image)
                         + container.withPorts(containerPort.new('http-metrics', 80))
                         + container.withImagePullPolicy('IfNotPresent')
                         + container.withArgs(std.prune(['-log.level=debug', if arg != '' then arg else null]))
                         + container.withEnv([
                           container.envType.new('JAEGER_AGENT_HOST', $._config.tns.jaeger.host),
                           container.envType.new('JAEGER_TAGS', $._config.tns.jaeger.tags),
                           container.envType.new('JAEGER_SAMPLER_TYPE', $._config.tns.jaeger.sampler_type),
                           container.envType.new('JAEGER_SAMPLER_PARAM', $._config.tns.jaeger.sampler_param),
                         ])
      ,

      _deployment: deployment.new(name, 1, [_container], {}),

      service: $.util.serviceFor(self._deployment),
    },
  },
}
