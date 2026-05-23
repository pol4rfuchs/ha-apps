# SearXNG — Home Assistant Add-on

Privacy-respecting metasearch engine. Kein Tracking, keine Profile.

## Konfiguration

### Add-on Option

| Option | Typ | Standard | Beschreibung |
|---|---|---|---|
| `set_base_url_for_ingress` | bool | `true` | Setzt `SEARXNG_BASE_URL` automatisch auf die HA-Ingress-URL |

### SearXNG selbst

Nach dem Erststart liegt die Konfigurationsdatei unter:

```
addon_configs/<SLUG>_searxng/settings.yml
```

Bearbeitbar z.B. über den File Editor. Änderungen werden nach einem Add-on-Neustart aktiv.

Vollständige Doku: https://docs.searxng.org/admin/settings/index.html

### custom.sh Hook

In `addon_configs/<SLUG>_searxng/custom.sh` können eigene Shell-Befehle vor dem
SearXNG-Start eingetragen werden (z.B. Settings patchen, Plugins aktivieren).

## JSON API

```
http://homeassistant.local:8080/search?q=test&format=json
```

## Valkey/Redis (optional)

Im `settings.yml` unter `redis:` eintragen:

```yaml
redis:
  url: "valkey://SLUG-valkey:6379/0"
```
