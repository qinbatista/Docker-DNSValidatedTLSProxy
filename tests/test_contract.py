from pathlib import Path
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class ProxyContractTests(unittest.TestCase):
    def test_dockerfile_declares_the_route53_module_version_in_the_builder_stage(self) -> None:
        dockerfile = (PROJECT_ROOT / "Dockerfile").read_text()

        self.assertIn("ARG ROUTE53_MODULE_VERSION=1.6.2", dockerfile)
        self.assertIn("FROM caddy:${CADDY_VERSION}-builder AS builder\n\nARG ROUTE53_MODULE_VERSION", dockerfile)
        self.assertIn("github.com/caddy-dns/route53@v${ROUTE53_MODULE_VERSION}", dockerfile)
        self.assertIn("setcap -r /usr/bin/caddy", dockerfile)

    def test_caddy_uses_route53_dns_challenge(self) -> None:
        caddyfile = (PROJECT_ROOT / "Caddyfile").read_text()

        self.assertIn("dns route53", caddyfile)
        self.assertIn("auto_https disable_redirects", caddyfile)
        self.assertIn("https://la.qyp.life:8443", caddyfile)
        self.assertIn("https://shortcut.la.qyp.life:8443", caddyfile)
        self.assertIn("https://downloads.la.qyp.life:8443", caddyfile)
        self.assertNotIn("*.qyp.life", caddyfile)
        self.assertIn("@video host la.qyp.life shortcut.la.qyp.life downloads.la.qyp.life", caddyfile)

    def test_compose_avoids_port_443_and_reuses_existing_network(self) -> None:
        compose_file = (PROJECT_ROOT / "compose.yaml").read_text()

        self.assertNotIn('"443:443"', compose_file)
        self.assertIn(":8443:8443\"", compose_file)
        self.assertIn("external: true", compose_file)
        self.assertIn("video-url-download_default", compose_file)

    def test_host_network_fallback_keeps_8443_and_adds_ipv6_ddns(self) -> None:
        compose_file = (PROJECT_ROOT / "compose.host-network.yaml").read_text()

        self.assertNotIn('"443:443"', compose_file)
        self.assertIn("network_mode: host", compose_file)
        self.assertIn("UPSTREAM_CONTAINER_NAME: 127.0.0.1", compose_file)
        self.assertIn('HOST_UPSTREAM_PORT:-8788', compose_file)
        self.assertIn("ipv6_ddns:", compose_file)
        self.assertIn("amazon/aws-cli@sha256:", compose_file)
        self.assertIn("SHORTCUT_TLS_HOSTNAME", compose_file)
        self.assertIn("SHORTCUT_ALIAS_HOSTNAME", compose_file)
        self.assertIn("update-ipv6-record", compose_file)

    def test_ipv6_ddns_script_updates_direct_and_alias_records(self) -> None:
        script = (PROJECT_ROOT / "scripts" / "update-ipv6-record.sh").read_text()

        self.assertIn("/proc/net/if_inet6", script)
        self.assertIn('"Type":"AAAA"', script)
        self.assertIn("list-resource-record-sets", script)
        self.assertIn("change-resource-record-sets", script)
        self.assertIn("IPV6_DDNS_DRY_RUN", script)
        self.assertIn("SHORTCUT_TLS_HOSTNAME", script)
        self.assertIn("SHORTCUT_ALIAS_HOSTNAME", script)
        self.assertIn('"Type":"CNAME"', script)
        self.assertIn("update_alias_record", script)
        self.assertIn('if [ "$run_once" = "true" ]; then', script)

    def test_workflow_publishes_arm64_image(self) -> None:
        workflow = (PROJECT_ROOT / ".github/workflows/publish-image.yml").read_text()

        self.assertIn("linux/arm64", workflow)
        self.assertIn("ghcr.io", workflow)
        self.assertIn("packages: write", workflow)


if __name__ == "__main__":
    unittest.main()
