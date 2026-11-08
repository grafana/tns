# Build jsonnet
FROM alpine:3.23@sha256:469c9ea410b9215eaee7976ba6c0639039b444be8e5d638f7abbada189971eb2 AS jsonnet-builder
RUN apk add --no-cache git make g++
RUN git clone https://github.com/google/jsonnet && \
    git  -C jsonnet checkout v0.14.0 && \
    make -C jsonnet LDFLAGS=-static jsonnet jsonnetfmt && \
    cp jsonnet/jsonnet /usr/bin && \
    cp jsonnet/jsonnetfmt /usr/bin

# Build jb
FROM golang:1.14.1-alpine3.11 AS jb-builder
RUN apk add --no-cache git make
RUN git clone https://github.com/jsonnet-bundler/jsonnet-bundler /jsonnet-bundler && \
    cd /jsonnet-bundler && \
    git checkout v0.2.0 && \
    make install

FROM alpine:3.23@sha256:469c9ea410b9215eaee7976ba6c0639039b444be8e5d638f7abbada189971eb2
RUN apk add --no-cache git make zip
COPY --from=jsonnet-builder /usr/bin/jsonnetfmt /usr/bin
COPY --from=jsonnet-builder /usr/bin/jsonnet /usr/bin
COPY --from=jb-builder /go/bin/jb /usr/bin
