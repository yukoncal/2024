# Shared helpers for the locked free Hermes model.
# shellcheck shell=bash

HERMES_LOCK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERMES_LOCK_FILE="${HERMES_LOCK_ROOT}/config/hermes.lock.json"

hermes_lock_read_model() {
  if [[ -f "${HERMES_LOCK_FILE}" ]] && command -v python3 >/dev/null 2>&1; then
    python3 - "${HERMES_LOCK_FILE}" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
if not data.get("locked", True):
    raise SystemExit("hermes lock disabled")
print(data.get("model") or "hermes")
PY
    return 0
  fi
  echo "hermes"
}

hermes_lock_assert() {
  local want got
  want="$(hermes_lock_read_model)"
  got="${1:-}"
  if [[ -z "$got" ]]; then
    echo "$want"
    return 0
  fi
  if [[ "$got" != "$want" && "$got" != "${want}:latest" ]]; then
    echo "error: model '${got}' is blocked. Hermes is locked to free local model '${want}'." >&2
    echo "       Edit config/hermes.lock.json only if you intentionally unlock it." >&2
    return 1
  fi
  echo "$want"
}

hermes_lock_write_tunnel() {
  local base_url="$1"
  python3 - "${HERMES_LOCK_FILE}" "${base_url}" <<'PY'
import json, sys
path, base = sys.argv[1], sys.argv[2].rstrip("/")
with open(path, encoding="utf-8") as f:
    data = json.load(f)
data.setdefault("cursor_desktop", {})
data["cursor_desktop"]["override_openai_base_url"] = base + "/v1"
data["tunnel_base_url"] = base + "/v1"
data["locked"] = True
data["model"] = data.get("model") or "hermes"
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print(base + "/v1")
PY
}
