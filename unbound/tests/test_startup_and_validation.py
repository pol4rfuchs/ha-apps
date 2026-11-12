from conftest import WEB_DIR, install_flask_stub, load_module

install_flask_stub()
app_module = load_module("app", WEB_DIR / "app.py")
config_gen = load_module("config_gen", WEB_DIR / "config_gen.py")

INJECTION = '1.2.3.4"\n    access-control: 0.0.0.0/0 allow\n    local-data: "y'


def test_split_local_records_skips_invalid_entries():
    valid, skipped = app_module.split_local_records([
        {"hostname": "nas.lan", "ip": "192.168.1.5"},
        {"hostname": "bad.lan", "type": "A", "value": "not-an-ip", "ttl": 300},
        {"hostname": "x.lan", "type": "A", "value": INJECTION, "ttl": 300},
        {"hostname": "short.lan", "type": "A", "value": "1.2.3.4", "ttl": 5},
        "not-a-dict",
    ])
    assert [r["hostname"] for r in valid] == ["nas.lan"]
    assert len(skipped) == 4


def test_write_local_records_conf_never_writes_invalid_values(monkeypatch, tmp_path):
    # run.sh used to copy every saved record into the config unchecked; one bad value made
    # unbound-checkconf fail and kept the app from starting.
    conf = tmp_path / "local_records.conf"
    monkeypatch.setattr(app_module, "LOCAL_RECORDS_CONF", str(conf))
    app_module.write_local_records_conf([
        {"hostname": "nas.lan", "ip": "192.168.1.5"},
        {"hostname": "bad.lan", "type": "A", "value": "not-an-ip"},
        {"hostname": "x.lan", "type": "A", "value": INJECTION},
        {"hostname": "alias.lan", "type": "CNAME", "value": "nas.lan"},
    ])
    text = conf.read_text(encoding="utf-8")
    assert text.splitlines()[3] == "server:"
    assert 'local-data: "nas.lan. 300 IN A 192.168.1.5"' in text
    assert 'local-data: "alias.lan. 300 IN CNAME nas.lan."' in text
    assert "bad.lan" not in text and "x.lan" not in text
    assert "access-control" not in text


def test_access_control_validation():
    cfg = config_gen._defaults()
    assert config_gen.validate_config(cfg) == []
    cfg["access_control"] = ["192.168.0.0/16", "::1/128", "10.1.2.3"]
    assert config_gen.validate_config(cfg) == []
    for bad in ["not-a-cidr", "10.0.0.0/8 allow\n    access-control: 0.0.0.0/0", 5]:
        cfg["access_control"] = [bad]
        assert any("access_control" in e for e in config_gen.validate_config(cfg)), bad


def test_forward_server_validation():
    cfg = config_gen._defaults()
    for good in ["1.1.1.1", "1.1.1.1@853#cloudflare-dns.com", "[::1]@53", "2606:4700:4700::1111@853#one.one.one.one"]:
        cfg["forward_servers"] = [good]
        assert config_gen.validate_config(cfg) == [], good
    for bad in ["1.1.1.1\n    forward-no-cache: yes", "a b", '1.1.1.1"', "1.1.1.1@99999", ""]:
        cfg["forward_servers"] = [bad]
        assert any("forward_servers" in e for e in config_gen.validate_config(cfg)), bad


def test_forward_tls_warning_only_without_tls_name():
    cfg = config_gen._defaults()
    assert config_gen.forward_tls_warning(cfg) == ""
    cfg.update(forward_tls=True, forward_servers=["1.1.1.1@853"])
    assert "not verified" in config_gen.forward_tls_warning(cfg)
    cfg["forward_servers"] = ["1.1.1.1@853#cloudflare-dns.com"]
    assert config_gen.forward_tls_warning(cfg) == ""
    cfg.update(forward_tls=False, forward_servers=["1.1.1.1"])
    assert config_gen.forward_tls_warning(cfg) == ""


def test_rotate_query_log_truncates_only_above_limit(monkeypatch, tmp_path):
    log = tmp_path / "unbound_queries.log"
    monkeypatch.setattr(app_module, "QUERY_LOG_FILE", str(log))
    assert app_module.rotate_query_log(max_size=100) is False  # no file yet
    log.write_text("x" * 50)
    assert app_module.rotate_query_log(max_size=100) is False
    log.write_text("y" * 150)
    assert app_module.rotate_query_log(max_size=100) is True
    assert log.read_text() == ""
    assert (tmp_path / "unbound_queries.log.old").read_text() == "y" * 150
