# Docker-DNSValidatedTLSProxy

- `Dockerfile` builds Caddy with the Route 53 DNS module for the fixed Linux container runtime.
- `Caddyfile` owns DNS-01 certificate issuance and reverse proxying to the existing `video-url-download` container.
- `compose.yaml` owns the isolated proxy container, its non-443 listener, persistent Caddy state, and external upstream network attachment.
- `.github/workflows/publish-image.yml` publishes the AMD64/ARM64 image to GHCR.
- The proxy must not publish port 443 or alter the upstream container/network; DNS and AWS credentials remain only in the Pi's untracked `.env`.
- For Docker host-loss recovery, follow `skills/docker-disaster-recovery/SKILL.md`; stage and verify Drive bundles before restoring runtime paths.
