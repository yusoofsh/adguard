#!/bin/sh

# Static release-gate checks for the delegated AdGuard build context.  The
# actual multi-architecture build runs in the repository's GitHub workflow;
# this script deliberately does not require Docker or mutate a host runtime.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
dockerfile="$root/Dockerfile"

grep -F 'FROM golang:1.26.8-alpine@sha256:8ac98ca534ac3f51e1f420a1dd2c15e74c75cfa0f23f3ad27eb5d7236c349a0c AS builder' "$dockerfile" >/dev/null
grep -F 'FROM adguard/adguardhome@sha256:2b77703b27730d5c0c7045fcd6c98834169cd5c69af5f86a43947425f2d367fd AS runtime' "$dockerfile" >/dev/null
grep -F 'a8be9b5e9ce0949a85456e4342bc5fdb8eb11a96' "$dockerfile" >/dev/null
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
grep -F '23e7c196830313e25020b7df8f692d294ba6dd82b568fe99355cf54550c14826' "$dockerfile" >/dev/null
grep -F '9eeb662861e301ade16b47d820bc6fc9097c2e43bcf982368a800d0f765dc2d2' "$dockerfile" >/dev/null
grep -F "libcrypto3=3.5.8-r0" "$dockerfile" >/dev/null
grep -F "libssl3=3.5.8-r0" "$dockerfile" >/dev/null
grep -F 'scripts/make/go-build.sh' "$dockerfile" >/dev/null
grep -F "setcap 'cap_net_bind_service=+eip'" "$dockerfile" >/dev/null
grep -F 'COPY --from=builder --chown=nobody:nogroup --chmod=0755' "$dockerfile" >/dev/null
grep -F 'ENTRYPOINT ["/opt/adguardhome/AdGuardHome"]' "$dockerfile" >/dev/null
grep -F 'CMD ["--no-check-update", "-c", "/opt/adguardhome/conf/AdGuardHome.yaml", "-w", "/opt/adguardhome/work"]' "$dockerfile" >/dev/null

if grep -Ev '^[[:space:]]*#' "$dockerfile" | grep -Eiq '(^|[^a-z])(npm|node)([^a-z]|$)'; then
	echo 'frontend must remain the checksum-verified release archive' >&2
	exit 1
fi

echo 'AdGuard build manifest checks passed.'
