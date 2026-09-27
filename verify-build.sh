#!/bin/sh

# Static release-gate checks for the delegated AdGuard build context.  The
# actual multi-architecture build runs in the repository's GitHub workflow;
# this script deliberately does not require Docker or mutate a host runtime.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
dockerfile="$root/Dockerfile"

grep -F 'FROM golang:1.26.8-alpine@sha256:8ac98ca534ac3f51e1f420a1dd2c15e74c75cfa0f23f3ad27eb5d7236c349a0c AS builder' "$dockerfile" >/dev/null
grep -F 'FROM adguard/adguardhome@sha256:2b77703b27730d5c0c7045fcd6c98834169cd5c69af5f86a43947425f2d367fd AS runtime' "$dockerfile" >/dev/null
grep -F 'b08c2e5418081888269d5009f01dfbaa8c8af253' "$dockerfile" >/dev/null
grep -F 'VERSION=v0.0.0-dev.0+b08c2e5' "$dockerfile" >/dev/null
grep -F 'SOURCE_DATE_EPOCH=1790344104' "$dockerfile" >/dev/null
grep -F 'ARG X_CRYPTO_VERSION=v0.56.0' "$dockerfile" >/dev/null
grep -F 'ARG X_TEXT_VERSION=v0.41.0' "$dockerfile" >/dev/null
grep -F 'golang.org/x/crypto ${X_CRYPTO_VERSION}' "$dockerfile" >/dev/null
grep -F 'GUh5Ii4J5jtcseSMiRqr1jXCNHoxjeV9Fmekc2oLy6Y=' "$dockerfile" >/dev/null
grep -F 'OMW5y6CY9l38uPLmxU6l6pwcXp1obtLo3e6gT7gQR2I=' "$dockerfile" >/dev/null
grep -F 'golang.org/x/text ${X_TEXT_VERSION}' "$dockerfile" >/dev/null
grep -F 'vz/seA0lnX87Othu2f/0L24RcgrXD9/YFTSuGjj3rH8=' "$dockerfile" >/dev/null
grep -F 'jvf1O8ajNzZqhSrQBPbutR/EB83Cc0CFrezNQIwbb5M=' "$dockerfile" >/dev/null
grep -F '89f2630904a97d06b66c1e31f349f6f6dcef35e222a2b19f58a7ba07e108ac3a' "$dockerfile" >/dev/null
grep -F 'sha256:d888c0ae6c86d7866ff10c5aafdd9077b36aee6455b33dd270fb93c0dd5cef6f' "$dockerfile" >/dev/null
grep -F "libcrypto3=3.5.8-r0" "$dockerfile" >/dev/null
grep -F "libssl3=3.5.8-r0" "$dockerfile" >/dev/null
grep -F 'scripts/make/go-build.sh' "$dockerfile" >/dev/null
grep -F "setcap 'cap_net_bind_service=+eip'" "$dockerfile" >/dev/null
grep -F 'COPY --from=builder --chown=nobody:nogroup --chmod=0755' "$dockerfile" >/dev/null
grep -F 'ENTRYPOINT ["/opt/adguardhome/AdGuardHome"]' "$dockerfile" >/dev/null
grep -F 'CMD ["--no-check-update", "-c", "/opt/adguardhome/conf/AdGuardHome.yaml", "-w", "/opt/adguardhome/work"]' "$dockerfile" >/dev/null

grep -F 'bun install --no-save' "$dockerfile" >/dev/null
grep -F 'bun run build-prod' "$dockerfile" >/dev/null
grep -F 'COPY --from=frontend /src/build/static /opt/adguardhome/build/static' "$dockerfile" >/dev/null

echo 'AdGuard build manifest checks passed.'
