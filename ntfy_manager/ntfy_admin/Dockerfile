ARG BUILD_FROM
FROM ${BUILD_FROM}

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

ENV LANG=C.UTF-8 \
    NODE_ENV=production \
    API_PORT=3000 \
    WEB_PORT=8099 \
    SESSION_COOKIE_NAME=ntfy_admin_token

# --- System packages -------------------------------------------------------
# nodejs/npm  : runtime + build for both API and Web
# nginx       : serves SPA + reverse proxies /api to API
# openssl     : random secret generation
# curl        : healthcheck
RUN apk add --no-cache \
        nodejs \
        npm \
        nginx \
        openssl \
        curl \
        ca-certificates \
    && rm -rf /var/cache/apk/*

WORKDIR /opt/ntfy-admin

# --- Install dependencies (cached layer) -----------------------------------
COPY package*.json ./
COPY apps/api/package.json apps/api/package.json
COPY apps/web/package.json apps/web/package.json

RUN npm install --no-audit --no-fund --include=dev

# --- Copy sources and build ------------------------------------------------
COPY apps ./apps

WORKDIR /opt/ntfy-admin/apps/api
RUN npm run build

WORKDIR /opt/ntfy-admin/apps/web
RUN npm run build

# --- Prune devDependencies after build -------------------------------------
WORKDIR /opt/ntfy-admin
RUN npm prune --production

# --- Stage runtime files ---------------------------------------------------
WORKDIR /opt/ntfy-admin
COPY rootfs /

RUN chmod +x /etc/services.d/ntfy-admin/run \
    && chmod +x /etc/services.d/nginx/run \
    && mkdir -p /data/logs /run/nginx /var/log/nginx /var/lib/nginx/tmp \
    && rm -rf /usr/share/nginx/html \
    && mkdir -p /usr/share/nginx/html \
    && cp -r /opt/ntfy-admin/apps/web/dist/. /usr/share/nginx/html/

EXPOSE 8099

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://127.0.0.1:8099/ >/dev/null 2>&1 || exit 1