# TNS Observability Demo

A simple three-tier demo application, fully instrumented with Prometheus, OpenTracing and Go-kit logging.

The "TNS" name comes from "The New Stack", where the original demo code was used for [an article](https://thenewstack.io/how-to-detect-map-and-monitor-docker-containers-with-weave-scope-from-weaveworks/).

## Instructions

1. Build:

```sh
# make
```

2. Run:

```sh
# kubectl apply -f ./production/k8s-yamls
```

3. Monitoring

```sh
# ks init ksonnet
# cd ksonnet
# jb install github.com/grafana/jsonnet-libs/prometheus-ksonnet
```

Update environments/default/main.jsonnet to be:

```
local prometheus = import "prometheus-ksonnet/prometheus-ksonnet.libsonnet";

prometheus {
  _config+:: {
    namespace: "default",
    stateful: true,
  },

  prometheus_container+:
     $.util.resourcesRequests('250m', '500Mi'),
}
```

Apply:

```sh
# ks apply default
```

4. Logging