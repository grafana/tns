(import 'ksonnet-util/kausal.libsonnet') +
(import 'namespace.libsonnet') +
(import 'config.libsonnet') +
(import 'app.libsonnet') +
{
  db: $.tns.new('db', '', $._images.db),
  app: $.tns.new('app', 'http://db', $._images.tns_app),
  loadgen: $.tns.new('loadgen', 'http://app', $._images.loadgen),
}
