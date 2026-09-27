# AdGuard Home

This repository contains the hardened AdGuard Home image build and the source
Compose definition. The image is built from a pinned commit of upstream's
default `master` branch, including the matching frontend built with `npm ci`,
and runtime digests. GitHub Actions verifies the complete image before
publication to `ghcr.io/yusoofsh/adguardhome`.

## Lighthouse deployment

`deploy/lighthouse/adguard/compose.yaml` is a read-only snapshot of the live
AdGuard deployment on `yusoofs-lighthouse`. It intentionally references the
host's existing configuration, TLS directory, external Caddy network, and
environment file. `deploy/lighthouse/adguard/hook.sh` reloads AdGuard Home
after certificate renewal.

Runtime state, TLS material, and `.env` are not tracked. Copy
`.env.example` to `.env` and provide the values through the host's secret
management before deploying.

## Local checks

```sh
./verify-build.sh
```
