local g = import 'grafana-builder/grafana.libsonnet';
local grr = import 'grizzly/grizzly.libsonnet';
local mixin = import 'mixin.libsonnet';

local templating = {
  templating: g.dashboard('Demo App').addMultiTemplate('namespace', 'kube_namespace_status_phase{job="integrations/kubernetes/kube-state-metrics"}', 'namespace').templating,
};

local grrDashboards = [
  grr.dashboard.new(std.stripChars(fname, '.json'), mixin.grafanaDashboards[fname] + templating) +
  grr.resource.addMetadata('folder', 'TNS')
  for fname in std.objectFields(mixin.grafanaDashboards)
];

{
  folders: [grr.folder.new(mixin.grafanaDashboardFolder, mixin.grafanaDashboardFolder)],
  dashboards: grrDashboards,
}
