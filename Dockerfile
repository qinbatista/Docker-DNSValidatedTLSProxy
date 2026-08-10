ARG CADDY_VERSION=2.11.3
ARG ROUTE53_MODULE_VERSION=1.6.2

FROM caddy:${CADDY_VERSION}-builder AS builder

ARG ROUTE53_MODULE_VERSION

RUN xcaddy build --with github.com/caddy-dns/route53@v${ROUTE53_MODULE_VERSION}

FROM caddy:${CADDY_VERSION}

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile

EXPOSE 8443
