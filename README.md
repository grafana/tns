# TNS Observability Demo

A simple three-tier demo application, fully instrumented with Prometheus, Jaeger and Loki logging.

The "TNS" name comes from "The New Stack", where the original demo code was used for [an article](https://thenewstack.io/how-to-detect-map-and-monitor-docker-containers-with-weave-scope-from-weaveworks/).

## Instructions

Installation requires `kubectl`, the Tanka tool and Jsonnet Bundler to be installed. 

1. Install Kubectl

This demo (and Tanka) assumes that you have `kubectl` installed and that you have configs
available for an empty cluster onto which you can install this demo. The cluster should 
be empty because the demo will install apps into many namespaces.

You can list your configured clusters/contexts with:

```sh
$ kubectl config get-contexts
```

2. Install Tanka

Install the 0.7.0 release of Tanka, available [here](https://github.com/grafana/tanka/releases/tag/v0.7.0).

3. Install Jsonnet Bundler
  
Install the 0.2.0 release of the Jsonnet Bundler, available [here](https://github.com/jsonnet-bundler/jsonnet-bundler/releases/tag/v0.2.0).

4. Checkout TNS code

```sh
$ git checkout https://github.com/grafana/tns
$ cd tns
```

5. Install all services

At this stage, you have two options. The steps required to get Prometheus, Grafana, Loki, 
Jaeger and the TNS demo app installed are all contained in the `production/sample/install.sh`
script. If you wish to understand what Tanka is doing, then look at that script, and 
follow the steps manually.

If however, you just want the applications installed, and are running on a computer with
a Bash shell (typically MacOS or Linux), just run this script. You will need to identify
the Kubernetes 'context' that you wish to interact with. Execute the script, providing 
the relevant context name:

```
$ production/sample/install.sh <CONTEXT>
```

This will download a lot of resources, and will ask you to confirm with `yes` before it
installs to each Kubernetes namespace.

## Accessing the Demo

You should now have all the applications installed. They should be accessible via an
Nginx service on 30040.

If you are using a local Kubernetes, you should be able to access these services 
via http://localhost:30040/. Exactly how you access this URL will depend on where your
Kubernetes cluster is hosted - you may need to enable a Load Balancer for example.

## Reviewing the Tanka Code
You will now have a `tanka` directory within your checkout that contains all of the 
Jsonnet resources that were needed to deploy this monitoring stack. To find out more
about Tanka, visit https://tanka.dev.

## Tracing Grafana Demo
This demo is currently wired up to run a development version of Grafana which includes
pre-released tracing features.

To use a different version of Grafana, remove this from `tanka/environments/default/main.jsonnet`:

```
_images+:: {
  grafana: "grafana/grafana-dev:explore-trace-ui-demo-b56f2a8ae23d399f6e170f439c058f4bdb08f0da-ubuntu",
},
```