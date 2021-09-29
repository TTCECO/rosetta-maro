# Copyright 2020 Coinbase, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Compile golang
FROM ubuntu:18.04 as golang-builder

RUN mkdir -p /app \
  && chown -R nobody:nogroup /app
WORKDIR /app

RUN apt-get update && apt-get install -y curl make gcc g++ git
ENV GOLANG_VERSION 1.16.8
ENV GOLANG_DOWNLOAD_SHA256 f32501aeb8b7b723bc7215f6c373abb6981bbc7e1c7b44e9f07317e1a300dce2
ENV GOLANG_DOWNLOAD_URL https://golang.org/dl/go$GOLANG_VERSION.linux-amd64.tar.gz

RUN curl -fsSL "$GOLANG_DOWNLOAD_URL" -o golang.tar.gz \
  && echo "$GOLANG_DOWNLOAD_SHA256  golang.tar.gz" | sha256sum -c - \
  && tar -C /usr/local -xzf golang.tar.gz \
  && rm golang.tar.gz

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

# Compile gttc
FROM golang-builder as gttc-builder

# VERSION: gttc v.0.2.3
RUN git clone -b dev-0x https://github.com/TTCECO/gttc \
  && cd gttc \
  && git checkout 2ab1966c9d5eb2a10816f7e85522eef194228077

RUN cd gttc \
  && make gttc

RUN mv gttc/build/bin/gttc /app/gttc \
  && rm -rf gttc

# Compile rosetta-maro
FROM golang-builder as rosetta-builder

# Use native remote build context to build in any directory
COPY . src
RUN cd src \
  && go build

RUN mv src/rosetta-maro /app/rosetta-maro \
  && mkdir /app/ethereum \
  && mv src/ethereum/call_tracer.js /app/ethereum/call_tracer.js \
  && mv src/ethereum/geth.toml /app/ethereum/geth.toml \
  && rm -rf src

## Build Final Image
FROM ubuntu:18.04

RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates

RUN mkdir -p /app \
  && chown -R nobody:nogroup /app \
  && mkdir -p /data \
  && chown -R nobody:nogroup /data

WORKDIR /app

# Copy binary from gttc-builder
COPY --from=gttc-builder /app/gttc /app/gttc

# Copy binary from rosetta-builder
COPY --from=rosetta-builder /app/ethereum /app/ethereum
COPY --from=rosetta-builder /app/rosetta-maro /app/rosetta-maro

# Set permissions for everything added to /app
RUN chmod -R 755 /app/*

CMD ["/app/rosetta-maro", "run"]
