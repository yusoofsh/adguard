# syntax=docker/dockerfile:1
# Build the current upstream master source, including its frontend, with the
# patched Go toolchain, then retain the official runtime hardening.

FROM alpine:3.23@sha256:85fe1e81d6758c208f3e1eed4338a1997e19d4be002d4dd32d3100c9a8c010a0 AS source

ADD https://github.com/AdguardTeam/AdGuardHome/archive/b08c2e5418081888269d5009f01dfbaa8c8af253.tar.gz /tmp/adguardhome-source.tar.gz
RUN echo '89f2630904a97d06b66c1e31f349f6f6dcef35e222a2b19f58a7ba07e108ac3a  /tmp/adguardhome-source.tar.gz' | sha256sum -c - \
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

FROM golang:1.26.8-alpine@sha256:8ac98ca534ac3f51e1f420a1dd2c15e74c75cfa0f23f3ad27eb5d7236c349a0c AS builder

ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG X_CRYPTO_VERSION=v0.56.0
ARG X_TEXT_VERSION=v0.41.0

WORKDIR /src
COPY --from=source /src /src
COPY --from=frontend /src/build/static /src/build/static

RUN set -eux; \
	cd /src; \
	go mod edit -require="golang.org/x/crypto@${X_CRYPTO_VERSION}"; \
	go mod edit -require="golang.org/x/text@${X_TEXT_VERSION}"; \
	go mod download all; \
	grep -F "golang.org/x/crypto ${X_CRYPTO_VERSION} h1:GUh5Ii4J5jtcseSMiRqr1jXCNHoxjeV9Fmekc2oLy6Y=" go.sum; \
	grep -F "golang.org/x/crypto ${X_CRYPTO_VERSION}/go.mod h1:OMW5y6CY9l38uPLmxU6l6pwcXp1obtLo3e6gT7gQR2I=" go.sum; \
	grep -F "golang.org/x/text ${X_TEXT_VERSION} h1:vz/seA0lnX87Othu2f/0L24RcgrXD9/YFTSuGjj3rH8=" go.sum; \
	grep -F "golang.org/x/text ${X_TEXT_VERSION}/go.mod h1:jvf1O8ajNzZqhSrQBPbutR/EB83Cc0CFrezNQIwbb5M=" go.sum; \
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
	VERSION=v0.0.0-dev.0+b08c2e5 \
	REVISION=b08c2e5418081888269d5009f01dfbaa8c8af253 \
	SOURCE_DATE_EPOCH=1790344104 \
	OUT=/out/AdGuardHome \
		sh ./scripts/make/go-build.sh; \
	go version -m /out/AdGuardHome | grep -F 'go1.26.8'; \
	go version -m /out/AdGuardHome | awk -v expected="${X_CRYPTO_VERSION}" '$1 == "dep" && $2 == "golang.org/x/crypto" && $3 == expected { found = 1 } END { exit !found }'

# Keep all official runtime metadata, ports, entrypoint, and administrative
# capabilities.  Replace the executable and frontend with the matching master
# source build, plus fixed OpenSSL packages.
FROM adguard/adguardhome@sha256:2b77703b27730d5c0c7045fcd6c98834169cd5c69af5f86a43947425f2d367fd AS runtime

ARG SOURCE_COMMIT=b08c2e5418081888269d5009f01dfbaa8c8af253
ARG SOURCE_DATE_EPOCH=1790344104
ARG VERSION=v0.0.0-dev.0+b08c2e5

LABEL org.opencontainers.image.created="2026-07-30T11:12:26Z" \
	org.opencontainers.image.revision="${SOURCE_COMMIT}" \
	org.opencontainers.image.version="${VERSION}" \
	org.opencontainers.image.source="https://github.com/yusoofsh/adguard"

# The official digest currently carries Alpine 3.23.5's OpenSSL 3.5.7-r0.
# Pin the compatible 3.5.8-r0 packages that contain CVE-2026-14456's fix.
RUN apk add --no-cache \
	'libcrypto3=3.5.8-r0' \
	'libssl3=3.5.8-r0'

COPY --from=builder --chown=nobody:nogroup --chmod=0755 /out/AdGuardHome /opt/adguardhome/AdGuardHome
COPY --from=frontend /src/build/static /opt/adguardhome/build/static

# The official image grants this capability so DNS can bind to privileged
# ports without changing the container's administrative/root behavior.
RUN setcap 'cap_net_bind_service=+eip' /opt/adguardhome/AdGuardHome

WORKDIR /opt/adguardhome/work
ENTRYPOINT ["/opt/adguardhome/AdGuardHome"]
CMD ["--no-check-update", "-c", "/opt/adguardhome/conf/AdGuardHome.yaml", "-w", "/opt/adguardhome/work"]
