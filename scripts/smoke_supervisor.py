#!/usr/bin/env python3
"""
smoke_supervisor.py
-------------------
Hilfsmittel für den Smoke-Test in .github/workflows/build-app.yaml.

  fixture <app> <dir>   schreibt <dir>/options.json: die `options:` aus
                        <app>/config.yaml, Pflichtfelder ohne Wert gefüllt
                        (Passwörter zufällig, nichts davon steht im Repo),
                        plus SMOKE_OVERRIDES für Werte mit Bedeutung.
  serve <options.json>  kleiner Ersatz für die Supervisor-API. bashio liest die
                        Optionen nicht aus /data/options.json, sondern über
                        http://supervisor/addons/self/options/config. Ohne
                        diesen Ersatz endet fast jede App mit
                        "Could not resolve host: supervisor".

Bewusste Grenzen: kein Ingress, keine Services (MQTT, MySQL), keine
POST-Wirkung. Unbekannte Pfade antworten {"result": "ok", "data": {}}.
"""

import argparse
import json
import os
import re
import secrets
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

# Werte, die ein Platzhalter nicht erfüllt (Startprüfungen der Apps).
SMOKE_OVERRIDES = {
    # 10-matrix-init.sh bricht beim ersten Start mit Platzhalter-Domain ab.
    "matrix_synapse": {"server_name": "smoke.test"},
    # run.sh beendet sich ohne akzeptierte Lizenz.
    "teamspeak6": {"license_accepted": True},
    # Standard ist mysql auf core-mariadb, das gibt es im Smoke-Test nicht.
    "nextcloud": {"db_type": "sqlite"},
    "forgejo": {"domain": "localhost"},
    "cortendesk": {"app_url": "http://localhost"},
    # Schema str, landet aber als Zahl in der Bridge-Config.
    "matrix_telegram_bridge": {"telegram_api_id": "12345"},
}


def dummy_for(schema_type: str):
    """Platzhalter für ein Pflichtfeld anhand des Schema-Typs."""
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
    import yaml  # nur hier gebraucht; serve läuft per sudo ohne pyyaml

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
        # Ein primäres Interface wie auf echter Hardware: matrix_synapse leitet
        # daraus die LAN-IP ab (10-matrix-init.sh), sonst landet es im Fallback.
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
        # Port ist gebunden, bevor der Elternprozess zurückkehrt. Der Kindprozess
        # löst sich vom Terminal und schreibt nur ins Log, damit der CI-Schritt
        # nicht auf seine offenen stdout/stderr wartet.
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
    s.add_argument("--daemon", action="store_true", help="im Hintergrund laufen")
    s.add_argument("--log", default="supervisor-mock.log", help="Log im --daemon-Modus")
    s.set_defaults(func=cmd_serve)
    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
