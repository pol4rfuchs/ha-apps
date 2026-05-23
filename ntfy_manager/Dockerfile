ARG BUILD_FROM=ghcr.io/hassio-addons/base:14.3.2

# ── Build stage ──────────────────────────────────────────────────────────────
FROM node:22-alpine AS builder
WORKDIR /opt/ntfy-admin
COPY package*.json ./
COPY apps/api/package.json apps/api/
COPY apps/web/package.json apps/web/
RUN npm install --no-audit --no-fund --include=dev
COPY apps ./apps
RUN cd apps/api && npm run build
RUN cd apps/web && npm run build
RUN npm prune --production

# ── Runtime stage ────────────────────────────────────────────────────────────
FROM ${BUILD_FROM}
SHELL ["/bin/ash", "-o", "pipefail", "-c"]
ENV LANG=C.UTF-8 \
    NODE_ENV=production \
    API_PORT=3000 \
    WEB_PORT=8099 \
    SESSION_COOKIE_NAME=ntfy_admin_token

# Copy Node.js runtime from builder (avoids apk nodejs issue)
COPY --from=builder /usr/local/bin/node /usr/local/bin/node
COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/bin/node /usr/local/bin/node

RUN apk add --no-cache \
        nginx \
        openssl \
        curl \
        ca-certificates \
    && rm -rf /var/cache/apk/*

WORKDIR /opt/ntfy-admin
COPY --from=builder /opt/ntfy-admin/node_modules ./node_modules
COPY --from=builder /opt/ntfy-admin/apps/api/dist ./apps/api/dist
COPY --from=builder /opt/ntfy-admin/apps/web/dist /usr/share/nginx/html/
COPY rootfs /
RUN chmod +x /etc/services.d/ntfy-admin/run \
    && chmod +x /etc/services.d/nginx/run \
    && mkdir -p /data/logs /run/nginx /var/log/nginx /var/lib/nginx/tmp

EXPOSE 8099
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://127.0.0.1:8099/ >/dev/null 2>&1 || exit 1
