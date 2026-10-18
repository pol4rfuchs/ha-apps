"""Start the unmodified upstream UniFi Toolkit behind the Ingress shim.

Mirrors upstream run.py (preflight checks + Alembic migrations) but serves
``ingress_shim:app`` instead of ``app.main:app``. Upstream files stay untouched.
"""
import os
import sys

APP_DIR = os.environ.get("TOOLKIT_APP_DIR", "/app")
os.chdir(APP_DIR)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, APP_DIR)

import run  # noqa: E402  (module-level preflight: env checks, data dir check)

run.run_migrations()

import uvicorn  # noqa: E402

uvicorn.run(
    "ingress_shim:app",
    host="0.0.0.0",
    port=int(os.environ.get("APP_PORT", "8000")),
    log_level=os.environ.get("LOG_LEVEL", "INFO").lower(),
    proxy_headers=False,  # keep the real peer address for the Ingress guard
    access_log=False,
)
