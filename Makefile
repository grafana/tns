build: db/.uptodate app/.uptodate lb/.uptodate

DOCKER_IMAGE_BASE?=grafana
GOENV=GOOS=linux GOARCH=amd64 CGO_ENABLED=0 GO111MODULE=on

db/db: db/*.go
	env $(GOENV) go build -o $@ ./db

app/app: app/*.go
	env $(GOENV) go build -o $@ ./app

lb/lb: lb/*.go
	env $(GOENV) go build -o $@ ./lb

db/.uptodate: db/db db/Dockerfile
	docker build -t $(DOCKER_IMAGE_BASE)/tns-db db/

app/.uptodate: app/app app/Dockerfile
	docker build -t $(DOCKER_IMAGE_BASE)/tns-app app/

lb/.uptodate: lb/lb lb/Dockerfile
	docker build -t $(DOCKER_IMAGE_BASE)/tns-lb lb/

clean:
	rm -f db/db app/app lb/lb db/.uptodate app/.uptodate lb/.uptodate
