from conftest import WEB_DIR, load_module

config_gen = load_module("config_gen", WEB_DIR / "config_gen.py")


def test_defaults_are_valid():
    cfg = config_gen._defaults()
    assert config_gen.validate_config(cfg) == []


def test_reject_bool_as_int():
    cfg = config_gen._defaults()
    cfg["num_threads"] = True
    assert any("num_threads" in err for err in config_gen.validate_config(cfg))


def test_reject_int_below_min():
    cfg = config_gen._defaults()
    cfg["num_threads"] = 0
    assert any("minimum" in err for err in config_gen.validate_config(cfg))


def test_generate_contains_core_unbound_sections(monkeypatch, tmp_path):
    monkeypatch.setattr(config_gen, "STUB_ZONES_FILE", str(tmp_path / "stub_zones.json"))
    monkeypatch.setattr(config_gen, "OVERLAY_FILE", str(tmp_path / "unbound-overlay.conf"))
    monkeypatch.setattr(config_gen, "EXTRA_FILE", str(tmp_path / "unbound-extra.conf"))
    rendered = config_gen.generate_unbound_conf(config_gen._defaults())
    assert "server:" in rendered
    assert "remote-control:" in rendered
    assert 'root-hints: "/etc/unbound/root.hints"' in rendered
    assert 'auto-trust-anchor-file: "/var/lib/unbound/root.key"' in rendered
    assert 'include: "/etc/unbound/blocklist.conf"' in rendered
    assert 'include: "/etc/unbound/local_records.conf"' in rendered
