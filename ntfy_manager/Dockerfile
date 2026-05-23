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
FROM node:22-alpine
RUN apk add --no-cache nginx curl ca-certificates openssl \
    && rm -rf /var/cache/apk/*

ENV NODE_ENV=production \
    API_PORT=3000 \
    WEB_PORT=8099 \
    SESSION_COOKIE_NAME=ntfy_admin_token

WORKDIR /opt/ntfy-admin
COPY --from=builder /opt/ntfy-admin/node_modules ./node_modules
COPY --from=builder /opt/ntfy-admin/apps/api/dist ./apps/api/dist
COPY --from=builder /opt/ntfy-admin/apps/web/dist /usr/share/nginx/html/
COPY rootfs/etc/nginx /etc/nginx
RUN mkdir -p /data/logs /run/nginx /var/log/nginx /var/lib/nginx/tmp

COPY rootfs/etc/services.d/ntfy-admin/run /start-api.sh
RUN chmod +x /start-api.sh

EXPOSE 8099
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://127.0.0.1:8099/ >/dev/null 2>&1 || exit 1

CMD ["sh", "-c", "nginx && node /opt/ntfy-admin/apps/api/dist/index.js"]
