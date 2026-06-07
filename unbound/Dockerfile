ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install unbound, python/flask, and dependencies
RUN apk add --no-cache \
    unbound \
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
      /var/run/unbound \
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
      /var/lib/unbound \
      /var/run/unbound && \
    chmod 0755 /var/lib/unbound && \
    chmod 0750 /var/run/unbound && \
    chmod 0644 /etc/unbound/root.hints && \
    if [ -f /var/lib/unbound/root.key ]; then \
      chown unbound:unbound /var/lib/unbound/root.key; \
      chmod 0640 /var/lib/unbound/root.key; \
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
