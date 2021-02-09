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
