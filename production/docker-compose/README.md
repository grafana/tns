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
## M Series Mac Notes
There is a possibility of encountering issues of `The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8) and no specific platform was requested ` even if the setting of `Use Rosetta for x86_64/amd64 emulation on Apple Silicon` is applied in Docker Dekstop. If this occurs, you can work around by setting the platform for the specific applications as seen below:
```yaml
  loadgen:
    platform: linux/amd64
```
Implementing the platform setting should alleviate the issues observed below:
```
✔ Network docker-compose_default                                                                                                                          Created                                                                                   0.0s 
 ✔ Container cadvisor                                                                                                                                      Started                                                                                   0.6s 
 ✔ Container docker-compose-grafana-1                                                                                                                      Started                                                                                   0.7s 
 ✔ Container docker-compose-tempo-1                                                                                                                        Started                                                                                   0.6s 
 ✔ Container node_exporter                                                                                                                                 Started                                                                                   0.6s 
 ✔ Container docker-compose-db-1                                                                                                                           Started                                                                                   0.6s 
 ✔ Container docker-compose-loki-1                                                                                                                         Started                                                                                   0.7s 
 ! cadvisor The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8) and no specific platform was requested                                                                                           0.0s 
 ! db The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8) and no specific platform was requested                                                                                                 0.0s 
 ✔ Container docker-compose-app-1                                                                                                                          Started                                                                                   0.6s 
 ! app The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8) and no specific platform was requested                                                                                                0.0s 
 ✔ Container docker-compose-loadgen-1                                                                                                                      Started                                                                                   0.7s 
 ! loadgen The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8) and no specific platform was requested                                                                                            0.0s 
 ✔ Container docker-compose-prometheus-1
```
After the change, success:
```
[+] Running 10/10
 ✔ Network docker-compose_default         Created                                                                                                                                                                                                    0.0s 
 ✔ Container docker-compose-tempo-1       Started                                                                                                                                                                                                    0.7s 
 ✔ Container node_exporter                Started                                                                                                                                                                                                    0.6s 
 ✔ Container docker-compose-loki-1        Started                                                                                                                                                                                                    0.7s 
 ✔ Container docker-compose-grafana-1     Started                                                                                                                                                                                                    0.7s 
 ✔ Container docker-compose-db-1          Started                                                                                                                                                                                                    0.6s 
 ✔ Container cadvisor                     Started                                                                                                                                                                                                    0.6s 
 ✔ Container docker-compose-app-1         Started                                                                                                                                                                                                    0.8s 
 ✔ Container docker-compose-loadgen-1     Started                                                                                                                                                                                                    0.9s 
 ✔ Container docker-compose-prometheus-1  Started
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

