from conftest import WEB_DIR, install_flask_stub, load_module

install_flask_stub()
app_module = load_module("app", WEB_DIR / "app.py")


def test_validate_blocklist_url_rejects_file_scheme():
    ok, error = app_module.validate_blocklist_url("file:///etc/passwd")
    assert ok is False
    assert "http/https" in error


def test_validate_blocklist_url_rejects_credentials():
    ok, error = app_module.validate_blocklist_url("https://user:pass@example.com/list.txt")
    assert ok is False
    assert "credentials" in error


def test_parse_blocklist_hosts_format():
    assert app_module.parse_blocklist_line("0.0.0.0 Ads.Example.COM # comment") == "ads.example.com"
    assert app_module.parse_blocklist_line("127.0.0.1 tracker.example.com") == "tracker.example.com"


def test_parse_blocklist_domain_only():
    assert app_module.parse_blocklist_line("ads.example.com") == "ads.example.com"


def test_parse_blocklist_rejects_invalid_domain():
    assert app_module.parse_blocklist_line("0.0.0.0 bad_domain") is None


def test_normalize_legacy_a_record():
    rec = app_module.normalize_local_record({"hostname": "homeassistant.example.internal", "ip": "192.0.2.10"})
    assert rec["type"] == "A"
    assert rec["value"] == "192.0.2.10"
    assert rec["ttl"] == 300


def test_normalize_aaaa_record():
    rec = app_module.normalize_local_record({
        "hostname": "ha.home.arpa",
        "type": "AAAA",
        "value": "fd00::10",
        "ttl": 300,
    })
    assert rec["type"] == "AAAA"


def test_reject_ipv6_for_a_record():
    try:
        app_module.normalize_local_record({
            "hostname": "ha.home.arpa",
            "type": "A",
            "value": "fd00::10",
            "ttl": 300,
        })
    except ValueError:
        return
    assert False, "IPv6 was accepted for A record"


def test_normalize_cname_record():
    rec = app_module.normalize_local_record({
        "hostname": "nas.home.arpa",
        "type": "CNAME",
        "value": "storage.home.arpa",
        "ttl": 300,
    })
    assert rec["type"] == "CNAME"
