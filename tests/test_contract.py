from pathlib import Path
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class ProxyContractTests(unittest.TestCase):
    def test_caddy_uses_route53_dns_challenge(self) -> None:
        caddyfile = (PROJECT_ROOT / "Caddyfile").read_text()

        self.assertIn("dns route53", caddyfile)
        self.assertIn("https://{$TLS_HOSTNAME}:{$PUBLIC_HTTPS_PORT}", caddyfile)

    def test_compose_avoids_port_443_and_reuses_existing_network(self) -> None:
        compose_file = (PROJECT_ROOT / "compose.yaml").read_text()

        self.assertNotIn('"443:443"', compose_file)
        self.assertIn(':${PUBLIC_HTTPS_PORT:-8443}:8443"', compose_file)
        self.assertIn("external: true", compose_file)
        self.assertIn("video-url-download_default", compose_file)

    def test_workflow_publishes_arm64_image(self) -> None:
        workflow = (PROJECT_ROOT / ".github/workflows/publish-image.yml").read_text()

        self.assertIn("linux/arm64", workflow)
        self.assertIn("ghcr.io", workflow)
        self.assertIn("packages: write", workflow)


if __name__ == "__main__":
    unittest.main()
