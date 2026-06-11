# ── Stage 1: Build ───────────────────────────────────────────────────────────
FROM node:22-alpine AS builder

WORKDIR /opt/ntfy-admin
COPY package*.json ./
COPY apps/api/package.json apps/api/
COPY apps/web/package.json apps/web/
RUN npm install --no-audit --no-fund --include=dev
COPY apps ./apps

# DL3003: use WORKDIR instead of cd
WORKDIR /opt/ntfy-admin/apps/api
RUN npm run build

WORKDIR /opt/ntfy-admin/apps/web
RUN npm run build

WORKDIR /opt/ntfy-admin
RUN npm prune --production

# ── Stage 2: Runtime (HA Add-on Base, s6-overlay v3, bashio) ─────────────────
FROM ghcr.io/hassio-addons/base:16.3.2

RUN apk add --no-cache \
    nodejs \
    nginx \
    curl \
    ca-certificates \
    && rm -rf /var/cache/apk/*

ENV NODE_ENV=production \
    API_PORT=3000 \
    SESSION_COOKIE_NAME=ntfy_admin_token

WORKDIR /opt/ntfy-admin

COPY --from=builder /opt/ntfy-admin/node_modules ./node_modules
COPY --from=builder /opt/ntfy-admin/apps/api/dist ./apps/api/dist
COPY --from=builder /opt/ntfy-admin/apps/api/package.json ./apps/api/package.json
COPY --from=builder /opt/ntfy-admin/apps/web/dist /usr/share/nginx/html/

# s6-overlay v3 Services + nginx.conf
COPY rootfs /

RUN mkdir -p /data/logs /run/nginx /var/log/nginx /var/lib/nginx/tmp \
    && find /etc/s6-overlay/s6-rc.d -name "run" -exec chmod a+x {} + \
    && rm -f /etc/nginx/http.d/default.conf

EXPOSE 8099

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://127.0.0.1:8099/ >/dev/null 2>&1 || exit 1
