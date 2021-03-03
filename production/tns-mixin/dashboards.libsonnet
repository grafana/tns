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

  latencyPanelWithExemplars(metricName, selector)::
    // There is a display issue with any multiplier != 1 so enforce it
    g.latencyPanel(metricName, selector, '1') + {

      // Requires new timeseries panel
      type: 'timeseries',

      // Enable exemplars on all queries
      targets: [
        t {
          exemplar: true,
        }
        for t in super.targets
      ],

      // Seconds to match multiplier 1
      yaxes: $.yaxes('s'),
      fieldConfig+: {
        defaults+: {
          unit: 's',
        },
      },
    },
};

{
  grafanaDashboardFolder: 'TNS',
  grafanaDashboards+: {
    'demo-red.json':
      g.dashboard('Demo App')
      .addMultiTemplate('namespace', 'kube_pod_container_info{image=~".*grafana/tns.*"}', 'namespace')
      .addRow(
        g.row('Load balancer')
        .addPanel(
          g.panel('QPS') +
          g.qpsSimplePanel('tns_request_duration_seconds_count{job=~"$namespace/loadgen"}')
        )
        .addPanel(
          g.panel('Latency') +
          g.latencyPanelWithExemplars('tns_request_duration_seconds', '{job=~"$namespace/loadgen"}')
        )
      )
      .addRow(
        g.row('App')
        .addPanel(
          g.panel('QPS') +
          g.qpsSimplePanel('tns_request_duration_seconds_count{job=~"$namespace/app"}')
        )
        .addPanel(
          g.panel('Latency') +
          g.latencyPanelWithExemplars('tns_request_duration_seconds', '{job=~"$namespace/app"}')
        )
      )
      .addRow(
        g.row('DB')
        .addPanel(
          g.panel('QPS') +
          g.qpsSimplePanel('tns_request_duration_seconds_count{job=~"$namespace/db"}')
        )
        .addPanel(
          g.panel('Latency') +
          g.latencyPanelWithExemplars('tns_request_duration_seconds', '{job=~"$namespace/db"}')
        )
      ),
  },
}
