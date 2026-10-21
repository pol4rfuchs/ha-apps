# CortenDesk

RustDesk-Console mit eingebautem ID-Server (hbbs) und Relay (hbbr) in einem Container.
Dünner Home-Assistant-Wrapper um das Upstream-Image `ghcr.io/marcpope/cortendesk`.

**Status:** experimental. Inoffizielle Community-App: Sie wird vom Upstream-Autor weder unterstützt noch empfohlen.
Fehler im Paket (Wrapper, Optionen, Home-Assistant-Anbindung) bitte im Repository
[pol4rfuchs/ha-apps](https://github.com/pol4rfuchs/ha-apps/issues) melden, Fehler in CortenDesk selbst bei
[marcpope/cortendesk](https://github.com/marcpope/cortendesk/issues).

Siehe [DOCS.md](DOCS.md) für Konfiguration, Ports und bekannte Einschränkungen.

## Installation

1. Repository in Home Assistant unter Einstellungen → Apps → App-Store hinzufügen.
2. **CortenDesk** installieren.
3. In der Konfiguration `app_url` und `admin_password` setzen, App starten.
4. Console unter `http://<ha-host>:21114` öffnen.

## Links

- Upstream (Console): <https://github.com/marcpope/cortendesk>
- Upstream (Server-Fork): <https://github.com/marcpope/cortendesk-server>

## Lizenz

Wrapper-Dateien dieser App: AGPL-3.0, wie die Upstream-Projekte. CortenDesk ist ab 1.11.0
vollständig AGPL-3.0 bzw. unter permissiven Lizenzen der gebündelten Bibliotheken (Bootstrap,
Remix Icon, ApexCharts, Figtree); Details in der `NOTICE` des Upstream-Repos und der `NOTICE` dieser App. Der Upstream-Quellcode der verwendeten Version steht unter dem Tag `v<Version>` in `marcpope/cortendesk` (Version siehe `CORTENDESK_VERSION` im Dockerfile). Der Autor
(Marc Pope) hat die Weitergabe als HA-App ausdrücklich erlaubt (Issue #89).
