#!/bin/bash

CONTEXT=${1?CONTEXT required}

SRC=$(cd `dirname $0`; pwd)

# INITIALISE TANKA
mkdir tanka
cd tanka
tk init # Initialises Tanka, and downloads the Kubernetes libaries Tanka needs

# SET UP DEFAULT ENVIRONMENT
tk env set environments/default --server-from-context $CONTEXT # Configures the default environment to point to your Kubernetes cluster
cp $SRC/default/main.jsonnet environments/default/             # Copies the base configuration for your default (monitoring) namespace
jb install github.com/grafana/jsonnet-libs/prometheus-ksonnet  # Downloads the prometheus-ksonnet library, which also includes Grafana
jb install github.com/grafana/tns/production/tns-mixin/        # Downloads dashboards for the TNS demo. These will be added to Grafana
jb install github.com/grafana/loki/production/ksonnet/promtail # Downloads the Promtail library, for logging to Loki
tk apply environments/default                                  # Installs everything into the default namespace.

# SET UP JAEGER ENVIRONMENT
tk env add environments/jaeger --server-from-context $CONTEXT --namespace jaeger # Creates Jaeger env/namespace and connects it to cluster
cp $SRC/jaeger/main.jsonnet environments/jaeger/               # Copies the config for the Jaeger namespace into your Tanka setup
#jb install github.com/grafana/tns/production/jaeger/           # Downloads Jaeger library
cp -r ../production/jaeger lib/
tk apply environments/jaeger                                   # Installs Jaeger into Jaeger namespace.

# SET UP LOKI ENVIRONMENT
tk env add environments/loki --server-from-context $CONTEXT --namespace loki # Creates loki env/namespace and connects it to the cluster
cp $SRC/loki/main.jsonnet environments/loki/                     # Copies the config for TNS namespace
#jb install github.com/grafana/tns/production/loki/              # Downloads the library for the TNS demo application
cp -r ../production/loki lib/
tk apply environments/loki                                      # Installs the TNS demo into the TNS namespace.

# SET UP TNS ENVIRONMENT
tk env add environments/tns --server-from-context $CONTEXT --namespace tns # Creates tns env/namespace and connects it to the cluster
cp $SRC/tns/main.jsonnet environments/tns/                     # Copies the config for TNS namespace
#jb install github.com/grafana/tns/production/tns/              # Downloads the library for the TNS demo application
cp -r ../production/tns lib/
tk apply environments/tns                                      # Installs the TNS demo into the TNS namespace.

