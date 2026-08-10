# DNS-validated TLS proxy for `qyp.life`

This is a separate Docker Compose project for the existing `video-url-download` service. It builds Caddy with the Route 53 DNS module, obtains certificates for `qyp.life` and `*.qyp.life` through ACME DNS-01, and proxies only `la.qyp.life` to `video-url-download:8787` over that service's existing Docker network.

It does not change, recreate, or attach configuration to the upstream container. It does not bind host port `443`. The public endpoint is deliberately `https://la.qyp.life:8443`.

## Requirements

- The existing `video-url-download_default` Docker network and `video-url-download` container must already exist on the Pi.
- `la.qyp.life` must have a public A/AAAA record pointing to the Pi, and the Pi/router firewall must allow TCP `8443`.
- The Route 53 principal in `.env` needs permission to create and remove the temporary `_acme-challenge.qyp.life` TXT record. Do not put those credentials in GitHub or in this repository.
- The GitHub repository must allow the Actions `GITHUB_TOKEN` to publish packages, or the image package must be granted write access to this repository.

## Pi deployment

From this project directory on the Pi:

```text
cp .env.example .env
# Edit .env with the restricted Route 53 credentials.
docker compose pull
docker compose up -d
docker compose ps
```

The separate Compose project joins the already-existing `video-url-download_default` network as an external network. If that network is absent, Compose stops before it creates the proxy container; it never creates a replacement network or changes the upstream service.

Use `docker compose logs proxy` to confirm the DNS-01 certificate issuance. Test the live endpoint with:

```text
curl --fail --silent --show-error --head https://la.qyp.life:8443/health
```

## Image publication

Pushing `main` runs `.github/workflows/publish-image.yml`, which produces a single GHCR manifest for `linux/amd64` and `linux/arm64`. The Pi pulls the ARM64 variant automatically.

## Local checks

The static contract check does not require Docker:

```text
python3 -m unittest discover -s tests -v
```

On Windows PowerShell, use `py -3 -m unittest discover -s tests -v`. A Docker host can additionally run `docker compose config` and `docker build --platform linux/arm64 .`.
