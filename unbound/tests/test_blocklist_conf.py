from conftest import WEB_DIR, install_flask_stub, load_module

install_flask_stub()
app_module = load_module("app", WEB_DIR / "app.py")


def _setup(monkeypatch, tmp_path, lists, whitelist=()):
    conf = tmp_path / "blocklist.conf"
    monkeypatch.setattr(app_module, "BLOCKLIST_CONF", str(conf))
    monkeypatch.setattr(app_module, "load_blocklists", lambda: list(lists))
    monkeypatch.setattr(app_module, "load_whitelist", lambda: list(whitelist))
    monkeypatch.setattr(app_module, "load_blocklist_status", lambda: {})
    monkeypatch.setattr(app_module, "save_blocklist_status", lambda status: None)
    return conf


def test_write_blocklist_conf_reads_plain_and_hosts_lines(monkeypatch, tmp_path):
    # run.sh used to understand only the hosts format, so plain domain lists were
    # dropped on every add-on start.
    conf = _setup(monkeypatch, tmp_path, ["http://lists.test/plain.txt", "http://lists.test/hosts.txt"])
    texts = {
        "http://lists.test/plain.txt": "# plain list\nads.example.com\nTracker.Example.com\n",
        "http://lists.test/hosts.txt": "0.0.0.0 hosts.example.com\n127.0.0.1 localhost\n",
    }
    monkeypatch.setattr(app_module, "fetch_blocklist", lambda url: (texts[url], None))

    count, errors = app_module.write_blocklist_conf()

    assert count == 3
    assert errors == []
    assert conf.read_text(encoding="utf-8").splitlines() == [
        'local-zone: "ads.example.com." always_refuse',
        'local-zone: "hosts.example.com." always_refuse',
        'local-zone: "tracker.example.com." always_refuse',
    ]


def test_write_blocklist_conf_applies_whitelist_and_reports_errors(monkeypatch, tmp_path):
    conf = _setup(
        monkeypatch, tmp_path,
        ["http://lists.test/a.txt", "http://lists.test/broken.txt"],
        whitelist=["Keep.Example.com"],
    )

    def fake_fetch(url):
        if url.endswith("broken.txt"):
            return None, "curl: (7) Failed to connect"
        return "ads.example.com\nkeep.example.com\n", None

    monkeypatch.setattr(app_module, "fetch_blocklist", fake_fetch)

    count, errors = app_module.write_blocklist_conf()

    assert count == 1
    assert errors == [{"url": "http://lists.test/broken.txt", "error": "curl: (7) Failed to connect"}]
    assert conf.read_text(encoding="utf-8") == 'local-zone: "ads.example.com." always_refuse\n'
