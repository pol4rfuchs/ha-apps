# UniFi Toolkit (Crosstalk Solutions, MIT) packaged for Home Assistant.
# Upstream is fetched at a pinned release tag + verified commit and is NOT
# patched; Ingress support lives in ingress/ingress_shim.py.
ARG BUILD_ARCH
ARG BUILD_FROM=ghcr.io/home-assistant/base-python:3.13-alpine3.24
# Upstream bump by hand: new tag + verified commit (UNIFI_TOOLKIT_COMMIT), regenerate constraints.txt;
# for Alpine.js / Chart.js update version and integrity hash together.

# ---------------------------------------------------------------- fetch stage
FROM ${BUILD_FROM} AS fetch

ARG UNIFI_TOOLKIT_VERSION=1.13.3
ARG UNIFI_TOOLKIT_COMMIT=05d38953fab7477275b4901ee8c6f2ffb65254b1
ARG ALPINEJS_VERSION=3.17.4
ARG ALPINEJS_INTEGRITY=sha512-N2gsr+58XVUt7OAPKnUGiKPDtkd+xbSGTae8C8IJxeRdkkhBJPIautkJ+qcwb7lcjJ/QK3/CPVIbN20JPvtK7A==
ARG CHARTJS_VERSION=4.4.1
ARG CHARTJS_INTEGRITY=sha512-C74QN1bxwV1v2PEujhmKjOZ7iUM4w6BWs23Md/6aOZZSlwMzeCIDGuZay++rBgChYru7/+QFeoQW0fQoP534Dg==

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

# Single RUN (hadolint DL3059). Upstream is cloned at the release tag and the
# commit is verified. Each npm tarball is verified against its registry
# integrity hash; the panel then makes no CDN calls.
RUN apk add --no-cache git curl openssl ca-certificates \
    && git clone --depth 1 --branch "v${UNIFI_TOOLKIT_VERSION}" \
        https://github.com/Crosstalk-Solutions/unifi-toolkit /src \
    && test "$(git -C /src rev-parse HEAD)" = "${UNIFI_TOOLKIT_COMMIT}" \
    && rm -rf /src/.git /src/.github /src/tests /src/unraid \
    && mkdir -p /vendor /tmp/npm \
    && fetch_pkg() { \
        name="$1"; version="$2"; integrity="$3"; \
        curl -fsSL "https://registry.npmjs.org/${name}/-/${name}-${version}.tgz" -o "/tmp/npm/${name}.tgz" \
        && actual="sha512-$(openssl dgst -sha512 -binary "/tmp/npm/${name}.tgz" | openssl base64 -A)" \
        && [ "${actual}" = "${integrity}" ] || { echo "integrity mismatch for ${name}" >&2; return 1; }; \
        tar -xzf "/tmp/npm/${name}.tgz" -C /tmp/npm; \
    } \
    && fetch_pkg alpinejs "${ALPINEJS_VERSION}" "${ALPINEJS_INTEGRITY}" \
    && cp /tmp/npm/package/dist/cdn.min.js /vendor/alpine.min.js \
    && rm -rf /tmp/npm/package \
    && fetch_pkg chart.js "${CHARTJS_VERSION}" "${CHARTJS_INTEGRITY}" \
    && cp /tmp/npm/package/dist/chart.umd.js /vendor/chart.umd.js

# --------------------------------------------------------------- runtime stage
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_VERSION

LABEL io.hass.arch="${BUILD_ARCH}" \
      io.hass.type="app" \
      io.hass.version="${BUILD_VERSION}" \
      org.opencontainers.image.title="UniFi Toolkit" \
      org.opencontainers.image.description="UniFi Toolkit (Crosstalk Solutions) for Home Assistant" \
      org.opencontainers.image.source="https://github.com/pol4rfuchs/ha-apps" \
      org.opencontainers.image.licenses="MIT"

COPY --from=fetch /src /app
COPY --from=fetch /vendor /opt/vendor

COPY constraints.txt /tmp/constraints.txt

RUN python3 -m pip install --no-cache-dir -c /tmp/constraints.txt -r /app/requirements.txt \
    && rm -f /tmp/constraints.txt \
    && rm -rf /app/data \
    && ln -s /data /app/data

COPY ingress /opt/ingress
COPY rootfs /

# Bytecode is compiled at build time; at runtime PYTHONDONTWRITEBYTECODE=1 keeps
# AppArmor from denying .pyc writes into the read-only /app and /opt.
RUN chmod +x \
      /etc/s6-overlay/s6-rc.d/unifi-toolkit/run \
      /etc/s6-overlay/s6-rc.d/unifi-toolkit/finish \
    && python3 -m compileall -q /app /opt/ingress

WORKDIR /app
EXPOSE 8000

# Exec form (no shell); a failed request raises and exits 1 = unhealthy.
# Loopback is allowed by the Ingress peer guard.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD ["python3", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=4)"]
