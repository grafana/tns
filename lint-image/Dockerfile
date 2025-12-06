# Build jsonnet
FROM alpine:3.23@sha256:51183f2cfa6320055da30872f211093f9ff1d3cf06f39a0bdb212314c5dc7375 AS jsonnet-builder
RUN apk add --no-cache git make g++
RUN git clone https://github.com/google/jsonnet && \
    git  -C jsonnet checkout v0.14.0 && \
    make -C jsonnet 2LDFLAGS=-static && \
    cp jsonnet/jsonnet /usr/bin && \
    cp jsonnet/jsonnetfmt /usr/bin

# Build jb
FROM golang:1.14.1-alpine3.11 AS jb-builder
RUN apk add --no-cache git make
RUN git clone https://github.com/jsonnet-bundler/jsonnet-bundler /jsonnet-bundler && \
    cd /jsonnet-bundler && \
    git checkout v0.2.0 && \
    make install

FROM alpine:3.23@sha256:51183f2cfa6320055da30872f211093f9ff1d3cf06f39a0bdb212314c5dc7375
RUN apk add --no-cache git make libgcc libstdc++ zip
COPY --from=jsonnet-builder /usr/bin/jsonnetfmt /usr/bin
COPY --from=jsonnet-builder /usr/bin/jsonnet /usr/bin
COPY --from=jb-builder /go/bin/jb /usr/bin
