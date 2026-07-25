# syntax=docker/dockerfile:1
# Home Assistant add-on build metadata lives here now.
# build.yaml is deprecated/no longer required by the HA add-on builder.

ARG BUILD_ARCH=unknown
ARG BUILD_VERSION=2.0.0
ARG TS6_MANAGER_REPO=https://github.com/pol4rfuchs/ts6-manager.git
ARG TS6_MANAGER_BRANCH=main
ARG TS6_MANAGER_REF=09573b64cadcf26786862fed2e24ad8641603ac1

# ─────────────────────────────────────────────
# Stage 1: Node build (backend + frontend), node:20-alpine
# ─────────────────────────────────────────────
FROM node:20-alpine AS builder

ARG TS6_MANAGER_REPO
ARG TS6_MANAGER_BRANCH
ARG TS6_MANAGER_REF

# DL3059: consolidated apk + corepack into one RUN
RUN apk add --no-cache git python3 make g++ openssl \
    && corepack enable && corepack prepare pnpm@9 --activate

WORKDIR /src
RUN git init . \
    && git remote add origin "${TS6_MANAGER_REPO}" \
    && git fetch --depth 1 origin "${TS6_MANAGER_REF}" \
    && git checkout --detach FETCH_HEAD

RUN pnpm install --frozen-lockfile

# DL3003: use WORKDIR instead of cd
WORKDIR /src/packages/backend
RUN npx prisma generate

# DL3059: consolidated build + deploy + cp into one RUN
# NOTE: unlike the previous single-container build, `prisma` (the CLI, not
# just @prisma/client) and schema.prisma now travel into /deploy/backend too —
# the final image needs them at *runtime* to run `prisma migrate deploy`
# against the persisted /data DB on every start (see ts6-init/up). A plain
# `pnpm deploy --prod` drops devDependencies, which is where the CLI lives.
WORKDIR /src
RUN pnpm run build \
    && pnpm deploy --filter @ts6/backend --prod /deploy/backend \
    && cp -r packages/backend/prisma /deploy/backend/prisma \
    && cp -r packages/backend/generated /deploy/backend/generated 2>/dev/null || true \
    && cp -r node_modules/.prisma /deploy/backend/node_modules/.prisma 2>/dev/null || true \
    && mkdir -p /deploy/backend/node_modules/.bin \
    && cp -r packages/backend/node_modules/prisma /deploy/backend/node_modules/prisma \
    && cp packages/backend/node_modules/.bin/prisma /deploy/backend/node_modules/.bin/prisma

# DL3003: use WORKDIR instead of cd
WORKDIR /src/packages/backend
RUN DATABASE_URL="file:/tmp/ts6webui-template.db" npx prisma db push --skip-generate

# ─────────────────────────────────────────────
# Stage 2: Go build (WebRTC media sidecar), golang:1.25-bookworm
# go.mod pins `go 1.25.0` — keep this base image's Go minor version in sync
# with packages/sidecar/go.mod on every upstream sync.
# ─────────────────────────────────────────────
FROM golang:1.25-bookworm AS sidecar-builder

WORKDIR /src
COPY --from=builder /src/packages/sidecar/go.mod /src/packages/sidecar/go.sum ./
RUN go mod download
COPY --from=builder /src/packages/sidecar/main.go .
# BUILD_ARCH -> GOARCH (HA only ever gives us aarch64/amd64, see §1)
ARG BUILD_ARCH=unknown
RUN case "${BUILD_ARCH}" in \
        aarch64) export GOARCH=arm64 ;; \
        amd64)   export GOARCH=amd64 ;; \
        *) echo "unsupported BUILD_ARCH=${BUILD_ARCH} for sidecar" >&2; exit 1 ;; \
    esac \
    && CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /sidecar main.go

# ─────────────────────────────────────────────
# Stage 3: Final image (HA hassio-addons base)
# ─────────────────────────────────────────────
FROM ghcr.io/hassio-addons/base:16.3.2

ARG BUILD_ARCH=unknown
ARG BUILD_VERSION=2.0.0
ARG TS6_MANAGER_REF

LABEL io.hass.name="TS6 Manager" \
      io.hass.description="Web-based management interface for TeamSpeak 6 servers" \
      io.hass.arch="${BUILD_ARCH}" \
      io.hass.type="addon" \
      io.hass.version="${BUILD_VERSION}" \
      maintainer="Pol4rFuchs" \
      org.opencontainers.image.source="https://github.com/pol4rfuchs/ts6-manager" \
      org.opencontainers.image.revision="${TS6_MANAGER_REF}"

# ffmpeg covers both yt-dlp/music-bot transcoding (existing) and the new
# sidecar's own RTCP/transcode needs (Dockerfile.sidecar installs it
# separately upstream because that repo ships sidecar as its own container —
# here it's one shared install for both processes).
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
COPY --from=sidecar-builder /sidecar /usr/local/bin/ts6-sidecar
COPY rootfs /

# SC2038+DL4006: replaced | xargs with -exec to avoid pipe + filename issues
# `finish` added (§11: every s6 long-run needs run+finish, or restarts crash-loop)
RUN find /etc/s6-overlay \( -name "run" -o -name "up" -o -name "finish" \) -exec chmod a+x {} + \
    && chmod a+x /usr/bin/ts6-init-run.sh /usr/local/bin/ts6-sidecar \
    && rm -f /etc/nginx/http.d/default.conf

VOLUME ["/data"]
