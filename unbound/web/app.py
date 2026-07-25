"""Unbound DNS resolver web UI for Home Assistant ingress."""

import importlib.util
import ipaddress
import json
import logging
import os
import re
import subprocess
import threading
import time
from urllib.parse import urlparse

from flask import Flask, jsonify, render_template, request

# Load config_gen from explicit path in the container, with a local fallback for tests.
_CONFIG_GEN_PATH = "/web/config_gen.py" if os.path.exists("/web/config_gen.py") else os.path.join(os.path.dirname(__file__), "config_gen.py")
_spec = importlib.util.spec_from_file_location("config_gen", _CONFIG_GEN_PATH)
config_gen = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(config_gen)

app = Flask(__name__)

_logger = logging.getLogger("unbound-web")

BLOCKLISTS_FILE = "/data/blocklists.json"
BLOCKLIST_STATUS_FILE = "/data/blocklist_status.json"
BLOCKLIST_CONF = "/etc/unbound/blocklist.conf"
WHITELIST_FILE = "/data/whitelist.json"
LOCAL_RECORDS_FILE = "/data/local_records.json"
STUB_ZONES_FILE = "/data/stub_zones.json"
LOCAL_RECORDS_CONF = "/etc/unbound/local_records.conf"
QUERY_LOG_FILE = "/data/unbound_queries.log"
CUSTOM_CONFIG_WARNING_FILE = "/data/custom_config_warning.txt"
CUSTOM_CONFIG_PATH = "/config/unbound.conf"
OVERLAY_WARNING_FILE = "/data/overlay_warning.txt"
OVERLAY_FILE = "/config/unbound-overlay.conf"
EXTRA_FILE = "/config/unbound-extra.conf"
UNBOUND_CONF = "/etc/unbound/unbound.conf"

_BLOCKLIST_SKIP_DOMAINS = frozenset({
    "localhost", "localhost.localdomain", "local", "broadcasthost",
    "ip6-localhost", "ip6-loopback", "ip6-localnet",
    "ip6-mcastprefix", "ip6-allnodes", "ip6-allrouters", "ip6-allhosts",
})

# Matches unbound query/reply log lines. Both share the first five fields:
#   [1708012345] unbound[1:0] info: 192.168.1.1 example.com. A IN
# Reply lines (log-replies: yes) tack on rcode/rtt/size after the class.
# We anchor strictly enough to skip other info: lines (stats, validation
# failures, keytag generation, etc.) that previously produced garbage rows.
_LOG_QUERY_RE = re.compile(
    r"\[(\d+)\]\s+unbound\[\d+:\d+\]\s+info:\s+"
    r"(\S+)\s+"                          # client (IP, validated below)
    r"(\S+\.)\s+"                        # domain (must end with a dot)
    r"([A-Z][A-Z0-9]*)\s+"               # RR type
    r"(IN|CH|HS|ANY|NONE)"               # DNS class
    r"(?:\s|$)"
)


DOMAIN_RE = re.compile(
    r"^(?=.{1,253}\.?$)(?!-)[A-Za-z0-9-]{1,63}(?<!-)"
    r"(\.(?!-)[A-Za-z0-9-]{1,63}(?<!-))*\.?$"
)
ALLOWED_LOCAL_RECORD_TYPES = {"A", "AAAA", "CNAME", "PTR"}
BLOCKLIST_MAX_BYTES = 5 * 1024 * 1024
BLOCKLIST_TIMEOUT_SECONDS = 30


def is_valid_domain(value):
    """Return True for a syntactically valid DNS name."""
    if not isinstance(value, str):
        return False
    value = value.strip().rstrip(".")
    return bool(value) and bool(DOMAIN_RE.match(value))


def validate_blocklist_url(url):
    """Validate external blocklist URL before download/storage."""
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"}:
        return False, "only http/https blocklist URLs are allowed"
    if not parsed.netloc:
        return False, "blocklist URL has no host"
    if parsed.username or parsed.password:
        return False, "blocklist URLs must not contain credentials"
    return True, None


def fetch_blocklist(url):
    """Fetch blocklist with strict curl limits."""
    ok, error = validate_blocklist_url(url)
    if not ok:
        return None, error
    try:
        result = subprocess.run(
            [
                "curl",
                "--fail",
                "--location",
                "--show-error",
                "--silent",
                "--connect-timeout",
                "10",
                "--max-time",
                str(BLOCKLIST_TIMEOUT_SECONDS),
                "--max-filesize",
                str(BLOCKLIST_MAX_BYTES),
                "--max-redirs",
                "3",
                url,
            ],
            capture_output=True,
            text=True,
            timeout=BLOCKLIST_TIMEOUT_SECONDS + 5,
        )
    except subprocess.TimeoutExpired:
        return None, "download timeout"

    if result.returncode != 0:
        return None, result.stderr.strip() or "curl failed"

    return result.stdout, None


def parse_blocklist_line(line):
    """Parse supported blocklist formats into a normalized domain or None."""
    line = line.strip()
    if not line or line.startswith("#"):
        return None
    if "#" in line:
        line = line.split("#", 1)[0].strip()
    parts = line.split()
    candidate = None
    if len(parts) == 1:
        candidate = parts[0]
    elif len(parts) >= 2 and parts[0] in ("0.0.0.0", "127.0.0.1", "::", "::1"):
        candidate = parts[1]
    if not candidate:
        return None
    domain = candidate.strip().lower().rstrip(".")
    if domain in _BLOCKLIST_SKIP_DOMAINS or not is_valid_domain(domain):
        return None
    return domain


def normalize_local_record(record):
    """Normalize and validate local DNS records. Keeps legacy hostname/ip support."""
    hostname = str(record.get("hostname", "")).strip().lower().rstrip(".")
    rtype = str(record.get("type", "A")).upper().strip()
    value = str(record.get("value", record.get("ip", ""))).strip().rstrip(".")
    ttl = record.get("ttl", 300)

    if not is_valid_domain(hostname):
        raise ValueError("invalid hostname")
    if rtype not in ALLOWED_LOCAL_RECORD_TYPES:
        raise ValueError("unsupported record type")

    if rtype == "A":
        ip = ipaddress.ip_address(value)
        if ip.version != 4:
            raise ValueError("A record requires IPv4 address")
    elif rtype == "AAAA":
        ip = ipaddress.ip_address(value)
        if ip.version != 6:
            raise ValueError("AAAA record requires IPv6 address")
    elif rtype in {"CNAME", "PTR"}:
        if not is_valid_domain(value):
            raise ValueError(f"{rtype} record requires valid domain target")

    if isinstance(ttl, bool) or not isinstance(ttl, int):
        raise ValueError("ttl must be integer")
    if ttl < 30 or ttl > 86400:
        raise ValueError("ttl must be between 30 and 86400")

    normalized = {"hostname": hostname, "type": rtype, "value": value, "ttl": ttl}
    if rtype == "A":
        normalized["ip"] = value
    return normalized


# --- JSON helpers ---

def load_blocklists():
    """Load blocklist URLs from persistent storage."""
    if not os.path.exists(BLOCKLISTS_FILE):
        return []
    with open(BLOCKLISTS_FILE, "r") as f:
        return json.load(f)


def save_blocklists(blocklists):
    """Save blocklist URLs to persistent storage."""
    with open(BLOCKLISTS_FILE, "w") as f:
        json.dump(blocklists, f, indent=2)


def load_blocklist_status():
    """Load per-blocklist status (domain count, last refresh, errors)."""
    if not os.path.exists(BLOCKLIST_STATUS_FILE):
        return {}
    with open(BLOCKLIST_STATUS_FILE, "r") as f:
        return json.load(f)


def save_blocklist_status(status):
    """Save per-blocklist status."""
    with open(BLOCKLIST_STATUS_FILE, "w") as f:
        json.dump(status, f, indent=2)


def load_whitelist():
    """Load whitelisted domains."""
    if not os.path.exists(WHITELIST_FILE):
        return []
    with open(WHITELIST_FILE, "r") as f:
        return json.load(f)


def save_whitelist(whitelist):
    """Save whitelisted domains."""
    with open(WHITELIST_FILE, "w") as f:
        json.dump(whitelist, f, indent=2)


def load_stub_zones():
    """Load stub zones."""
    if not os.path.exists(STUB_ZONES_FILE):
        return []
    with open(STUB_ZONES_FILE, "r") as f:
        return json.load(f)


def save_stub_zones(zones):
    """Save stub zones."""
    with open(STUB_ZONES_FILE, "w") as f:
        json.dump(zones, f, indent=2)


def load_local_records():
    """Load local DNS records."""
    if not os.path.exists(LOCAL_RECORDS_FILE):
        return []
    with open(LOCAL_RECORDS_FILE, "r") as f:
        return json.load(f)


def save_local_records(records):
    """Save local DNS records."""
    with open(LOCAL_RECORDS_FILE, "w") as f:
        json.dump(records, f, indent=2)


def write_local_records_conf(records):
    """Write /etc/unbound/local_records.conf from records list."""
    with open(LOCAL_RECORDS_CONF, "w", encoding="utf-8") as f:
        f.write("# Generated local records\n")
        f.write("# Do not edit manually\n\n")
        f.write("server:\n")
        for raw in records:
            try:
                rec = normalize_local_record(raw)
            except (ValueError, KeyError):
                continue
            hostname = rec["hostname"]
            rtype = rec["type"]
            value = rec["value"]
            ttl = rec["ttl"]
            if rtype in {"A", "AAAA"}:
                f.write(f'    local-zone: "{hostname}." static\n')
                f.write(f'    local-data: "{hostname}. {ttl} IN {rtype} {value}"\n')
            elif rtype == "CNAME":
                f.write(f'    local-zone: "{hostname}." transparent\n')
                f.write(f'    local-data: "{hostname}. {ttl} IN CNAME {value}."\n')
            elif rtype == "PTR":
                f.write(f'    local-data-ptr: "{hostname} {value}."\n')


def parse_query_log(text):
    """Parse unbound query log text into structured dicts."""
    entries = []
    for line in text.split("\n"):
        m = _LOG_QUERY_RE.search(line)
        if not m:
            continue
        client = m.group(2)
        try:
            ipaddress.ip_address(client)
        except ValueError:
            continue
        entries.append({
            "timestamp": int(m.group(1)),
            "client": client,
            "domain": m.group(3).rstrip("."),
            "type": m.group(4),
            "class": m.group(5),
        })
    return entries


# --- Helpers ---


def run_unbound_control(cmd, retries=0):
    """Run an unbound-control command and return (output, ok).

    On success: returns stdout. On failure: returns combined stderr+stdout so
    OpenSSL/TLS diagnostics aren't lost. Set retries>0 to retry transient
    failures (e.g. control-channel races during reload).
    """
    last_err = ""
    for attempt in range(retries + 1):
        try:
            result = subprocess.run(
                ["unbound-control"] + cmd,
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                return result.stdout, True
            last_err = (result.stderr.strip() + "\n" + result.stdout.strip()).strip()
        except (subprocess.TimeoutExpired, FileNotFoundError) as e:
            last_err = str(e)
        if attempt < retries:
            time.sleep(0.5)
    return last_err or "Unknown error", False




def validate_unbound_config(path=UNBOUND_CONF):
    """Validate active Unbound config before reload."""
    try:
        result = subprocess.run(
            ["unbound-checkconf", path],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        return False, str(e)

    output = (result.stdout.strip() + "\n" + result.stderr.strip()).strip()
    if result.returncode != 0:
        return False, output or "unbound-checkconf failed"
    return True, output or "unbound-checkconf OK"


def validate_and_reload_unbound(retries=1):
    """Validate config and reload Unbound only if validation succeeds."""
    valid, check_msg = validate_unbound_config()
    if not valid:
        return {
            "ok": False,
            "check_ok": False,
            "reload_ok": False,
            "message": check_msg,
        }

    reload_msg, reload_ok = run_unbound_control(["reload"], retries=retries)
    return {
        "ok": reload_ok,
        "check_ok": True,
        "reload_ok": reload_ok,
        "message": reload_msg if reload_ok else reload_msg,
    }


def apply_reload_pipeline(action="reload", retries=1):
    """Centralized reload pipeline for all mutating API endpoints."""
    result = validate_and_reload_unbound(retries=retries)
    status_code = 200 if result["ok"] else 400
    payload = {
        "action": action,
        "ok": result["ok"],
        "check_ok": result["check_ok"],
        "reload_ok": result["reload_ok"],
        "message": result["message"],
    }
    return payload, status_code


def merge_reload_result(payload, reload_payload):
    """Merge endpoint response payload with centralized reload result."""
    merged = dict(payload)
    merged["reload"] = reload_payload
    merged["reload_ok"] = reload_payload.get("reload_ok", False)
    merged["check_ok"] = reload_payload.get("check_ok", False)
    merged["message"] = reload_payload.get("message", "")
    return merged


def parse_stats(raw_stats):
    """Parse unbound-control stats output into a structured dict."""
    stats = {}
    for line in raw_stats.strip().split("\n"):
        if "=" in line:
            key, value = line.split("=", 1)
            stats[key.strip()] = value.strip()
    return stats


# --- Routes ---

@app.route("/")
def index():
    """Serve the main dashboard."""
    return render_template("index.html")


@app.route("/api/stats")
def api_stats():
    """Return DNS statistics from unbound-control."""
    raw, ok = run_unbound_control(["stats_noreset"])
    if not ok:
        return jsonify({"error": "Failed to get stats", "detail": raw}), 500

    stats = parse_stats(raw)

    # Unbound in multi-threaded mode emits per-thread keys (threadN.*) plus
    # cumulative total.* keys, and does not emit num.threads — derive it.
    num_threads = sum(
        1 for key in stats
        if key.startswith("thread") and key.endswith(".num.queries")
    )

    total_queries = float(stats.get("total.num.queries", 0))
    cache_hits = float(stats.get("total.num.cachehits", 0))
    cache_miss = float(stats.get("total.num.cachemiss", 0))
    hit_rate = (cache_hits / total_queries * 100) if total_queries > 0 else 0

    # Count blocked domains from blocklist.conf
    blocked_count = 0
    if os.path.exists(BLOCKLIST_CONF):
        with open(BLOCKLIST_CONF, "r") as f:
            blocked_count = sum(1 for line in f if line.startswith("local-zone:"))

    uptime = float(stats.get("time.up", 0))
    queries_per_sec = round(total_queries / uptime, 1) if uptime > 0 else 0

    # Response codes
    rcodes = {}
    for key, val in stats.items():
        if key.startswith("num.answer.rcode."):
            rcode = key.split(".")[-1]
            count = int(float(val))
            if count > 0:
                rcodes[rcode] = count

    # Query types
    qtypes = {}
    for key, val in stats.items():
        if key.startswith("num.query.type."):
            qtype = key.split(".")[-1]
            count = int(float(val))
            if count > 0:
                qtypes[qtype] = count

    # Memory usage (bytes)
    memory = {}
    for key, val in stats.items():
        if key.startswith("mem."):
            label = key.replace("mem.", "")
            memory[label] = int(float(val))

    return jsonify({
        "total_queries": int(total_queries),
        "cache_hits": int(cache_hits),
        "cache_misses": int(cache_miss),
        "cache_hit_rate": round(hit_rate, 1),
        "blocked_domains": blocked_count,
        "num_threads": num_threads if num_threads > 0 else "N/A",
        "uptime": stats.get("time.up", "N/A"),
        "queries_per_sec": queries_per_sec,
        "recursion_time_avg": stats.get("total.recursion.time.avg", "N/A"),
        "recursion_time_median": stats.get("total.recursion.time.median", "N/A"),
        "prefetch": int(float(stats.get("total.num.prefetch", 0))),
        "unwanted_queries": int(float(stats.get("unwanted.queries", 0))),
        "unwanted_replies": int(float(stats.get("unwanted.replies", 0))),
        "rcodes": rcodes,
        "qtypes": qtypes,
        "memory": memory,
        "raw": stats,
    })


# --- Blocklists ---

@app.route("/api/blocklists")
def api_blocklists_list():
    """List all configured blocklists with per-URL status."""
    urls = load_blocklists()
    status = load_blocklist_status()
    result = []
    for url in urls:
        info = status.get(url, {})
        result.append({
            "url": url,
            "domains": info.get("domains", None),
            "last_refresh": info.get("last_refresh", None),
            "error": info.get("error", None),
        })
    return jsonify(result)


@app.route("/api/blocklists", methods=["POST"])
def api_blocklists_add():
    """Add a new blocklist URL."""
    data = request.get_json()
    if not data or "url" not in data:
        return jsonify({"error": "Missing 'url' field"}), 400

    url = data["url"].strip()
    if not url:
        return jsonify({"error": "URL cannot be empty"}), 400
    ok, error = validate_blocklist_url(url)
    if not ok:
        return jsonify({"error": error}), 400

    blocklists = load_blocklists()
    if url in blocklists:
        return jsonify({"error": "URL already exists"}), 409

    blocklists.append(url)
    save_blocklists(blocklists)
    return jsonify({"status": "added", "url": url}), 201


@app.route("/api/blocklists/<int:idx>", methods=["DELETE"])
def api_blocklists_remove(idx):
    """Remove a blocklist by index."""
    blocklists = load_blocklists()
    if idx < 0 or idx >= len(blocklists):
        return jsonify({"error": "Invalid index"}), 404

    removed = blocklists.pop(idx)
    save_blocklists(blocklists)

    # Clean up status for removed URL
    status = load_blocklist_status()
    status.pop(removed, None)
    save_blocklist_status(status)

    return jsonify({"status": "removed", "url": removed})


def _do_blocklist_refresh():
    """Core blocklist refresh logic. Returns dict with results."""
    blocklists = load_blocklists()
    whitelist = {str(d).strip().lower().rstrip(".") for d in load_whitelist()}
    status = load_blocklist_status()

    all_domains = set()
    errors = []

    for url in blocklists:
        url_domains = set()
        text, error = fetch_blocklist(url)
        if error:
            errors.append({"url": url, "error": error})
            status[url] = {
                "domains": 0,
                "last_refresh": time.time(),
                "error": error,
            }
            continue

        for line in text.split("\n"):
            domain = parse_blocklist_line(line)
            if domain:
                url_domains.add(domain)

        all_domains |= url_domains
        status[url] = {
            "domains": len(url_domains),
            "last_refresh": time.time(),
            "error": None,
        }

    save_blocklist_status(status)

    all_domains -= whitelist

    with open(BLOCKLIST_CONF, "w", encoding="utf-8") as f:
        for domain in sorted(all_domains):
            f.write(f'local-zone: "{domain}." always_refuse\n')

    reload_payload, status_code = apply_reload_pipeline("refresh_blocklists", retries=1)

    payload = {
        "status": "refreshed",
        "domains_blocked": len(all_domains),
        "errors": errors,
    }
    result = merge_reload_result(payload, reload_payload)
    result["http_status"] = status_code
    return result


@app.route("/api/blocklists/refresh", methods=["POST"])
def api_blocklists_refresh():
    """Re-download all blocklists, subtract whitelist, and reload unbound."""
    result = _do_blocklist_refresh()
    status_code = result.pop("http_status", 200)
    return jsonify(result), status_code


# --- Whitelist ---

@app.route("/api/whitelist")
def api_whitelist_list():
    """List all whitelisted domains."""
    return jsonify(load_whitelist())


@app.route("/api/whitelist", methods=["POST"])
def api_whitelist_add():
    """Add a domain to the whitelist."""
    data = request.get_json()
    if not data or "domain" not in data:
        return jsonify({"error": "Missing 'domain' field"}), 400

    domain = data["domain"].strip().lower()
    if not domain:
        return jsonify({"error": "Domain cannot be empty"}), 400

    whitelist = load_whitelist()
    if domain in whitelist:
        return jsonify({"error": "Domain already whitelisted"}), 409

    whitelist.append(domain)
    save_whitelist(whitelist)
    return jsonify({"status": "added", "domain": domain}), 201


@app.route("/api/whitelist/<int:idx>", methods=["DELETE"])
def api_whitelist_remove(idx):
    """Remove a whitelisted domain by index."""
    whitelist = load_whitelist()
    if idx < 0 or idx >= len(whitelist):
        return jsonify({"error": "Invalid index"}), 404

    removed = whitelist.pop(idx)
    save_whitelist(whitelist)
    return jsonify({"status": "removed", "domain": removed})


# --- Local Records ---

@app.route("/api/local-records")
def api_local_records_list():
    """List all local DNS records."""
    normalized = []
    for rec in load_local_records():
        try:
            normalized.append(normalize_local_record(rec))
        except ValueError:
            normalized.append(rec)
    return jsonify(normalized)


@app.route("/api/local-records", methods=["POST"])
def api_local_records_add():
    """Add a local DNS record."""
    data = request.get_json() or {}
    try:
        record = normalize_local_record(data)
    except (ValueError, KeyError) as exc:
        _logger.warning("Rejected local record %r: %s", data, exc)
        return jsonify({"error": "Invalid local record data"}), 400

    records = load_local_records()

    for rec in records:
        try:
            existing = normalize_local_record(rec)
        except ValueError:
            continue
        if existing["hostname"] == record["hostname"] and existing["type"] == record["type"]:
            return jsonify({"error": "Hostname/type already exists"}), 409

    records.append(record)
    save_local_records(records)
    write_local_records_conf(records)

    reload_payload, status_code = apply_reload_pipeline("add_local_record", retries=1)
    payload = {"status": "added", "record": record}
    return jsonify(merge_reload_result(payload, reload_payload)), 201 if reload_payload["ok"] else status_code


@app.route("/api/local-records/<int:idx>", methods=["DELETE"])
def api_local_records_remove(idx):
    """Remove a local DNS record by index."""
    records = load_local_records()
    if idx < 0 or idx >= len(records):
        return jsonify({"error": "Invalid index"}), 404

    removed = records.pop(idx)
    save_local_records(records)
    write_local_records_conf(records)

    reload_payload, status_code = apply_reload_pipeline("delete_local_record", retries=1)
    payload = {"status": "removed", "record": removed}
    return jsonify(merge_reload_result(payload, reload_payload)), status_code


# --- Stub Zones ---

@app.route("/api/stub-zones")
def api_stub_zones_list():
    """List all stub zones."""
    return jsonify(load_stub_zones())


@app.route("/api/stub-zones", methods=["POST"])
def api_stub_zones_add():
    """Add a stub zone."""
    data = request.get_json()
    if not data or "name" not in data or "addr" not in data:
        return jsonify({"error": "Missing 'name' and/or 'addr' field"}), 400

    name = data["name"].strip().lower()
    addr = data["addr"].strip()
    if not name or not addr:
        return jsonify({"error": "Name and address cannot be empty"}), 400

    zones = load_stub_zones()

    for z in zones:
        if z["name"] == name:
            return jsonify({"error": "Stub zone already exists"}), 409

    zones.append({"name": name, "addr": addr})
    save_stub_zones(zones)

    # Regenerate config and reload via centralized validation pipeline.
    config_gen.write_unbound_conf()
    reload_payload, status_code = apply_reload_pipeline("add_stub_zone", retries=1)
    payload = {"status": "added", "name": name, "addr": addr}
    return jsonify(merge_reload_result(payload, reload_payload)), 201 if reload_payload["ok"] else status_code


@app.route("/api/stub-zones/<int:idx>", methods=["DELETE"])
def api_stub_zones_remove(idx):
    """Remove a stub zone by index."""
    zones = load_stub_zones()
    if idx < 0 or idx >= len(zones):
        return jsonify({"error": "Invalid index"}), 404

    removed = zones.pop(idx)
    save_stub_zones(zones)

    # Regenerate config and reload via centralized validation pipeline.
    config_gen.write_unbound_conf()
    reload_payload, status_code = apply_reload_pipeline("delete_stub_zone", retries=1)
    payload = {"status": "removed", "name": removed["name"]}
    return jsonify(merge_reload_result(payload, reload_payload)), status_code


# --- Cache ---

@app.route("/api/cache/flush", methods=["POST"])
def api_cache_flush():
    """Flush the entire DNS cache."""
    output, ok = run_unbound_control(["flush_zone", "."])
    if not ok:
        return jsonify({"error": "Failed to flush cache", "detail": output}), 500
    return jsonify({"status": "flushed"})


@app.route("/api/cache/flush-domain", methods=["POST"])
def api_cache_flush_domain():
    """Flush a specific domain from the DNS cache."""
    data = request.get_json()
    if not data or "domain" not in data:
        return jsonify({"error": "Missing 'domain' field"}), 400

    domain = data["domain"].strip()
    if not domain:
        return jsonify({"error": "Domain cannot be empty"}), 400
    if not is_valid_domain(domain):
        return jsonify({"error": "Invalid domain format"}), 400

    domain = domain.rstrip(".")
    output, ok = run_unbound_control(["flush", domain])
    if not ok:
        return jsonify({"error": "Failed to flush domain", "detail": output}), 500
    return jsonify({"status": "flushed", "domain": domain})


# --- Query Log ---

@app.route("/api/query-log")
def api_query_log():
    """Return the last ~100KB of query log parsed into entries."""
    if not os.path.exists(QUERY_LOG_FILE):
        return jsonify([])

    try:
        size = os.path.getsize(QUERY_LOG_FILE)
        read_bytes = min(size, 100 * 1024)
        with open(QUERY_LOG_FILE, "r") as f:
            if size > read_bytes:
                f.seek(size - read_bytes)
                f.readline()  # skip partial line
            text = f.read()
        return jsonify(parse_query_log(text))
    except Exception:
        _logger.exception("Failed to read query log")
        return jsonify({"error": "Failed to read query log"}), 500


@app.route("/api/query-log/clear", methods=["POST"])
def api_query_log_clear():
    """Truncate the query log file in place."""
    try:
        if os.path.exists(QUERY_LOG_FILE):
            with open(QUERY_LOG_FILE, "w"):
                pass
        old = QUERY_LOG_FILE + ".old"
        if os.path.exists(old):
            os.unlink(old)
        return jsonify({"ok": True, "message": "Query log cleared."})
    except OSError:
        _logger.exception("Failed to clear query log")
        return jsonify({"ok": False, "message": "Failed to clear query log"}), 500


@app.route("/api/top-domains")
def api_top_domains():
    """Return top 25 queried domains from the log."""
    if not os.path.exists(QUERY_LOG_FILE):
        return jsonify([])

    try:
        size = os.path.getsize(QUERY_LOG_FILE)
        read_bytes = min(size, 2 * 1024 * 1024)
        with open(QUERY_LOG_FILE, "r") as f:
            if size > read_bytes:
                f.seek(size - read_bytes)
                f.readline()  # skip partial line
            text = f.read()

        counts = {}
        for entry in parse_query_log(text):
            d = entry["domain"]
            counts[d] = counts.get(d, 0) + 1

        top = sorted(counts.items(), key=lambda x: x[1], reverse=True)[:25]
        return jsonify([{"domain": d, "count": c} for d, c in top])
    except Exception:
        _logger.exception("Failed to compute top domains")
        return jsonify({"error": "Failed to compute top domains"}), 500


# --- Config (Settings) ---

@app.route("/api/config")
def api_config_get():
    """Return current config and schema for the Settings UI."""
    config = config_gen.load_config()
    result = {"config": config, "schema": config_gen.CONFIG_SCHEMA}
    if os.path.exists(CUSTOM_CONFIG_WARNING_FILE):
        with open(CUSTOM_CONFIG_WARNING_FILE, "r") as f:
            result["custom_config_warning"] = f.read().strip()
    if os.path.exists(OVERLAY_WARNING_FILE):
        with open(OVERLAY_WARNING_FILE, "r") as f:
            result["overlay_warning"] = f.read().strip()
    result["overlay_status"] = {
        "overlay_present": os.path.exists(OVERLAY_FILE)
            and os.path.getsize(OVERLAY_FILE) > 0,
        "extra_present": os.path.exists(EXTRA_FILE)
            and os.path.getsize(EXTRA_FILE) > 0,
    }
    return jsonify(result)


@app.route("/api/config", methods=["PUT"])
def api_config_put():
    """Update config, regenerate unbound.conf, and reload."""
    data = request.get_json()
    if not data:
        return jsonify({"ok": False, "message": "No JSON body"}), 400

    # Merge submitted values onto current config
    current = config_gen.load_config()
    current.update(data)

    result = config_gen.apply_config(current)
    status_code = 200 if result["ok"] else 400
    return jsonify(result), status_code


@app.route("/api/config/validate-custom", methods=["POST"])
def api_config_validate_custom():
    """Validate the user's custom unbound.conf without restarting."""
    import shutil
    import tempfile

    if not os.path.exists(CUSTOM_CONFIG_PATH):
        return jsonify({
            "ok": False,
            "message": f"Custom config file not found at {CUSTOM_CONFIG_PATH}",
        })

    try:
        with tempfile.NamedTemporaryFile(suffix=".conf", delete=False) as tmp:
            tmp_path = tmp.name
            shutil.copy2(CUSTOM_CONFIG_PATH, tmp_path)

        result = subprocess.run(
            ["unbound-checkconf", tmp_path],
            capture_output=True, text=True, timeout=10,
        )
        os.unlink(tmp_path)

        if result.returncode == 0:
            return jsonify({"ok": True, "message": "Configuration is valid."})
        else:
            output = (result.stdout + result.stderr).strip()
            return jsonify({"ok": False, "message": output})
    except Exception:
        _logger.exception("Failed to validate custom config")
        return jsonify({"ok": False, "message": "Failed to validate custom config"})


# --- Blocklist auto-refresh ---

BLOCKLIST_REFRESH_INTERVAL = 24 * 60 * 60  # 24 hours


def _blocklist_auto_refresh():
    """Background thread: refresh blocklists every 24 hours."""
    while True:
        time.sleep(BLOCKLIST_REFRESH_INTERVAL)
        try:
            blocklists = load_blocklists()
            if not blocklists:
                continue
            _logger.info("Auto-refreshing blocklists (%d URLs)...", len(blocklists))
            result = _do_blocklist_refresh()
            _logger.info(
                "Auto-refresh complete: %d domains blocked, %d errors",
                result["domains_blocked"], len(result["errors"]),
            )
        except Exception:
            _logger.exception("Auto-refresh failed")


if __name__ == "__main__":
    from waitress import serve

    logging.basicConfig(level=logging.INFO)

    t = threading.Thread(target=_blocklist_auto_refresh, daemon=True)
    t.start()

    port = int(os.environ.get("INGRESS_PORT", 2137))
    serve(app, host="0.0.0.0", port=port)