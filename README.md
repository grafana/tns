# TNS Observability Demo

A simple three-tier demo application, fully instrumented with Prometheus, OpenTracing and Go-kit logging.

The "TNS" name comes from "The New Stack", where the original demo code was used for [an article](https://thenewstack.io/how-to-detect-map-and-monitor-docker-containers-with-weave-scope-from-weaveworks/).

## Instructions

1. Build:

```sh
$ make
```

2. Run:

```sh
$ kubectl apply -f ./production/k8s-yamls
```

3. Monitoring with Prometheus

Requires [tanka](https://github.com/grafana/tanka) and a recent version of [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```sh
$ GO111MODULE=on go get github.com/grafana/tanka/cmd/tk@v0.5.0
$ go get github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
```

```sh
$ mkdir tanka; cd tanka
$ tk init
$ tk env set environments/default --server=https://kubernetes.docker.internal:6443 # if you're using docker desktop.
$ jb install github.com/grafana/jsonnet-libs/prometheus-ksonnet
$ jb install github.com/ksonnet/ksonnet-lib/ksonnet.beta.3/k.libsonnet
$ jb install github.com/ksonnet/ksonnet-lib/ksonnet.beta.3/k8s.libsonnet
```

Update environments/default/main.jsonnet to be:

```
local prometheus = import "prometheus-ksonnet/prometheus-ksonnet.libsonnet";

prometheus {
  local service = $.core.v1.service,
  _config+:: {
    namespace: "default",
  },

  prometheus_service+: $.prometheus {
    name: "prometheus",

    prometheus_container+::
        $.util.resourcesRequests('250m', '500Mi'),
  },

  // Expose the nginx admin frontend on port 30040 of the node.
  nginx_service+:
    service.mixin.spec.withType("NodePort") +
    service.mixin.spec.withPorts({
        nodePort: 30040,
        port: 8080,
        targetPort: 80,
    }),
}
```

Apply:

```sh
$ tk apply environments/default
```

Then go to http://localhost:30040/ to see the monitoring stack.

3b. Add dashboards for demo app

```sh
$ jb install https://github.com/grafana/tns/production/tns-mixin/
```
Update environments/default/main.jsonnet to be:

```
local prometheus = import "prometheus-ksonnet/prometheus-ksonnet.libsonnet";
local mixin = import "tns-mixin/mixin.libsonnet";

prometheus + mixin {
...
```

```sh
$ tk apply environments/default
```

4. Log Aggregation with Grafana Loki

```bash
$ helm init
$ helm repo add loki https://grafana.github.io/loki/charts
$ helm repo update
$ helm upgrade --install loki loki/loki-stack
```

Add a Loki datasource to Grafana, pointing at `https://loki.default.svc.cluster.local`.
