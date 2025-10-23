.ONESHELL:
.DELETE_ON_ERROR:
SHELL       := sh
MAKEFLAGS   += --warn-undefined-variables
MAKEFLAGS   += --no-builtin-rule


build: db/.uptodate app/.uptodate loadgen/.uptodate lint-image/.uptodate
publish: db/.published app/.published loadgen/.published lint-image/.published

IMAGE_TAG?=$(shell git rev-parse --short HEAD)
DOCKER_IMAGE_BASE?=grafana
GOENV=GOOS=linux GOARCH=$(shell go env GOARCH) CGO_ENABLED=0 GO111MODULE=on

db/db: db/*.go
	env $(GOENV) go build -o $@ ./db

app/app: app/*.go
	env $(GOENV) go build -o $@ ./app

loadgen/loadgen: loadgen/*.go
	env $(GOENV) go build -o $@ ./loadgen

db/.uptodate: db/db db/Dockerfile
	docker build -t $(DOCKER_IMAGE_BASE)/tns-db db/
	docker tag $(DOCKER_IMAGE_BASE)/tns-db $(DOCKER_IMAGE_BASE)/tns-db:$(IMAGE_TAG)
	touch $@

app/.uptodate: app/app app/Dockerfile app/index.html.tmpl
	docker build -t $(DOCKER_IMAGE_BASE)/tns-app app/
	docker tag $(DOCKER_IMAGE_BASE)/tns-app $(DOCKER_IMAGE_BASE)/tns-app:$(IMAGE_TAG)
	touch $@

loadgen/.uptodate: loadgen/loadgen loadgen/Dockerfile
	docker build -t $(DOCKER_IMAGE_BASE)/tns-loadgen loadgen/
	docker tag $(DOCKER_IMAGE_BASE)/tns-loadgen $(DOCKER_IMAGE_BASE)/tns-loadgen:$(IMAGE_TAG)
	touch $@

lint-image/.uptodate: lint-image/Dockerfile
	docker build -t $(DOCKER_IMAGE_BASE)/tns-lint:$(IMAGE_TAG) lint-image/
	touch $@

db/.published: db/.uptodate
	docker push $(DOCKER_IMAGE_BASE)/tns-db:$(IMAGE_TAG)

app/.published: app/.uptodate
	docker push $(DOCKER_IMAGE_BASE)/tns-app:$(IMAGE_TAG)

loadgen/.published: loadgen/.uptodate
	docker push $(DOCKER_IMAGE_BASE)/tns-loadgen:$(IMAGE_TAG)

lint-image/.published: lint-image/.uptodate
	docker push $(DOCKER_IMAGE_BASE)/tns-lint:$(IMAGE_TAG)

clean:
	rm -f db/db app/app loadgen/loadgen db/.uptodate app/.uptodate loadgen/.uptodate lint-image/.{uptodate,published}


JSONNET_FILES := $(shell find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print)

.PHONY: fmt-jsonnet
fmt-jsonnet: $(JSONNET_FILES)
	jsonnetfmt -i -- $?

.PHONY: lint-jsonnet
lint-jsonnet: $(JSONNET_FILES)
	@RESULT=0;
	for f in $?; do \
		if !(jsonnetfmt -- "$$f" | diff -u "$$f" -); then \
			RESULT=1; \
		fi; \
	done
	exit $$RESULT
