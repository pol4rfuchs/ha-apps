import json

from conftest import WEB_DIR, load_module

config_gen = load_module("config_gen", WEB_DIR / "config_gen.py")


def render(monkeypatch, tmp_path, stub_zones=None, **overrides):
    stub = tmp_path / "stub_zones.json"
    if stub_zones is not None:
        stub.write_text(json.dumps(stub_zones))
    monkeypatch.setattr(config_gen, "STUB_ZONES_FILE", str(stub))
    monkeypatch.setattr(config_gen, "OVERLAY_FILE", str(tmp_path / "unbound-overlay.conf"))
    monkeypatch.setattr(config_gen, "EXTRA_FILE", str(tmp_path / "unbound-extra.conf"))
    cfg = config_gen._defaults()
    cfg.update(overrides)
    assert config_gen.validate_config(cfg) == []
    return config_gen.generate_unbound_conf(cfg)


def test_defaults_keep_behaviour_and_enable_safe_hardening(monkeypatch, tmp_path):
    text = render(monkeypatch, tmp_path)
    assert "interface: 0.0.0.0" in text and "interface: ::0" not in text
    assert "ratelimit: 0" in text and "ip-ratelimit: 0" in text
    assert "deny-any: no" in text
    assert "harden-large-queries: yes" in text and "harden-short-bufsize: yes" in text
    assert "unwanted-reply-threshold: 10000000" in text
    assert "private-address:" not in text


def test_rate_limits_and_deny_any(monkeypatch, tmp_path):
    text = render(monkeypatch, tmp_path, ratelimit=1000, ip_ratelimit=200, deny_any=True,
                  harden_large_queries=False, unwanted_reply_threshold=0)
    assert "    ratelimit: 1000" in text
    assert "    ip-ratelimit: 200" in text
    assert "deny-any: yes" in text
    assert "harden-large-queries: no" in text
    assert "unwanted-reply-threshold: 0" in text


def test_rebinding_protection_exempts_stub_zones(monkeypatch, tmp_path):
    text = render(monkeypatch, tmp_path, private_address_protection=True,
                  stub_zones=[{"name": "Home.Lan.", "addr": "192.168.1.1"}, {"name": "x", "addr": "bad:1"}])
    for rng in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fd00::/8"):
        assert f"private-address: {rng}" in text
    assert 'private-domain: "home.lan"' in text
    assert text.count("private-domain:") == 1  # invalid stub zone skipped
    assert 'name: "home.lan"' in text


def test_ipv6_listener_is_opt_in(monkeypatch, tmp_path):
    text = render(monkeypatch, tmp_path, listen_ipv6=True)
    assert "interface: 0.0.0.0" in text and "interface: ::0" in text


def test_negative_limits_rejected():
    cfg = config_gen._defaults()
    cfg["ip_ratelimit"] = -1
    assert any("ip_ratelimit" in e for e in config_gen.validate_config(cfg))


def test_restart_required_for_threads_and_ipv6_listener(monkeypatch, tmp_path):
    saved = {}
    old = config_gen._defaults()
    monkeypatch.setattr(config_gen, "load_config", lambda: dict(old))
    monkeypatch.setattr(config_gen, "save_config", lambda c: saved.update(c))
    monkeypatch.setattr(config_gen, "UNBOUND_CONF", str(tmp_path / "unbound.conf"))
    monkeypatch.setattr(config_gen, "BLOCKLIST_CONF", str(tmp_path / "blocklist.conf"))
    monkeypatch.setattr(config_gen, "LOCAL_RECORDS_CONF", str(tmp_path / "local.conf"))
    monkeypatch.setattr(config_gen, "write_and_validate", lambda c: (True, ""))
    monkeypatch.setattr(config_gen, "_reload_unbound", lambda: (True, ""))
    changed = dict(old, listen_ipv6=True)
    assert config_gen.apply_config(changed)["restart_required"] is True
    assert config_gen.apply_config(dict(old, prefetch=False))["restart_required"] is False
