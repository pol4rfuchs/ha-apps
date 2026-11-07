"""Answers on the NetBox port with 503 while the database is being migrated.

The first start (and every upgrade) can take several minutes. Without a listener, anyone opening the page
(or a reverse proxy) would see a refused connection instead of a hint that NetBox is still starting.
"""
from http.server import BaseHTTPRequestHandler, HTTPServer

BODY = b"NetBox is starting (database migration). Reload this page in a few minutes.\n"


class Handler(BaseHTTPRequestHandler):
    def _respond(self):
        self.send_response(503)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(BODY)))
        self.send_header("Retry-After", "30")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(BODY)

    do_GET = do_HEAD = do_POST = _respond

    def log_message(self, *_args):
        pass


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8001), Handler).serve_forever()
