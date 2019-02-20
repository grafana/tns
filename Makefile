build: db/.uptodate app/.uptodate loadgen/.uptodate

DOCKER_IMAGE_BASE?=grafana
GOENV=GOOS=linux GOARCH=amd64 CGO_ENABLED=0 GO111MODULE=on

db/db: db/*.go
	env $(GOENV) go build -o $@ ./db

app/app: app/*.go
	env $(GOENV) go build -o $@ ./app

loadgen/loadgen: loadgen/*.go
	env $(GOENV) go build -o $@ ./loadgen

db/.uptodate: db/db db/Dockerfile
	docker build -t $(DOCKER_IMAGE_BASE)/tns-db db/
	touch $@

app/.uptodate: app/app app/Dockerfile
	docker build -t $(DOCKER_IMAGE_BASE)/tns-app app/
	touch $@

loadgen/.uptodate: loadgen/loadgen loadgen/Dockerfile
	docker build -t $(DOCKER_IMAGE_BASE)/tns-loadgen loadgen/
	touch $@

clean:
	rm -f db/db app/app loadgen/loadgen db/.uptodate app/.uptodate loadgen/.uptodate
