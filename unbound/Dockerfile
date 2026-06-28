# ARGs used in a FROM instruction must be declared before the *first* FROM
# in the whole file, or buildx silently fails to resolve them in later
# stages ("base name (${BUILD_FROM}) should not be blank" — see
# moby/moby#38379). Both belong here, not next to their respective stages.
ARG BUILD_FROM=ghcr.io/hassio-addons/base:21.0.0
ARG UNBOUND_VERSION=1.25.1

# ---------------------------------------------------------------------------
# Stage 1: build Unbound from source.
#
# Alpine 3.24 stable's apk repo still ships Unbound 1.24.2 (1.25.1 only
# landed in the `edge` branch on 2026-05-20, after the 3.24 stable freeze).
# 1.25.1 fixes 11 CVEs including a DNSSEC-validation RCE (CVE-2026-33278),
# so we build it ourselves instead of waiting for a stable apk backport.
#
# Built against the same Alpine 3.24 userland as the runtime stage, so no
# musl/openssl/libevent ABI mismatch versus a mixed apk@edge install.
# ---------------------------------------------------------------------------
FROM alpine:3.24 AS unbound-builder

ARG UNBOUND_VERSION

RUN apk add --no-cache \
    build-base \
    openssl-dev \
    libevent-dev \
    expat-dev \
    curl

RUN set -euo pipefail && \
    curl --fail --location --show-error --silent \
      --output /tmp/unbound.tar.gz \
      "https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz" && \
    mkdir -p /tmp/src && \
    tar -xzf /tmp/unbound.tar.gz -C /tmp/src --strip-components=1 && \
    cd /tmp/src && \
    ./configure \
      --prefix=/usr \
      --sysconfdir=/etc \
      --localstatedir=/var \
      --with-pidfile="" \
      --with-run-dir=/var/lib/unbound \
      --with-username=unbound \
      --with-libevent \
      --with-pthreads \
      --with-ssl \
      --enable-subnet \
      --disable-rpath && \
    make -j"$(nproc)" && \
    make DESTDIR=/build-out install

# ---------------------------------------------------------------------------
# Stage 2: runtime image.
#
# Base bumped 20.2.0 -> 21.0.0: this is the release that fixes the addon
# startup banner to call bashio::app.* instead of the deprecated
# bashio::addon.* functions (which were hitting a now-403'd Supervisor
# store endpoint on every start). See hassio-addons/app-base PR #389.
# ---------------------------------------------------------------------------
FROM ${BUILD_FROM}

# Bring in the self-built Unbound (binaries, libs, man pages, default conf).
COPY --from=unbound-builder /build-out/ /

# apk's `unbound` package normally creates this system user via its
# pre-install script; since we no longer install that package, create it
# ourselves so --with-username=unbound (and our own chown calls below)
# resolve to a real, stable user.
RUN addgroup -S unbound && \
    adduser -S -D -H -h /var/run/unbound -s /sbin/nologin -G unbound -g unbound unbound

# Runtime libraries for the self-built Unbound, plus python/flask and the
# rest of the web UI stack. No `unbound` apk package here anymore.
RUN apk add --no-cache --upgrade libcrypto3 libssl3 && \
    apk add --no-cache \
    libevent \
    libexpat \
    bash \
    jq \
    curl \
    drill \
    python3 \
    py3-flask \
    py3-waitress \
    openssl \
    ca-certificates-bundle

# Create necessary directories and download root hints
RUN mkdir -p \
      /etc/unbound \
      /var/lib/unbound \
      /data && \
    curl \
      --fail \
      --location \
      --show-error \
      --silent \
      --connect-timeout 10 \
      --max-time 30 \
      --output /etc/unbound/root.hints \
      https://www.internic.net/domain/named.root && \
    unbound-anchor -a /var/lib/unbound/root.key || true && \
    chown unbound:unbound \
      /var/lib/unbound && \
    chmod 0755 /var/lib/unbound && \
    chmod 0644 /etc/unbound/root.hints && \
    if [ -f /var/lib/unbound/root.key ]; then \
      chown unbound:unbound /var/lib/unbound/root.key; \
      chmod 0644 /var/lib/unbound/root.key; \
    fi

# Set up unbound-control keys for stats access
RUN unbound-control-setup && \
    find /etc/unbound -type d -exec chmod 0755 {} \; && \
    find /etc/unbound -type f -exec chmod 0644 {} \;

# Copy web application
COPY web/ /web/

# Copy run script
COPY run.sh /
RUN chmod 0755 /run.sh

# Health check: verify unbound responds to DNS queries
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD drill @127.0.0.1 -p 53 localhost || exit 1

# Expose DNS ports and ingress port
EXPOSE 53/tcp 53/udp 2137

CMD ["/run.sh"]
