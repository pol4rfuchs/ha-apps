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


def test_normalize_stub_zone_accepts_unbound_syntax():
    assert config_gen.normalize_stub_zone("Home.Lan.", " 192.168.1.1 ") == ("home.lan", "192.168.1.1")
    assert config_gen.normalize_stub_zone("home.lan", "192.168.1.1@5353") == ("home.lan", "192.168.1.1@5353")
    assert config_gen.normalize_stub_zone("178.168.192.in-addr.arpa", "fd00::1") == (
        "178.168.192.in-addr.arpa", "fd00::1")


def test_normalize_stub_zone_rejects_invalid_input():
    for name, addr in [
        ("home.lan", "192.168.1.1:53"),        # common typo: unbound wants @port
        ("home.lan", "router.home.lan"),       # stub-addr takes an IP, not a name
        ("home.lan", "192.168.1.1@99999"),
        ('home.lan"\n  access-control: 0.0.0.0/0 allow', "192.168.1.1"),
        ("home.lan", "192.168.1.1\n  access-control: 0.0.0.0/0 allow"),
    ]:
        try:
            config_gen.normalize_stub_zone(name, addr)
        except ValueError:
            continue
        raise AssertionError(f"accepted {name!r} {addr!r}")


def test_generate_skips_invalid_saved_stub_zone(monkeypatch, tmp_path):
    # Entries saved before validation existed must not keep the add-on from starting.
    stub = tmp_path / "stub_zones.json"
    stub.write_text('[{"name": "fritz.box", "addr": "192.168.178.1:53"},'
                    ' {"name": "home.lan", "addr": "192.168.1.1"}]')
    monkeypatch.setattr(config_gen, "STUB_ZONES_FILE", str(stub))
    monkeypatch.setattr(config_gen, "OVERLAY_FILE", str(tmp_path / "unbound-overlay.conf"))
    monkeypatch.setattr(config_gen, "EXTRA_FILE", str(tmp_path / "unbound-extra.conf"))
    rendered = config_gen.generate_unbound_conf(config_gen._defaults())
    assert "192.168.178.1:53" not in rendered
    assert 'name: "home.lan"' in rendered
    assert "stub-addr: 192.168.1.1" in rendered
