"""Home Assistant Ingress shim for the unmodified UniFi Toolkit.

Upstream hard-codes absolute URLs ("/api/...", "/stalker/...", fetch('/...'),
ws://host/...) and loads Alpine.js / Chart.js / Google Fonts from the internet.
Under Ingress the app lives below a per-session prefix
(/api/hassio_ingress/<token>), which HA passes in ``X-Ingress-Path`` while
stripping it from the request path. This pure-ASGI wrapper therefore:

* rejects every peer except the Supervisor's Ingress gateway (and loopback),
* serves vendored Alpine.js / Chart.js from /opt/vendor instead of jsDelivr,
* removes Google Fonts links and answers upstream's GitHub update check locally
  (privacy: no external requests from the panel; updates come via Home Assistant),
* prefixes absolute URLs in HTML/CSS/JS responses and in redirect headers,
* injects a small runtime shim for fetch / XHR / WebSocket.

No upstream file is patched, so upstream updates need no rebasing.
"""
from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Optional
from urllib.parse import urlsplit

from app import __version__ as TOOLKIT_VERSION
from app.main import app as upstream_app

VENDOR_DIR = Path(os.environ.get("INGRESS_VENDOR_DIR", "/opt/vendor"))
INGRESS_PEERS = frozenset({"172.30.32.2", "127.0.0.1", "::1"})

PREFIX_RE = re.compile(r"^/api/hassio_ingress/[A-Za-z0-9_-]{8,128}$")
VENDOR_FILES = {
    "/__vendor/alpine.min.js": "alpine.min.js",
    "/__vendor/chart.umd.js": "chart.umd.js",
}
REWRITE_TYPES = ("text/html", "text/css", "javascript")

# CDN references -> vendored copies (served below, version-pinned at build).
CDN_ALPINE = re.compile(r"https://cdn\.jsdelivr\.net/npm/alpinejs[^\"'\s>]*")
CDN_CHART = re.compile(r"https://cdn\.jsdelivr\.net/npm/chart\.js[^\"'\s>]*")
FONT_LINK = re.compile(
    r"<link\b[^>]*(?:fonts\.googleapis\.com|fonts\.gstatic\.com)[^>]*>\s*",
    re.IGNORECASE,
)
# The dashboard shows an advertisement banner for the author's consulting service.
# It is left out here (the header button and the /rogue-support page stay).
PROMO_BANNER = re.compile(r'<div class="promo-banner">.*?</a>\s*</div>\s*', re.DOTALL)
# Absolute (root-relative) URLs in markup, CSS and JS. Every pattern skips
# targets that already carry the Ingress prefix, so rewriting is idempotent
# (an Alpine @click="window.location.href = '/x'" matches two of them).
_ABS = r"/(?!/|api/hassio_ingress/)"
ATTR_URL = re.compile(r"""((?<![.\w])(?:href|src|action|data-src)\s*=\s*)(["'])""" + _ABS)
CSS_URL = re.compile(r"""(url\(\s*)(["']?)""" + _ABS)
JS_LOCATION = re.compile(r"""(\blocation(?:\.href)?\s*=\s*)(["'`])""" + _ABS)
JS_API_BASE = re.compile(r"""(\bAPI_BASE_PATH\s*=\s*)(["'`])""" + _ABS)

RUNTIME_SHIM = """<script>(function(){var P=%s;if(!P)return;
function fix(u){if(typeof u==='string'&&u.charAt(0)==='/'&&u.charAt(1)!=='/'&&u!==P&&u.indexOf(P+'/')!==0)return P+u;return u;}
var of=window.fetch;if(of){window.fetch=function(i,o){
if(typeof i==='string'){i=fix(i);}
else if(typeof Request!=='undefined'&&i instanceof Request){var q=new URL(i.url);if(q.origin===location.origin&&q.pathname.indexOf(P+'/')!==0){i=new Request(P+q.pathname+q.search,i);}}
return of.call(this,i,o);};}
var ox=XMLHttpRequest.prototype.open;XMLHttpRequest.prototype.open=function(m,u){
var a=Array.prototype.slice.call(arguments);a[1]=fix(String(u));return ox.apply(this,a);};
var OW=window.WebSocket;if(OW){var WS=function(u,p){try{var x=new URL(u,location.href);
if(x.host===location.host&&x.pathname.indexOf(P+'/')!==0){x.pathname=P+x.pathname;}u=x.toString();}catch(e){}
return p===undefined?new OW(u):new OW(u,p);};
WS.prototype=OW.prototype;['CONNECTING','OPEN','CLOSING','CLOSED'].forEach(function(k){WS[k]=OW[k];});window.WebSocket=WS;}
var oa=Element.prototype.setAttribute;Element.prototype.setAttribute=function(n,v){
if(typeof v==='string'){var k=String(n).toLowerCase();if(k==='src'||k==='href'||k==='action'||k==='data-src'||k==='poster'){v=fix(v);}}
return oa.call(this,n,v);};
function pp(c,p){var C=window[c];if(!C)return;var d=Object.getOwnPropertyDescriptor(C.prototype,p);
if(d&&d.set){Object.defineProperty(C.prototype,p,{get:d.get,set:function(v){d.set.call(this,typeof v==='string'?fix(v):v);},configurable:true,enumerable:d.enumerable});}}
pp('HTMLImageElement','src');pp('HTMLScriptElement','src');pp('HTMLIFrameElement','src');pp('HTMLSourceElement','src');pp('HTMLAnchorElement','href');pp('HTMLLinkElement','href');
})();</script>"""


def _header(headers, name: bytes) -> Optional[bytes]:
    for key, value in headers:
        if key.lower() == name:
            return value
    return None


def _rewrite(text: str, prefix: str, content_type: str) -> str:
    text = CDN_ALPINE.sub("/__vendor/alpine.min.js", text)
    text = CDN_CHART.sub("/__vendor/chart.umd.js", text)
    if "text/html" in content_type:
        text = FONT_LINK.sub("", text)
        text = PROMO_BANNER.sub("", text)
    if prefix:
        text = ATTR_URL.sub(lambda m: f"{m.group(1)}{m.group(2)}{prefix}/", text)
        text = CSS_URL.sub(lambda m: f"{m.group(1)}{m.group(2)}{prefix}/", text)
        text = JS_LOCATION.sub(lambda m: f"{m.group(1)}{m.group(2)}{prefix}/", text)
        text = JS_API_BASE.sub(lambda m: f"{m.group(1)}{m.group(2)}{prefix}/", text)
        if "text/html" in content_type:
            shim = RUNTIME_SHIM % ('"' + prefix + '"')
            lowered = text.lower()
            idx = lowered.find("<head")
            if idx != -1:
                end = lowered.find(">", idx)
                if end != -1:
                    return text[: end + 1] + shim + text[end + 1:]
            return shim + text
    return text


def _fix_location(value: str, prefix: str, host: str) -> str:
    """Make redirect targets stay below the Ingress prefix."""
    if not prefix:
        return value
    parts = urlsplit(value)
    if parts.netloc and parts.netloc.lower() != host.lower():
        return value  # redirect to a foreign host: leave untouched
    path = parts.path or "/"
    if not path.startswith("/") or path == prefix or path.startswith(prefix + "/"):
        return value
    out = prefix + path
    if parts.query:
        out += "?" + parts.query
    if parts.fragment:
        out += "#" + parts.fragment
    return out


class IngressShim:
    def __init__(self, app):
        self.app = app
        self._warned: set[str] = set()

    async def __call__(self, scope, receive, send):
        if scope["type"] == "lifespan":
            await self.app(scope, receive, send)
            return
        if scope["type"] not in ("http", "websocket"):
            return

        peer = (scope.get("client") or ("",))[0]
        if peer not in INGRESS_PEERS:
            if peer not in self._warned and len(self._warned) < 64:
                self._warned.add(peer)
                print(f"[ingress] rejected peer {peer or 'unknown'}: only the Home Assistant Ingress gateway may connect", flush=True)
            if scope["type"] == "websocket":
                await send({"type": "websocket.close", "code": 1008})
            else:
                await self._plain(send, 403, b"Forbidden: use Home Assistant Ingress")
            return

        headers = list(scope.get("headers") or [])
        raw_prefix = (_header(headers, b"x-ingress-path") or b"").decode("latin-1")
        prefix = raw_prefix if PREFIX_RE.match(raw_prefix) else ""

        if scope["type"] == "websocket":
            await self.app(scope, receive, send)
            return

        if scope["method"] == "GET" and scope["path"] == "/api/update-check":
            body = json.dumps({"update_available": False,
                               "current_version": TOOLKIT_VERSION}).encode()
            await send({"type": "http.response.start", "status": 200,
                        "headers": [(b"content-type", b"application/json"),
                                    (b"content-length", str(len(body)).encode())]})
            await send({"type": "http.response.body", "body": body})
            return

        if scope["method"] == "GET" and scope["path"] in VENDOR_FILES:
            await self._vendor(send, VENDOR_FILES[scope["path"]])
            return

        # Ask upstream for uncompressed bodies so they can be rewritten.
        scope = dict(scope)
        scope["headers"] = [(k, v) for k, v in headers if k.lower() != b"accept-encoding"]
        host = (_header(headers, b"host") or b"").decode("latin-1")

        state: dict = {"rewrite": False, "ctype": "", "start": None, "chunks": []}

        async def wrapped_send(message):
            if message["type"] == "http.response.start":
                hdrs = list(message.get("headers") or [])
                ctype = (_header(hdrs, b"content-type") or b"").decode("latin-1").lower()
                encoded = _header(hdrs, b"content-encoding")
                rewrite = (not encoded) and any(t in ctype for t in REWRITE_TYPES)
                new_hdrs = []
                for key, value in hdrs:
                    if key.lower() == b"location":
                        value = _fix_location(value.decode("latin-1"), prefix, host).encode("latin-1")
                    if rewrite and key.lower() == b"content-length":
                        continue
                    new_hdrs.append((key, value))
                message = {**message, "headers": new_hdrs}
                if rewrite:
                    state.update(rewrite=True, ctype=ctype, start=message)
                    return
                await send(message)
                return
            if message["type"] == "http.response.body" and state["rewrite"]:
                state["chunks"].append(message.get("body", b""))
                if message.get("more_body"):
                    return
                body = b"".join(state["chunks"])
                charset = "utf-8"
                m = re.search(r"charset=([\w-]+)", state["ctype"])
                if m:
                    charset = m.group(1)
                try:
                    text = body.decode(charset)
                    body = _rewrite(text, prefix, state["ctype"]).encode(charset)
                except (UnicodeDecodeError, LookupError):
                    pass
                start = dict(state["start"])
                start["headers"] = list(start["headers"]) + [
                    (b"content-length", str(len(body)).encode())
                ]
                await send(start)
                await send({"type": "http.response.body", "body": body})
                return
            await send(message)

        await self.app(scope, receive, wrapped_send)

    @staticmethod
    async def _plain(send, status: int, body: bytes):
        await send({"type": "http.response.start", "status": status,
                    "headers": [(b"content-type", b"text/plain; charset=utf-8"),
                                (b"content-length", str(len(body)).encode())]})
        await send({"type": "http.response.body", "body": body})

    async def _vendor(self, send, name: str):
        path = VENDOR_DIR / name
        try:
            body = path.read_bytes()
        except OSError:
            await self._plain(send, 404, b"vendored file missing")
            return
        await send({"type": "http.response.start", "status": 200,
                    "headers": [(b"content-type", b"text/javascript; charset=utf-8"),
                                (b"cache-control", b"public, max-age=86400"),
                                (b"content-length", str(len(body)).encode())]})
        await send({"type": "http.response.body", "body": body})


app = IngressShim(upstream_app)
