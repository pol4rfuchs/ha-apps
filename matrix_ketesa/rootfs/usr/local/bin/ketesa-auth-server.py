#!/usr/bin/env python3
"""Basic-auth static file server for the Ketesa admin UI.

Serves the unpacked Ketesa release (a static single-page app) from KETESA_ROOT
and refuses every request that does not carry the configured credentials.
Plain `python3 -m http.server` would serve the admin UI to anyone who can reach
the port.

Configuration (environment, set by the s6 run script):
  KETESA_USER / KETESA_PASSWORD  credentials (required, never logged)
  KETESA_ROOT                    directory to serve (default /opt/ketesa)
  KETESA_PORT                    listen port (default 8091)
  KETESA_LOG_LEVEL               DEBUG | INFO | WARNING | ERROR (default INFO)
"""
import base64
import hmac
import http.server
import logging
import os
import sys
from functools import partial

USERNAME = os.environ.get("KETESA_USER", "")
PASSWORD = os.environ.get("KETESA_PASSWORD", "")
ROOT = os.environ.get("KETESA_ROOT", "/opt/ketesa")
PORT = int(os.environ.get("KETESA_PORT", "8091"))
LEVEL = os.environ.get("KETESA_LOG_LEVEL", "INFO").upper()

logging.basicConfig(
    stream=sys.stderr,
    level=getattr(logging, LEVEL, logging.INFO),
    format="%(levelname)s ketesa: %(message)s",
)
log = logging.getLogger("ketesa")

if not USERNAME or not PASSWORD:
    log.error("KETESA_USER/KETESA_PASSWORD not set, refusing to start")
    sys.exit(1)

EXPECTED = base64.b64encode(f"{USERNAME}:{PASSWORD}".encode())


class AuthHandler(http.server.SimpleHTTPRequestHandler):
    server_version = "ketesa-auth"
    sys_version = ""

    def _authed(self):
        auth = self.headers.get("Authorization", "")
        if not auth.startswith("Basic "):
            return False
        # Constant-time comparison, so response timing does not leak the credentials
        return hmac.compare_digest(auth.split(" ", 1)[1].strip().encode(), EXPECTED)

    def _request_auth(self):
        log.warning("%s: request without valid credentials: %s %s", self.client_address[0], self.command, self.path)
        body = b"401 Unauthorized\n"
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="Ketesa Admin UI"')
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def end_headers(self):
        self.send_header("X-Content-Type-Options", "nosniff")
        super().end_headers()

    def do_GET(self):
        if not self._authed():
            self._request_auth()
            return
        super().do_GET()

    def do_HEAD(self):
        if not self._authed():
            self._request_auth()
            return
        super().do_HEAD()

    def log_message(self, fmt, *args):
        # Request lines only at DEBUG; the Authorization header is never part of them
        log.debug("%s %s", self.client_address[0], fmt % args)


if __name__ == "__main__":
    if not os.path.isfile(os.path.join(ROOT, "index.html")):
        log.error("no index.html in %s, refusing to start", ROOT)
        sys.exit(1)
    handler = partial(AuthHandler, directory=ROOT)
    # Threaded: a single slow or stalled client must not block the whole UI
    with http.server.ThreadingHTTPServer(("0.0.0.0", PORT), handler) as httpd:
        log.info("serving %s on :%d with basic auth (log level %s)", ROOT, PORT, LEVEL)
        httpd.serve_forever()
