# syntax=docker/dockerfile:1
# Home Assistant add-on build metadata lives here now.
# build.yaml is deprecated/no longer required by the HA add-on builder.

ARG BUILD_ARCH=unknown
ARG BUILD_VERSION=1.0.2
ARG TS6_MANAGER_REPO=https://github.com/clusterzx/ts6-manager.git
ARG TS6_MANAGER_BRANCH=main
ARG TS6_MANAGER_REF=dd26e57954feca794fcceac0fb982243897d9114

# ─────────────────────────────────────────────
# Stage 1: Build (node:20-alpine)
# ─────────────────────────────────────────────
FROM node:20-alpine AS builder

ARG TS6_MANAGER_REPO
ARG TS6_MANAGER_BRANCH
ARG TS6_MANAGER_REF

RUN apk add --no-cache git python3 make g++ openssl
RUN corepack enable && corepack prepare pnpm@9 --activate

WORKDIR /src
RUN git init . \
    && git remote add origin "${TS6_MANAGER_REPO}" \
    && git fetch --depth 1 origin "${TS6_MANAGER_REF}" \
    && git checkout --detach FETCH_HEAD

RUN pnpm install --frozen-lockfile
RUN cd packages/backend && npx prisma generate
RUN pnpm run build
RUN pnpm deploy --filter @ts6/backend --prod /deploy/backend
RUN cp -r packages/backend/prisma /deploy/backend/prisma
RUN cp -r packages/backend/generated /deploy/backend/generated 2>/dev/null || true
RUN cp -r node_modules/.prisma /deploy/backend/node_modules/.prisma 2>/dev/null || true
RUN cd packages/backend && DATABASE_URL="file:/tmp/ts6webui-template.db" npx prisma db push --skip-generate

# ─────────────────────────────────────────────
# Stage 2: Final image (HA hassio-addons base)
# ─────────────────────────────────────────────
FROM ghcr.io/hassio-addons/base:16.3.2

ARG BUILD_ARCH=unknown
ARG BUILD_VERSION=1.0.0
ARG TS6_MANAGER_REF

LABEL io.hass.name="TS6 Manager" \
      io.hass.description="Web-based management interface for TeamSpeak 6 servers" \
      io.hass.arch="${BUILD_ARCH}" \
      io.hass.type="addon" \
      io.hass.version="${BUILD_VERSION}" \
      maintainer="Pol4rFuchs" \
      org.opencontainers.image.source="https://github.com/clusterzx/ts6-manager" \
      org.opencontainers.image.revision="${TS6_MANAGER_REF}"

RUN apk add --no-cache \
        nginx \
        nodejs \
        npm \
        ffmpeg \
        python3 \
        py3-pip \
    && pip3 install --no-cache-dir yt-dlp \
    && rm -rf /var/cache/apk/* /root/.cache

WORKDIR /app
COPY --from=builder /deploy/backend ./
COPY --from=builder /tmp/ts6webui-template.db /app/ts6webui-template.db
COPY --from=builder /src/packages/frontend/dist /var/www/html
COPY rootfs /

RUN find /etc/s6-overlay -name "run" -o -name "up" | xargs chmod a+x \
    && chmod a+x /usr/bin/ts6-init-run.sh \
    && rm -f /etc/nginx/http.d/default.conf

VOLUME ["/data"]
