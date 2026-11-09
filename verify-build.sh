#!/bin/sh

# Static release-gate checks for the delegated AdGuard build context.  The
# actual multi-architecture build runs in the repository's GitHub workflow;
# this script deliberately does not require Docker or mutate a host runtime.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
dockerfile="$root/Dockerfile"

grep -F 'FROM golang:1.27.3-alpine@sha256:fa3d596898d9f126af7c01d14ee7597bab3f39cccf392ef36b69fe77cd681f18 AS builder' "$dockerfile" >/dev/null
grep -F 'FROM adguard/adguardhome:edge@sha256:31e95c4d10bec79cfc595aa15dc44e27b5098a9cbf3499f0de0057e57b2e813d AS runtime' "$dockerfile" >/dev/null
grep -F 'f44bb2281384d72007c337dc7898fc36852e9b76' "$dockerfile" >/dev/null
grep -F 'VERSION=v0.0.0-dev.0+f44bb22' "$dockerfile" >/dev/null
grep -F 'SOURCE_DATE_EPOCH=1794223430' "$dockerfile" >/dev/null
grep -F 'ARG X_CRYPTO_VERSION=v0.58.0' "$dockerfile" >/dev/null
grep -F 'ARG X_TEXT_VERSION=v0.43.0' "$dockerfile" >/dev/null
grep -F 'golang.org/x/crypto ${X_CRYPTO_VERSION}' "$dockerfile" >/dev/null
grep -F 'COkYLr4k7nDI4r6QtMML2AfzeIswWHAJthLS6K/M/54=' "$dockerfile" >/dev/null
grep -F 'Xh+kl5A+M0gMiWDytH2Hhr5Z7WbNCpv/eB/EFgfSk+w=' "$dockerfile" >/dev/null
grep -F 'golang.org/x/text ${X_TEXT_VERSION}' "$dockerfile" >/dev/null
grep -F '1QivrlhwAsnMOcqgOdl9my7s9OyZl8O5/UGUTJVXoWc=' "$dockerfile" >/dev/null
grep -F 'hbSIYA/amXcRXTFSZqh8tWHEoqRvvbKPJ2uz/KU+a+s=' "$dockerfile" >/dev/null
grep -F 'd4644b7e250e4481e92a3b839ba4e7721c08296c056c6edf2e452a2f14e9f521' "$dockerfile" >/dev/null
grep -F 'sha256:d888c0ae6c86d7866ff10c5aafdd9077b36aee6455b33dd270fb93c0dd5cef6f' "$dockerfile" >/dev/null
grep -F "libcrypto3>=3.5.8-r0" "$dockerfile" >/dev/null
grep -F "libssl3>=3.5.8-r0" "$dockerfile" >/dev/null
grep -F 'scripts/make/go-build.sh' "$dockerfile" >/dev/null
grep -F "setcap 'cap_net_bind_service=+eip'" "$dockerfile" >/dev/null
grep -F 'COPY --from=builder --chown=nobody:nogroup --chmod=0755' "$dockerfile" >/dev/null
grep -F 'ENTRYPOINT ["/opt/adguardhome/AdGuardHome"]' "$dockerfile" >/dev/null
grep -F 'CMD ["--no-check-update", "-c", "/opt/adguardhome/conf/AdGuardHome.yaml", "-w", "/opt/adguardhome/work"]' "$dockerfile" >/dev/null

grep -F 'COPY patches/ /tmp/patches/' "$dockerfile" >/dev/null
grep -F 'RUN apk add --no-cache patch' "$dockerfile" >/dev/null
grep -F 'patch -p1 -i "$p" || exit 1' "$dockerfile" >/dev/null
test -s "$root/patches/client_v2-tls-expiry-window.patch"

grep -F 'bun install --no-save' "$dockerfile" >/dev/null
grep -F 'bun run build-prod' "$dockerfile" >/dev/null
grep -F 'COPY --from=frontend /src/build/static /opt/adguardhome/build/static' "$dockerfile" >/dev/null

echo 'AdGuard build manifest checks passed.'
