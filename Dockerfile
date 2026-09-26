# syntax=docker/dockerfile:1
# Build the exact deployed AdGuard Home source with the patched Go toolchain,
# then replace only the executable in the official runtime image.  The release
# frontend is supplied by AdGuard and checksum-verified; no npm build is used.

FROM golang:1.26.8-alpine@sha256:8ac98ca534ac3f51e1f420a1dd2c15e74c75cfa0f23f3ad27eb5d7236c349a0c AS builder

ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG X_CRYPTO_VERSION=v0.56.0
ARG X_TEXT_VERSION=v0.41.0

WORKDIR /src

# AdGuard Home commit a8be9b5e9ce0949a85456e4342bc5fdb8eb11a96.
ADD https://github.com/AdguardTeam/AdGuardHome/archive/a8be9b5e9ce0949a85456e4342bc5fdb8eb11a96.tar.gz /tmp/adguardhome-source.tar.gz
ADD https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.108.0-b.90/AdGuardHome_frontend.tar.gz /tmp/adguardhome-frontend.tar.gz
ADD https://github.com/AdguardTeam/AdGuardHome/releases/download/v0.108.0-b.90/checksums.txt /tmp/adguardhome-checksums.txt

RUN set -eux; \
	printf '%s  %s\n' \
		23e7c196830313e25020b7df8f692d294ba6dd82b568fe99355cf54550c14826 \
		/tmp/adguardhome-source.tar.gz \
		| sha256sum -c -; \
	frontend_sha="$(awk '$2 == "./AdGuardHome_frontend.tar.gz" { print $1 }' /tmp/adguardhome-checksums.txt)"; \
	test "$frontend_sha" = 9eeb662861e301ade16b47d820bc6fc9097c2e43bcf982368a800d0f765dc2d2; \
	printf '%s  %s\n' "$frontend_sha" /tmp/adguardhome-frontend.tar.gz | sha256sum -c -; \
	tar -xzf /tmp/adguardhome-source.tar.gz --strip-components=1 -C /src; \
	tar -xzf /tmp/adguardhome-frontend.tar.gz -C /src

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
	VERSION=v0.108.0-b.90 \
	REVISION=a8be9b5e9ce0949a85456e4342bc5fdb8eb11a96 \
	SOURCE_DATE_EPOCH=1785409946 \
	OUT=/out/AdGuardHome \
		sh ./scripts/make/go-build.sh; \
	go version -m /out/AdGuardHome | grep -F 'go1.26.8'; \
	go version -m /out/AdGuardHome | grep -F "golang.org/x/crypto ${X_CRYPTO_VERSION}"

# Keep all official runtime metadata, ports, entrypoint, and administrative
# capabilities.  Only the AdGuard executable and fixed OpenSSL packages are
# changed in the final image.
FROM adguard/adguardhome@sha256:2b77703b27730d5c0c7045fcd6c98834169cd5c69af5f86a43947425f2d367fd AS runtime

ARG SOURCE_COMMIT=a8be9b5e9ce0949a85456e4342bc5fdb8eb11a96
ARG SOURCE_DATE_EPOCH=1785409946
ARG VERSION=v0.108.0-b.90

LABEL org.opencontainers.image.created="2026-07-30T11:12:26Z" \
	org.opencontainers.image.revision="${SOURCE_COMMIT}" \
	org.opencontainers.image.version="${VERSION}"

# The official digest currently carries Alpine 3.23.5's OpenSSL 3.5.7-r0.
# Pin the compatible 3.5.8-r0 packages that contain CVE-2026-14456's fix.
RUN apk add --no-cache \
	'libcrypto3=3.5.8-r0' \
	'libssl3=3.5.8-r0'

COPY --from=builder --chown=nobody:nogroup --chmod=0755 /out/AdGuardHome /opt/adguardhome/AdGuardHome

# The official image grants this capability so DNS can bind to privileged
# ports without changing the container's administrative/root behavior.
RUN setcap 'cap_net_bind_service=+eip' /opt/adguardhome/AdGuardHome

WORKDIR /opt/adguardhome/work
ENTRYPOINT ["/opt/adguardhome/AdGuardHome"]
CMD ["--no-check-update", "-c", "/opt/adguardhome/conf/AdGuardHome.yaml", "-w", "/opt/adguardhome/work"]
