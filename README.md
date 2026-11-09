# AdGuard Home

This repository contains the hardened AdGuard Home image build and the source
Compose definition. The image is built from a pinned commit of upstream's
default `master` branch, including the matching frontend built with Bun,
and runtime digests. The frontend build runs with Bun against the upstream
`package-lock.json` checksum. GitHub Actions verifies the complete image before
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

## Version tags

Each published build also has a `sha-<commit>` tag. To give a build a version, push a git tag named `vYYYY.MM.DD-ys.N` on a commit of `main` whose image has finished publishing. The `Tag released image` workflow then adds `ghcr.io/yusoofsh/adguardhome:YYYY.MM.DD-ys.N` to that exact image. It never moves a version tag that already exists, and a tag push does not rebuild or redeploy anything. Pin deployments to the version tag.
