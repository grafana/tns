local g = (import 'grafana-builder/grafana.libsonnet') + {
  qpsSimplePanel(selector):: {
    aliasColors: {
      '200': '#7EB26D',
      '500': '#E24D42',
    },
    targets: [
      {
        expr: 'sum by (status_code) (rate(' + selector + '[$__rate_interval]))',
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
    'demo-red-alternative.json':
      {
        annotations: {
          list: [],
        },
        editable: true,
        gnetId: null,
        graphTooltip: 0,
        hideControls: false,
        links: [],
        refresh: '10s',
        rows: [
          {
            collapse: false,
            height: '250px',
            panels: [
              {
                aliasColors: {
                  '200': '#7EB26D',
                  '500': '#E24D42',
                },
                bars: false,
                dashLength: 10,
                dashes: false,
                datasource: '$datasource',
                fill: 10,
                id: 1,
                legend: {
                  avg: false,
                  current: false,
                  max: false,
                  min: false,
                  show: true,
                  total: false,
                  values: false,
                },
                lines: true,
                linewidth: 0,
                links: [],
                nullPointMode: 'null as zero',
                percentage: false,
                pointradius: 5,
                points: false,
                renderer: 'flot',
                seriesOverrides: [],
                spaceLength: 10,
                span: 6,
                stack: true,
                steppedLine: false,
                targets: [
                  {
                    expr: 'sum by (status_code) (rate(tns_request_duration_seconds_count{job=~"$namespace/loadgen"}[$__rate_interval]))',
                    format: 'time_series',
                    intervalFactor: 2,
                    legendFormat: '{{status_code}}',
                    refId: 'A',
                    step: 10,
                  },
                ],
                thresholds: [],
                timeFrom: null,
                timeShift: null,
                title: 'QPS',
                tooltip: {
                  shared: false,
                  sort: 0,
                  value_type: 'individual',
                },
                type: 'graph',
                xaxis: {
                  buckets: null,
                  mode: 'time',
                  name: null,
                  show: true,
                  values: [],
                },
                yaxes: [
                  {
                    format: 'short',
                    label: null,
                    logBase: 1,
                    max: null,
                    min: 0,
                    show: true,
                  },
                  {
                    format: 'short',
                    label: null,
                    logBase: 1,
                    max: null,
                    min: null,
                    show: false,
                  },
                ],
              },
              {
                aliasColors: {},
                bars: false,
                dashLength: 10,
                dashes: false,
                datasource: '$datasource',
                fieldConfig: {
                  defaults: {
                    unit: 's',
                  },
                },
                fill: 1,
                id: 2,
                legend: {
                  avg: false,
                  current: false,
                  max: false,
                  min: false,
                  show: true,
                  total: false,
                  values: false,
                },
                lines: true,
                linewidth: 1,
                links: [],
                nullPointMode: 'null as zero',
                percentage: false,
                pointradius: 5,
                points: false,
                renderer: 'flot',
                seriesOverrides: [],
                spaceLength: 10,
                span: 6,
                stack: false,
                steppedLine: false,
                targets: [
                  {
                    exemplar: true,
                    expr: 'histogram_quantile(0.99, sum(rate(tns_request_duration_seconds_bucket{job=~"$namespace/loadgen"}[$__rate_interval])) by (le)) * 1',
                    format: 'time_series',
                    intervalFactor: 2,
                    legendFormat: '99th Percentile',
                    refId: 'A',
                    step: 10,
                  },
                  {
                    exemplar: true,
                    expr: 'histogram_quantile(0.50, sum(rate(tns_request_duration_seconds_bucket{job=~"$namespace/loadgen"}[$__rate_interval])) by (le)) * 1',
                    format: 'time_series',
                    intervalFactor: 2,
                    legendFormat: '50th Percentile',
                    refId: 'B',
                    step: 10,
                  },
                  {
                    exemplar: true,
                    expr: 'sum(rate(tns_request_duration_seconds_sum{job=~"$namespace/loadgen"}[$__rate_interval])) * 1 / sum(rate(tns_request_duration_seconds_count{job=~"$namespace/loadgen"}[$__rate_interval]))',
                    format: 'time_series',
                    intervalFactor: 2,
                    legendFormat: 'Average',
                    refId: 'C',
                    step: 10,
                  },
                ],
                thresholds: [],
                timeFrom: null,
                timeShift: null,
                title: 'Latency',
                tooltip: {
                  shared: false,
                  sort: 0,
                  value_type: 'individual',
                },
                type: 'timeseries',
                xaxis: {
                  buckets: null,
                  mode: 'time',
                  name: null,
                  show: true,
                  values: [],
                },
                yaxes: [
                  {
                    format: 's',
                    label: null,
                    logBase: 1,
                    max: null,
                    min: 0,
                    show: true,
                  },
                  {
                    format: 'short',
                    label: null,
                    logBase: 1,
                    max: null,
                    min: null,
                    show: false,
                  },
                ],
              },
            ],
            repeat: null,
            repeatIteration: null,
            repeatRowId: null,
            showTitle: true,
            title: 'Load balancer',
            titleSize: 'h6',
          },
          {
            collapse: false,
            height: '250px',
            panels: [
              {
                aliasColors: {
                  '200': '#7EB26D',
                  '500': '#E24D42',
                },
                bars: false,
                dashLength: 10,
                dashes: false,
                datasource: '$datasource',
                fill: 10,
                id: 3,
                legend: {
                  avg: false,
                  current: false,
                  max: false,
                  min: false,
                  show: true,
                  total: false,
                  values: false,
                },
                lines: true,
                linewidth: 0,
                links: [],
                nullPointMode: 'null as zero',
                percentage: false,
                pointradius: 5,
                points: false,
                renderer: 'flot',
                seriesOverrides: [],
                spaceLength: 10,
                span: 6,
                stack: true,
                steppedLine: false,
                targets: [
                  {
                    expr: 'sum by (status_code) (rate(tns_request_duration_seconds_count{job=~"$namespace/app"}[$__rate_interval]))',
                    format: 'time_series',
                    intervalFactor: 2,
                    legendFormat: '{{status_code}}',
                    refId: 'A',
                    step: 10,
                  },
                ],
                thresholds: [],
                timeFrom: null,
                timeShift: null,
                title: 'QPS',
                tooltip: {
                  shared: false,
                  sort: 0,
                  value_type: 'individual',
                },
                type: 'graph',
                xaxis: {
                  buckets: null,
                  mode: 'time',
                  name: null,
                  show: true,
                  values: [],
                },
                yaxes: [
                  {
                    format: 'short',
                    label: null,
                    logBase: 1,
                    max: null,
                    min: 0,
                    show: true,
                  },
                  {
                    format: 'short',
                    label: null,
                    logBase: 1,
                    max: null,
                    min: null,
                    show: false,
                  },
                ],
              },
              {
                aliasColors: {},
                bars: false,
                dashLength: 10,
                dashes: false,
                datasource: '$datasource',
                fieldConfig: {
                  defaults: {
                    unit: 's',
                  },
                },
                fill: 1,
                id: 4,
                legend: {
                  avg: false,
                  current: false,
                  max: false,
                  min: false,
                  show: true,
                  total: false,
                  values: false,
                },
                lines: true,
                linewidth: 1,
                links: [],
                nullPointMode: 'null as zero',
                percentage: false,
                pointradius: 5,
                points: false,
                renderer: 'flot',
                seriesOverrides: [],
                spaceLength: 10,
                span: 6,
                stack: false,
                steppedLine: false,
                targets: [
                  {
                    exemplar: true,
                    expr: 'histogram_quantile(0.99, sum(rate(tns_request_duration_seconds_bucket{job=~"$namespace/app"}[$__rate_interval])) by (le)) * 1',
                    format: 'time_series',
                    intervalFactor: 2,
                    legendFormat: '99th Percentile',
                    refId: 'A',
                    step: 10,
                  },
                  {
                    exemplar: true,
                    expr: 'histogram_quantile(0.50, sum(rate(tns_request_duration_seconds_bucket{job=~"$namespace/app"}[$__rate_interval])) by (le)) * 1',
                    format: 'time_series',
                    intervalFactor: 2,
                    legendFormat: '50th Percentile',
                    refId: 'B',
                    step: 10,
                  },
                  {
                    exemplar: true,
                    expr: 'sum(rate(tns_request_duration_seconds_sum{job=~"$namespace/app"}[$__rate_interval])) * 1 / sum(rate(tns_request_duration_seconds_count{job=~"$namespace/app"}[$__rate_interval]))',
                    format: 'time_series',
                    intervalFactor: 2,
                    legendFormat: 'Average',
                    refId: 'C',
                    step: 10,
                  },
                ],
                thresholds: [],
                timeFrom: null,
                timeShift: null,
                title: 'Latency',
                tooltip: {
                  shared: false,
                  sort: 0,
                  value_type: 'individual',
                },
                type: 'timeseries',
                xaxis: {
                  buckets: null,
                  mode: 'time',
                  name: null,
                  show: true,
                  values: [],
                },
                yaxes: [
                  {
                    format: 's',
                    label: null,
                    logBase: 1,
                    max: null,
                    min: 0,
                    show: true,
                  },
                  {
                    format: 'short',
                    label: null,
                    logBase: 1,
                    max: null,
                    min: null,
                    show: false,
                  },
                ],
              },
            ],
            repeat: null,
            repeatIteration: null,
            repeatRowId: null,
            showTitle: true,
            title: 'App',
            titleSize: 'h6',
          },
          {
            collapse: false,
            height: '250px',
            panels: [
              {
                aliasColors: {
                  '200': '#7EB26D',
                  '500': '#E24D42',
                },
                bars: false,
                dashLength: 10,
                dashes: false,
                datasource: '$datasource',
                fill: 10,
                id: 5,
                legend: {
                  avg: false,
                  current: false,
                  max: false,
                  min: false,
                  show: true,
                  total: false,
                  values: false,
                },
                lines: true,
                linewidth: 0,
                links: [],
                nullPointMode: 'null as zero',
                percentage: false,
                pointradius: 5,
                points: false,
                renderer: 'flot',
                seriesOverrides: [],
                spaceLength: 10,
                span: 6,
                stack: true,
                steppedLine: false,
                targets: [
                  {
                    expr: 'sum by (status_code) (rate(tns_request_duration_seconds_count{job=~"$namespace/db"}[$__rate_interval]))',
                    format: 'time_series',
                    intervalFactor: 2,
                    legendFormat: '{{status_code}}',
                    refId: 'A',
                    step: 10,
                  },
                ],
                thresholds: [],
                timeFrom: null,
                timeShift: null,
                title: 'QPS',
                tooltip: {
                  shared: false,
                  sort: 0,
                  value_type: 'individual',
                },
                type: 'graph',
                xaxis: {
                  buckets: null,
                  mode: 'time',
                  name: null,
                  show: true,
                  values: [],
                },
                yaxes: [
                  {
                    format: 'short',
                    label: null,
                    logBase: 1,
                    max: null,
                    min: 0,
                    show: true,
                  },
                  {
                    format: 'short',
                    label: null,
                    logBase: 1,
                    max: null,
                    min: null,
                    show: false,
                  },
                ],
              },
              {
                aliasColors: {},
                bars: false,
                dashLength: 10,
                dashes: false,
                datasource: '$datasource',
                fieldConfig: {
                  defaults: {
                    unit: 's',
                  },
                },
                fill: 1,
                id: 6,
                legend: {
                  avg: false,
                  current: false,
                  max: false,
                  min: false,
                  show: true,
                  total: false,
                  values: false,
                },
                lines: true,
                linewidth: 1,
                links: [],
                nullPointMode: 'null as zero',
                percentage: false,
                pointradius: 5,
                points: false,
                renderer: 'flot',
                seriesOverrides: [],
                spaceLength: 10,
                span: 6,
                stack: false,
                steppedLine: false,
                targets: [
                  {
                    exemplar: true,
                    expr: 'histogram_quantile(0.99, sum(rate(tns_request_duration_seconds_bucket{job=~"$namespace/db"}[$__rate_interval])) by (le)) * 1',
                    format: 'time_series',
                    intervalFactor: 2,
                    legendFormat: '99th Percentile',
                    refId: 'A',
                    step: 10,
                  },
                  {
                    exemplar: true,
                    expr: 'histogram_quantile(0.50, sum(rate(tns_request_duration_seconds_bucket{job=~"$namespace/db"}[$__rate_interval])) by (le)) * 1',
                    format: 'time_series',
                    intervalFactor: 2,
                    legendFormat: '50th Percentile',
                    refId: 'B',
                    step: 10,
                  },
                  {
                    exemplar: true,
                    expr: 'sum(rate(tns_request_duration_seconds_sum{job=~"$namespace/db"}[$__rate_interval])) * 1 / sum(rate(tns_request_duration_seconds_count{job=~"$namespace/db"}[$__rate_interval]))',
                    format: 'time_series',
                    intervalFactor: 2,
                    legendFormat: 'Average',
                    refId: 'C',
                    step: 10,
                  },
                ],
                thresholds: [],
                timeFrom: null,
                timeShift: null,
                title: 'Latency',
                tooltip: {
                  shared: false,
                  sort: 0,
                  value_type: 'individual',
                },
                type: 'timeseries',
                xaxis: {
                  buckets: null,
                  mode: 'time',
                  name: null,
                  show: true,
                  values: [],
                },
                yaxes: [
                  {
                    format: 's',
                    label: null,
                    logBase: 1,
                    max: null,
                    min: 0,
                    show: true,
                  },
                  {
                    format: 'short',
                    label: null,
                    logBase: 1,
                    max: null,
                    min: null,
                    show: false,
                  },
                ],
              },
            ],
            repeat: null,
            repeatIteration: null,
            repeatRowId: null,
            showTitle: true,
            title: 'DB',
            titleSize: 'h6',
          },
        ],
        schemaVersion: 14,
        style: 'dark',
        tags: [],
        templating: {
          list: [
            {
              current: {
                text: 'default',
                value: 'default',
              },
              hide: 0,
              label: null,
              name: 'datasource',
              options: [],
              query: 'prometheus',
              refresh: 1,
              regex: '',
              type: 'datasource',
            },
            {
              allValue: '.+',
              current: {
                selected: true,
                text: 'All',
                value: '$__all',
              },
              datasource: '$datasource',
              hide: 0,
              includeAll: true,
              label: 'namespace',
              multi: true,
              name: 'namespace',
              options: [],
              query: 'label_values(kube_pod_container_info{image=~".*grafana/tns.*"}, namespace)',
              refresh: 1,
              regex: '',
              sort: 2,
              tagValuesQuery: '',
              tags: [],
              tagsQuery: '',
              type: 'query',
              useTags: false,
            },
          ],
        },
        time: {
          from: 'now-1h',
          to: 'now',
        },
        timepicker: {
          refresh_intervals: [
            '5s',
            '10s',
            '30s',
            '1m',
            '5m',
            '15m',
            '30m',
            '1h',
            '2h',
            '1d',
          ],
          time_options: [
            '5m',
            '15m',
            '1h',
            '6h',
            '12h',
            '24h',
            '2d',
            '7d',
            '30d',
          ],
        },
        timezone: 'utc',
        title: 'Demo App',
        uid: '',
        version: 0,
      },
  },
}
