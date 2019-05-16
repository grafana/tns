local g = (import 'grafana-builder/grafana.libsonnet') + {
  qpsSimplePanel(selector):: {
    aliasColors: {
      '200': '#7EB26D',
      '500': '#E24D42',
    },
    targets: [
      {
        expr: 'sum by (status_code) (rate(' + selector + '[1m]))',
        format: 'time_series',
        intervalFactor: 2,
        legendFormat: '{{status_code}}',
        refId: 'A',
        step: 10,
      },
    ],
  } + $.stack,
};

{
  dashboards+: {
    'demo-red.json':
      g.dashboard('Demo App')
      .addMultiTemplate('namespace', 'kube_pod_container_info{image=~".*grafana/tns.*"}', 'namespace')
      .addRow(
        g.row('Load balancer')
        .addPanel(
          g.panel('QPS') +
          g.qpsSimplePanel('tns_request_duration_seconds_count{job="$namespace/loadgen"}')
        )
        .addPanel(
          g.panel('Latency') +
          g.latencyPanel('tns_request_duration_seconds', '{job="$namespace/loadgen"}')
        )
      )
      .addRow(
        g.row('App')
        .addPanel(
          g.panel('QPS') +
          g.qpsSimplePanel('tns_request_duration_seconds_count{job="$namespace/app"}')
        )
        .addPanel(
          g.panel('Latency') +
          g.latencyPanel('tns_request_duration_seconds', '{job="$namespace/app"}')
        )
      )
      .addRow(
        g.row('DB')
        .addPanel(
          g.panel('QPS') +
          g.qpsSimplePanel('tns_request_duration_seconds_count{job="$namespace/db"}')
        )
        .addPanel(
          g.panel('Latency') +
          g.latencyPanel('tns_request_duration_seconds', '{job="$namespace/db"}')
        )
      ),
  },
}
