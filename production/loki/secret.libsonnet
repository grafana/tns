{
  local secret = $.core.v1.secret,
  loki_secret:
    secret.new(
      'loki-config',
      {
        'loki.yaml': std.base64($.util.manifestYaml($._config.loki)),
      },
      'Opaque',
    ) +
    secret.mixin.metadata.withNamespace($._config.namespace),
}
