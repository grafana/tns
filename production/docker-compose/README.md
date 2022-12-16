# Docker Compose Demo

This demo using docker-compose to bring up a complete stack with the demo app, including Grafana, Prometheus, Loki and Tempo.
The datasources and cross-datasource links should all be configured correctly.

To run:

```shell
$ docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions
$ docker-compose up -d
```

The navigate to http://localhost:3000 to see Grafana.

If you have any problems, run `docker-compose up -d` first.

Optionally, [enable docker metrics](https://docs.docker.com/config/daemon/prometheus/) by adding this to your docker config:

```json
{
  "metrics-addr" : "127.0.0.1:9323",
  "experimental" : true
}
```

## Using for local Grafana development
The datasources in this directory can be used to assist with local grafana development. Assumming you are running Grafana locally, comment out the `grafana` section of `docker-compose.yml` before running the above so docker does not start another grafana instance. Then, you will need to configure your locally running grafana to point to the datasources running in docker. You will want to take the `datasources.yaml` file provided and edit the 'isDefault' value to be false (assuming you already have a default datasource), create unique UIDs when defined and set the URLs to point to the right hostname and ports. The provisioning file with edits can go into your locally running grafana's `conf/provisioning/datasources` directory. Be sure to restart your locally running grafana instance to pick up the provisioning changes.

The TNS app spun up will be available at http://localhost:8001/ 

An example provisioning setup for local grafana looks like the following

```yaml 
apiVersion: 1
datasources:
  - name: 'prometheus-tns'
    type: prometheus
    url: http://localhost:9090/
    access: proxy
    editable: true
    isDefault: false
    jsonData:
        httpMethod: GET
    version: 1
    jsonData:
      exemplarTraceIdDestinations:
      - name: traceID
        datasourceUid: 'tempo-tns'
  - name: 'loki-tns'
    type: loki
    uid: 'loki-tns'
    access: proxy
    orgId: 1
    url: http://localhost:3100
    basicAuth: false
    isDefault: false
    version: 1
    editable: true
    apiVersion: 1
    jsonData:
      derivedFields:
        - name: TraceID
          datasourceUid: 'tempo-tns'
          matcherRegex: (?:traceID|trace_id)=(\w+)
          url: $${__value.raw}
  - name: 'tempo-tns'
    type: tempo
    uid: 'tempo-tns'
    url: http://localhost:8004
    access: proxy
    editable: true
    isDefault: false
    jsonData:
      httpMethod: GET
      tracesToLogs:
        datasourceUid: 'loki-tns'
        tags: ['job', 'instance', 'pod', 'namespace']
    version: 1
```