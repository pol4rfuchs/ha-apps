from conftest import WEB_DIR, install_flask_stub, load_module

install_flask_stub()
app_module = load_module("app", WEB_DIR / "app.py")


def _setup(monkeypatch, tmp_path, lists, whitelist=()):
    conf = tmp_path / "blocklist.conf"
    monkeypatch.setattr(app_module, "BLOCKLIST_CONF", str(conf))
    monkeypatch.setattr(app_module, "BLOCKLIST_CACHE_DIR", str(tmp_path / "cache"))
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
        'local-zone: "ads.example.com." always_null',
        'local-zone: "hosts.example.com." always_null',
        'local-zone: "tracker.example.com." always_null',
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
    assert conf.read_text(encoding="utf-8") == 'local-zone: "ads.example.com." always_null\n'


def test_parse_blocklist_line_adblock_domain_rules():
    # OISD/Hagezi publish this format; it used to yield 0 domains without an error.
    assert app_module.parse_blocklist_line("||Ads.Example.com^") == "ads.example.com"
    assert app_module.parse_blocklist_line("@@||good.example.com^") is None
    assert app_module.parse_blocklist_line("||tracker.test^$third-party") is None
    assert app_module.parse_blocklist_line("||example.com/path^") is None
    assert app_module.parse_blocklist_line("! comment") is None
    assert app_module.parse_blocklist_line("[Adblock Plus 2.0]") is None


def test_failed_download_falls_back_to_cached_copy(monkeypatch, tmp_path):
    conf = _setup(monkeypatch, tmp_path, ["http://lists.test/a.txt"])
    monkeypatch.setattr(app_module, "fetch_blocklist", lambda url: ("ads.example.com\n", None))
    assert app_module.write_blocklist_conf() == (1, [])

    monkeypatch.setattr(app_module, "fetch_blocklist", lambda url: (None, "curl: (6) Could not resolve host"))
    count, errors = app_module.write_blocklist_conf()

    assert count == 1
    assert "using cached copy" in errors[0]["error"]
    assert conf.read_text(encoding="utf-8") == 'local-zone: "ads.example.com." always_null\n'


def test_whitelisted_subdomain_of_blocked_zone_gets_transparent_zone(monkeypatch, tmp_path):
    conf = _setup(monkeypatch, tmp_path, ["http://lists.test/a.txt"],
                  whitelist=["keep.example.com", "unrelated.test"])
    monkeypatch.setattr(app_module, "fetch_blocklist", lambda url: ("example.com\n", None))

    count, _ = app_module.write_blocklist_conf()

    assert count == 1
    assert conf.read_text(encoding="utf-8").splitlines() == [
        'local-zone: "example.com." always_null',
        'local-zone: "keep.example.com." transparent',
    ]


def test_parse_query_log_counts_each_query_once():
    # log-queries and log-replies together write two lines per query.
    both = (
        "[1700000000] unbound[1:0] info: 127.0.0.1 ads.example.com. A IN\n"
        "[1700000000] unbound[1:0] info: 127.0.0.1 ads.example.com. A IN REFUSED 0.000000 1 44\n"
    )
    replies_only = "[1700000000] unbound[1:0] info: 127.0.0.1 nas.lan. A IN NOERROR 0.000000 1 52\n"

    assert [e["domain"] for e in app_module.parse_query_log(both)] == ["ads.example.com"]
    assert [e["domain"] for e in app_module.parse_query_log(replies_only)] == ["nas.lan"]
