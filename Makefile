.ONESHELL:
.DELETE_ON_ERROR:
SHELL       := bash
.SHELLFLAGS := -euf -o pipefail -c
MAKEFLAGS   += --warn-undefined-variables
MAKEFLAGS   += --no-builtin-rule

JSONNET_FILES := $(shell find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print)

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

app/.uptodate: app/app app/Dockerfile app/index.html.tmpl
	docker build -t $(DOCKER_IMAGE_BASE)/tns-app app/
	touch $@

loadgen/.uptodate: loadgen/loadgen loadgen/Dockerfile
	docker build -t $(DOCKER_IMAGE_BASE)/tns-loadgen loadgen/
	touch $@

clean:
	rm -f db/db app/app loadgen/loadgen db/.uptodate app/.uptodate loadgen/.uptodate

.PHONY: fmt-jsonnet
fmt-jsonnet: $(JSONNET_FILES)
	jsonnetfmt -i -- $?

.PHONY: lint-jsonnet
lint-jsonnet: $(JSONNET_FILES)
	@RESULT=0;
	for f in $?; do
		if !(jsonnetfmt -- "$$f" | diff -u "$$f" -); then
			RESULT=1
		fi
	done
	exit $$RESULT
