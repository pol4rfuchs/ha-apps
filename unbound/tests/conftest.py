import importlib.util
import sys
import types
from pathlib import Path

UNBOUND_DIR = Path(__file__).resolve().parents[1]
WEB_DIR = UNBOUND_DIR / "web"


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def install_flask_stub():
    if "flask" in sys.modules:
        return
    flask = types.ModuleType("flask")

    class Flask:
        def __init__(self, *args, **kwargs):
            pass
        def route(self, *args, **kwargs):
            def decorator(func):
                return func
            return decorator
        def run(self, *args, **kwargs):
            return None

    flask.Flask = Flask
    flask.jsonify = lambda *args, **kwargs: args[0] if args else kwargs
    flask.render_template = lambda *args, **kwargs: ""
    flask.request = types.SimpleNamespace(get_json=lambda: None, args={})
    sys.modules["flask"] = flask
