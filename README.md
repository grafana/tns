# TNS Observability Demo

A simple three-tier demo application, fully instrumented with Prometheus, Jaeger and Loki logging.

The "TNS" name comes from "The New Stack", where the original demo code was used for [an article](https://thenewstack.io/how-to-detect-map-and-monitor-docker-containers-with-weave-scope-from-weaveworks/).

## Prerequisites

There are a set of tools you will need to download and install. We recommend you place
them into your `/usr/local/bin` directory after downloading.

### Docker
This demo assumes you have Docker installed. Follow instructions [here](https://docs.docker.com/install/) for more details.

### k3d
To run this demo, you need a Kubernetes cluster. While the demo should work against any 
Kubernetes cluster, these docs will assume a locally running `k3d` cluster. Download and
install `k3d` from [here](https://github.com/rancher/k3d/releases/tag/v1.6.0). Note that the instructions below work specifically for v1.6.0 of k3d. The later versions of k3d work very differently and it is important to use v1.6.

### kubectl
`kubectl` is used to interact with Kubernetes clusters. Follow the instructions
[here](https://kubernetes.io/docs/tasks/tools/install-kubectl/) to install it.

### tanka
Tanka uses the Jsonnet language to interact with Kubernetes, via the `kubectl` tool.
Download and install it from [here](https://github.com/grafana/tanka/releases/tag/v0.7.1).

### jsonnet-bundler
Jsonnet bundler downloads Jsonnet dependencies. Download and install it from 
[here](https://github.com/jsonnet-bundler/jsonnet-bundler/releases/tag/v0.4.0).). Rename the downloaded binary to jb and move it to the location where $PATH points. Also make sure the  binary is executable:
```
$ chmod +x /usr/local/bin/jb
```

## Instructions

If you wish to use a Kubernetes cluster other than a local `k3d` one, please adjust these
instructions accordingly.

1. Clone TNS repository
```sh
$ git clone https://github.com/grafana/tns
$ cd tns
```

2. Install K3D Cluster
```sh
$ ./create-k3d-cluster
$ export KUBECONFIG="$(k3d get-kubeconfig --name='tns')"
```

3. Install TNS applications
This step will ask you to confirm `yes` four times.
```sh
$ ./install
```

4. Wait
It will take some time to install the demo - there's a lot of downloading to do.
It is not unreasonable for it to take over ten minutes for everything to
download then start up.

This command will show you the status of the cluster:

```sh
$ kubectl get pods -A
```
All pods should be listed as either `running` or `completed`. If this is the case,
your cluster should be ready for use.

## Accessing the Demo

You should now be able to access the demo via [http://localhost:8080/](http://localhost:8080).

## Reviewing the Tanka Code
This installation will have created a `tanka` directory in your TNS checkout. This
directory contains all of the Jsonnet resources used to install this demo.
You will now have a `tanka` directory within your checkout that contains all of the 
Jsonnet resources that were needed to deploy this monitoring stack. To find out more
about Tanka, visit https://tanka.dev.

## Disabling/enabling your cluster
Should you wish to disable your cluster, use this command:

```sh
$ k3d stop -name tns
```
To re-enable it, do this:
```sh
$ k3d start -name tns
```

## Removing the Cluster
Once you have finished with the cluster, this should remove it and leave you ready to
recreate it on another occasion:
```sh
$ k3d delete --name tns
$ rm -rf tanka
```
