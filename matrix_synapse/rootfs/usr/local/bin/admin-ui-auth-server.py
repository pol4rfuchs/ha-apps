#!/usr/bin/env python3
"""
Minimal Basic-Auth wrapper around http.server for the Ketesa (Admin UI).

Replaces plain `python3 -m http.server`, which serves the admin UI to
anyone who can reach the port. Credentials come from environment
variables (set by the s6 run script from /data/matrix/.admin_ui_auth,
written by 10-matrix-init.sh) — never hardcoded, never logged here.
"""
import base64
import http.server
import os
import socketserver
import sys

USERNAME = os.environ.get("ADMIN_UI_USER", "")
PASSWORD = os.environ.get("ADMIN_UI_PASSWORD", "")
PORT = 8090

if not USERNAME or not PASSWORD:
    print("admin-ui-auth-server: ADMIN_UI_USER/ADMIN_UI_PASSWORD not set, refusing to start", file=sys.stderr)
    sys.exit(1)

EXPECTED = base64.b64encode(f"{USERNAME}:{PASSWORD}".encode()).decode()


class AuthHandler(http.server.SimpleHTTPRequestHandler):
    def _authed(self):
        auth = self.headers.get("Authorization", "")
        if not auth.startswith("Basic "):
            return False
        return auth.split(" ", 1)[1].strip() == EXPECTED

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

    def _request_auth(self):
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="Ketesa Admin UI"')
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"401 Unauthorized")

    def log_message(self, fmt, *args):
        # Keep default stderr logging, but never let Authorization headers show up in it
        sys.stderr.write("%s - - [%s] %s\n" % (self.client_address[0], self.log_date_time_string(), fmt % args))


if __name__ == "__main__":
    with socketserver.TCPServer(("0.0.0.0", PORT), AuthHandler) as httpd:
        print(f"admin-ui-auth-server: serving on :{PORT} with Basic-Auth")
        httpd.serve_forever()
