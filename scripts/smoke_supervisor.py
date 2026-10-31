#!/usr/bin/env python3
"""
smoke_supervisor.py
-------------------
Helper for the smoke test in .github/workflows/build-app.yaml.

  fixture <app> <dir>   writes <dir>/options.json: the `options:` from
                        <app>/config.yaml, required fields without a value
                        filled in (random passwords, none of them are in the
                        repo), plus SMOKE_OVERRIDES for values that matter.
  serve <options.json>  small stand-in for the Supervisor API. bashio does not
                        read the options from /data/options.json but via
                        http://supervisor/addons/self/options/config. Without
                        this stand-in almost every app ends with
                        "Could not resolve host: supervisor".

Deliberate limits: no ingress, no services (MQTT, MySQL), no effect for
POST requests. Unknown paths answer {"result": "ok", "data": {}}.
"""

import argparse
import json
import os
import re
import secrets
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

# Values a placeholder does not satisfy (startup checks of the apps).
SMOKE_OVERRIDES = {
    # 10-matrix-init.sh aborts on first start with a placeholder domain.
    "matrix_synapse": {"server_name": "smoke.test"},
    # run.sh exits without an accepted license.
    "teamspeak6": {"license_accepted": True},
    # The default is mysql on core-mariadb, which does not exist in the smoke test.
    "nextcloud": {"db_type": "sqlite"},
    "forgejo": {"domain": "localhost"},
    "cortendesk": {"app_url": "http://localhost"},
    # Schema is str, but it ends up as a number in the bridge config.
    "matrix_telegram_bridge": {"telegram_api_id": "12345"},
}


def dummy_for(schema_type: str):
    """Placeholder for a required field, based on the schema type."""
    base = schema_type.split("(", 1)[0]
    if base == "password":
        return secrets.token_hex(16)
    if base == "email":
        return "smoke@smoke.test"
    if base == "url":
        return "http://localhost"
    if base in ("int", "port"):
        m = re.match(r"int\((\d+),", schema_type)
        return int(m.group(1)) if m else 1
    if base == "float":
        return 1.0
    if base == "bool":
        return False
    if base == "list":
        return schema_type[len("list(") : -1].split("|")[0]
    return "smoke"


def build_options(app: str) -> dict:
    import yaml  # only needed here; serve runs via sudo without pyyaml

    cfg = yaml.safe_load(Path(app, "config.yaml").read_text(encoding="utf-8")) or {}
    options = dict(cfg.get("options") or {})
    for key, typ in (cfg.get("schema") or {}).items():
        if not isinstance(typ, str) or typ.endswith("?"):
            continue
        if options.get(key) in (None, ""):
            options[key] = dummy_for(typ)
    options.update(SMOKE_OVERRIDES.get(app, {}))
    return options


def cmd_fixture(args) -> None:
    out = Path(args.dir)
    out.mkdir(parents=True, exist_ok=True)
    options = build_options(args.app)
    (out / "options.json").write_text(json.dumps(options), encoding="utf-8")
    print(f"Wrote {out}/options.json with keys: {sorted(options)}")


def cmd_serve(args) -> None:
    options = json.loads(Path(args.options).read_text(encoding="utf-8"))
    info = {
        "name": args.app,
        "slug": args.app,
        "description": "smoke test",
        "version": args.version,
        "version_latest": args.version,
        "update_available": False,
        "state": "started",
        "arch": ["amd64"],
        "hostname": args.app.replace("_", "-"),
        "ip_address": "172.17.0.2",
        "ingress": False,
        "ingress_entry": "",
        "ingress_url": "",
        "ingress_port": 0,
        "options": options,
    }
    routes = {
        "/addons/self/options/config": options,
        "/addons/self/info": info,
        "/info": {
            "supervisor": "smoke",
            "homeassistant": "smoke",
            "hassos": None,
            "operating_system": "smoke",
            "machine": "qemux86-64",
            "arch": "amd64",
            "hostname": "smoke",
        },
        # A primary interface as on real hardware: matrix_synapse derives the
        # LAN IP from it (10-matrix-init.sh), otherwise it ends up in the fallback.
        "/network/info": {
            "interfaces": [
                {
                    "interface": "eth0",
                    "type": "ethernet",
                    "enabled": True,
                    "connected": True,
                    "primary": True,
                    "ipv4": {"method": "auto", "address": ["192.168.1.10/24"]},
                }
            ],
            "docker": {"address": "172.30.32.0/23"},
        },
    }

    class Handler(BaseHTTPRequestHandler):
        def _reply(self) -> None:
            path = self.path.split("?", 1)[0]
            body = json.dumps({"result": "ok", "data": routes.get(path, {})}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        do_GET = do_POST = _reply

        def log_message(self, fmt, *a) -> None:
            sys.stderr.write(f"supervisor-mock: {self.command} {self.path}\n")

    server = ThreadingHTTPServer((args.bind, args.port), Handler)
    if args.daemon:
        # The port is bound before the parent process returns. The child process
        # detaches from the terminal and only writes to the log, so the CI step
        # does not wait on its open stdout/stderr.
        if os.fork():
            return
        os.setsid()
        log = os.open(args.log, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
        null = os.open(os.devnull, os.O_RDONLY)
        os.dup2(null, 0)
        os.dup2(log, 1)
        os.dup2(log, 2)
    server.serve_forever()


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    sub = p.add_subparsers(dest="cmd", required=True)
    f = sub.add_parser("fixture")
    f.add_argument("app")
    f.add_argument("dir")
    f.set_defaults(func=cmd_fixture)
    s = sub.add_parser("serve")
    s.add_argument("options")
    s.add_argument("--app", default="smoke")
    s.add_argument("--version", default="0.0.0")
    s.add_argument("--bind", default="0.0.0.0")
    s.add_argument("--port", type=int, default=80)
    s.add_argument("--daemon", action="store_true", help="run in the background")
    s.add_argument("--log", default="supervisor-mock.log", help="log file in --daemon mode")
    s.set_defaults(func=cmd_serve)
    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
