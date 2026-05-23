#!/usr/bin/env bash
set -euo pipefail

install_yq_binary() {
  local version="${YQ_VERSION:-v4.48.1}"
  local arch="amd64"
  local tmp="/tmp/yq_linux_${arch}"
  local urls=(
    "https://github.com/mikefarah/yq/releases/download/${version}/yq_linux_${arch}"
    "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}"
  )

  for url in "${urls[@]}"; do
    echo "Trying yq download: ${url}"
    if curl --fail --location --retry 5 --retry-delay 3 --retry-all-errors --connect-timeout 20 --max-time 120 -o "${tmp}" "${url}"; then
      sudo install -m 0755 "${tmp}" /usr/local/bin/yq
      yq --version
      return 0
    fi
  done

  return 1
}

install_yq_shim() {
  echo "WARN: GitHub yq binary download failed; installing minimal Python yq shim for this CI workflow." >&2
  sudo tee /usr/local/bin/yq >/dev/null <<'PY_YQ_SHIM'
#!/usr/bin/env python3
import re
import sys
from pathlib import Path
import yaml

VERSION = "yq shim 0.1 for TS6 Manager CI"


def fail(message: str, code: int = 2) -> None:
    print(f"yq-shim: {message}", file=sys.stderr)
    raise SystemExit(code)


def load_yaml(path: Path):
    if not path.exists():
        fail(f"file not found: {path}")
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    return data


def dump_yaml(path: Path, data) -> None:
    with path.open("w", encoding="utf-8") as handle:
        yaml.safe_dump(data, handle, default_flow_style=False, sort_keys=False, allow_unicode=True)


def split_path(path_expr: str):
    path_expr = path_expr.strip()
    if not path_expr.startswith("."):
        fail(f"unsupported expression path: {path_expr}")
    return [part for part in path_expr[1:].split(".") if part]


def get_value(data, parts):
    cur = data
    for part in parts:
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def set_value(data, parts, value):
    cur = data
    for part in parts[:-1]:
        nxt = cur.get(part)
        if not isinstance(nxt, dict):
            nxt = {}
            cur[part] = nxt
        cur = nxt
    cur[parts[-1]] = value


def parse_default(default_expr: str):
    default_expr = default_expr.strip()
    if default_expr in ("null", "~"):
        return None
    if default_expr.startswith('"') and default_expr.endswith('"'):
        return bytes(default_expr[1:-1], "utf-8").decode("unicode_escape")
    if default_expr.startswith("'") and default_expr.endswith("'"):
        return default_expr[1:-1]
    return default_expr


def print_scalar(value) -> None:
    if value is None:
        value = ""
    if isinstance(value, bool):
        print("true" if value else "false")
    elif isinstance(value, (dict, list)):
        print(yaml.safe_dump(value, default_flow_style=False, sort_keys=False).rstrip())
    else:
        print(str(value))


def cmd_read(expr: str, file_path: str) -> None:
    data = load_yaml(Path(file_path))
    if "//" in expr:
        path_expr, default_expr = expr.split("//", 1)
        default = parse_default(default_expr)
    else:
        path_expr, default = expr, None
    value = get_value(data, split_path(path_expr))
    if value is None:
        value = default
    print_scalar(value)


def cmd_inplace(expr: str, file_path: str) -> None:
    match = re.match(r'^\s*(\.[A-Za-z0-9_.-]+)\s*=\s*"(.*)"\s*$', expr)
    if not match:
        fail(f"unsupported inplace expression: {expr}")
    path_expr, raw_value = match.groups()
    value = bytes(raw_value, "utf-8").decode("unicode_escape")
    path = Path(file_path)
    data = load_yaml(path)
    set_value(data, split_path(path_expr), value)
    dump_yaml(path, data)


def main() -> None:
    args = sys.argv[1:]
    if not args or args == ["--version"]:
        print(VERSION)
        return
    if args[0] == "-r" and len(args) == 3:
        cmd_read(args[1], args[2])
        return
    if args[0] == "-i" and len(args) == 3:
        cmd_inplace(args[1], args[2])
        return
    fail("unsupported invocation: " + " ".join(args))


if __name__ == "__main__":
    main()
PY_YQ_SHIM
  sudo chmod +x /usr/local/bin/yq
  yq --version
}

install_yq_binary || install_yq_shim
