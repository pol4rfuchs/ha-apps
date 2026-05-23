# Nginx Proxy Manager – Home Assistant Add-on

[![Release](https://img.shields.io/badge/version-2.1.0-blue)](https://codeberg.org/wuest3nfuchs/addon-nginx-proxy-manager)
[![HA OS](https://img.shields.io/badge/HAOS-compatible-green)](https://www.home-assistant.io/)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

Moderner, vollständig in Home Assistant OS integrierter **Nginx Proxy Manager** –
basierend auf dem offiziellen [jc21/nginx-proxy-manager](https://github.com/NginxProxyManager/nginx-proxy-manager) Image.

---

## Features

- 🔁 **Offizielles NPM-Image** als Basis – upstream-Updates automatisch nutzbar
- 🔐 **Secrets-Support** – DB-Passwort & JWT-Secret aus `secrets.yaml`
- 🗄️ **SQLite** (Standard) oder **MariaDB Add-on** Integration
- 🌐 **Ingress-Panel** – NPM UI direkt in der HA-Seitenleiste
- 🌙 **Dark Mode** – nativ via NPM UI
- 🛡️ **AppArmor-Profil** für sicheren Containerbetrieb
- 📦 **Backup-kompatibel** – Daten & Zertifikate im HA-Snapshot
- 🏗️ **Multi-Arch** – `amd64` + `aarch64`
- 🔒 **Let's Encrypt** inkl. DNS-01 / Cloudflare / Wildcard

---

## Installation

1. Repository in HA hinzufügen:
   `https://codeberg.org/wuest3nfuchs/addon-nginx-proxy-manager`
2. Add-on installieren
3. Konfigurieren & starten
4. UI über **Ingress** öffnen

Vollständige Doku: [DOCS.md](DOCS.md)

---

## Lizenz

MIT – siehe [LICENSE](LICENSE)
