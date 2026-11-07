"""Settings of the Home Assistant app. Loaded by the upstream configuration loader after configuration.py;
the values come from the app options through the environment (see /usr/local/lib/netbox-ha/common.sh)."""
from os import environ
from os.path import isfile

# Uploaded scripts and reports must survive a new container, so they live in /data.
SCRIPTS_ROOT = "/data/netbox/scripts"
REPORTS_ROOT = "/data/netbox/reports"

# Plugins from the "plugins" option (installed into /data/netbox/plugins by the init script).
PLUGINS = [name for name in environ.get("HA_NETBOX_PLUGINS", "").split() if name]
PLUGINS_CONFIG = {}

# log_level option: Django and NetBox loggers write to the container log at the chosen level.
_LEVEL = environ.get("HA_NETBOX_LOG_LEVEL", "INFO")
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {"plain": {"format": "%(asctime)s %(levelname)s %(name)s: %(message)s"}},
    "handlers": {"console": {"class": "logging.StreamHandler", "formatter": "plain"}},
    "loggers": {
        "django": {"handlers": ["console"], "level": _LEVEL},
        "netbox": {"handlers": ["console"], "level": _LEVEL},
    },
}

# Optional user settings: /config/extra.py (host path /addon_configs/<id>_netbox/extra.py). It runs in this
# module's namespace, so it can fill PLUGINS_CONFIG or override any other setting.
_EXTRA = "/config/extra.py"
if isfile(_EXTRA):
    with open(_EXTRA, encoding="utf-8") as _file:
        exec(compile(_file.read(), _EXTRA, "exec"))  # noqa: S102
