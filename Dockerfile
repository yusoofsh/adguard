# syntax=docker/dockerfile:1
# Build the current upstream master source, including its frontend, with the
# patched Go toolchain, then retain the official runtime hardening.

FROM alpine:3.23@sha256:85fe1e81d6758c208f3e1eed4338a1997e19d4be002d4dd32d3100c9a8c010a0 AS source

ADD https://github.com/AdguardTeam/AdGuardHome/archive/fb7774fa5ca1da62e0bc5b09e5e5f408ed1c8514.tar.gz /tmp/adguardhome-source.tar.gz
RUN echo 'f63b7e56992ac1a5d0dd5cad923af9a7f373db37b1771184e96ca52579af563a  /tmp/adguardhome-source.tar.gz' | sha256sum -c - \
	&& mkdir -p /src \
	&& tar -xzf /tmp/adguardhome-source.tar.gz --strip-components=1 -C /src

FROM oven/bun:1-alpine@sha256:d888c0ae6c86d7866ff10c5aafdd9077b36aee6455b33dd270fb93c0dd5cef6f AS frontend

COPY --from=source /src/client_v2 /src/client_v2
COPY --from=source /src/.twosky.json /src/.twosky.json
WORKDIR /src/client_v2
RUN test "$(sha256sum package-lock.json | awk '{print $1}')" = \
	271ad1ba897727ac1ae870c349873b4ef314a64c9f1ec4ab93a68832aec96ea9 \
	&& bun install --no-save \
	&& bun run build-prod

FROM golang:1.27.2-alpine@sha256:f92b6ef800e499660581efdabdf25d9d817a9d124eaf900924f0504e7e27e12d AS builder

ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG X_CRYPTO_VERSION=v0.58.0
ARG X_TEXT_VERSION=v0.43.0

WORKDIR /src
COPY --from=source /src /src
COPY --from=frontend /src/build/static /src/build/static

ENV GOMAXPROCS=2 GOMEMLIMIT=2400MiB GOFLAGS=-p=2

RUN set -eux; \
	cd /src; \
	go mod edit -require="golang.org/x/crypto@${X_CRYPTO_VERSION}"; \
	go mod edit -require="golang.org/x/text@${X_TEXT_VERSION}"; \
	go mod download all; \
	grep -F "golang.org/x/crypto ${X_CRYPTO_VERSION} h1:COkYLr4k7nDI4r6QtMML2AfzeIswWHAJthLS6K/M/54=" go.sum; \
	grep -F "golang.org/x/crypto ${X_CRYPTO_VERSION}/go.mod h1:Xh+kl5A+M0gMiWDytH2Hhr5Z7WbNCpv/eB/EFgfSk+w=" go.sum; \
	grep -F "golang.org/x/text ${X_TEXT_VERSION} h1:1QivrlhwAsnMOcqgOdl9my7s9OyZl8O5/UGUTJVXoWc=" go.sum; \
	grep -F "golang.org/x/text ${X_TEXT_VERSION}/go.mod h1:hbSIYA/amXcRXTFSZqh8tWHEoqRvvbKPJ2uz/KU+a+s=" go.sum; \
	targetos="${TARGETOS:-linux}"; \
	targetarch="${TARGETARCH:-amd64}"; \
	targetvariant="${TARGETVARIANT:-}"; \
	goarm=''; \
	if [ "$targetarch" = arm ]; then \
		case "$targetvariant" in \
		v6) goarm=6 ;; \
		v7) goarm=7 ;; \
		*) echo "unsupported ARM variant: $targetvariant" >&2; exit 1 ;; \
		esac; \
	fi; \
	GOOS="$targetos" \
	GOARCH="$targetarch" \
	GOARM="$goarm" \
	CGO_ENABLED=0 \
	CHANNEL=beta \
	VERSION=v0.0.0-dev.0+fb7774f \
	REVISION=fb7774fa5ca1da62e0bc5b09e5e5f408ed1c8514 \
	SOURCE_DATE_EPOCH=1792132736 \
	OUT=/out/AdGuardHome \
		sh ./scripts/make/go-build.sh; \
	go version -m /out/AdGuardHome | grep -F 'go1.27.2'; \
	go version -m /out/AdGuardHome | awk -v expected="${X_CRYPTO_VERSION}" '$1 == "dep" && $2 == "golang.org/x/crypto" && $3 == expected { found = 1 } END { exit !found }'

# Keep all official runtime metadata, ports, entrypoint, and administrative
# capabilities.  Replace the executable and frontend with the matching master
# source build, plus fixed OpenSSL packages.
FROM adguard/adguardhome:edge@sha256:31e95c4d10bec79cfc595aa15dc44e27b5098a9cbf3499f0de0057e57b2e813d AS runtime

ARG SOURCE_COMMIT=fb7774fa5ca1da62e0bc5b09e5e5f408ed1c8514
ARG SOURCE_DATE_EPOCH=1792132736
ARG VERSION=v0.0.0-dev.0+fb7774f

LABEL org.opencontainers.image.created="2026-10-16T06:38:56Z" \
	org.opencontainers.image.revision="${SOURCE_COMMIT}" \
	io.yusoofsh.upstream.revision="${SOURCE_COMMIT}" \
	org.opencontainers.image.version="${VERSION}" \
	org.opencontainers.image.source="https://github.com/yusoofsh/adguard"

# Retain the patched OpenSSL minimum while accepting newer compatible packages
# supplied by the pinned upstream runtime's package repositories.
RUN apk add --no-cache \
	'libcrypto3>=3.5.8-r0' \
	'libssl3>=3.5.8-r0'

COPY --from=builder --chown=nobody:nogroup --chmod=0755 /out/AdGuardHome /opt/adguardhome/AdGuardHome
COPY --from=frontend /src/build/static /opt/adguardhome/build/static

# The official image grants this capability so DNS can bind to privileged
# ports without changing the container's administrative/root behavior.
RUN setcap 'cap_net_bind_service=+eip' /opt/adguardhome/AdGuardHome

WORKDIR /opt/adguardhome/work
ENTRYPOINT ["/opt/adguardhome/AdGuardHome"]
CMD ["--no-check-update", "-c", "/opt/adguardhome/conf/AdGuardHome.yaml", "-w", "/opt/adguardhome/work"]
