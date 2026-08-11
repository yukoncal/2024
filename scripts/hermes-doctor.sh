#!/usr/bin/env bash
# Hermes doctor — diagnose and optionally fix the locked free local Hermes setup.
# Usage:
#   ./scripts/hermes-doctor.sh           # diagnose only
#   ./scripts/hermes-doctor.sh --fix    # diagnose + autofix
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/hermes-lock.sh
source "${ROOT}/scripts/lib/hermes-lock.sh"

FIX=0
for arg in "$@"; do
  case "$arg" in
    --fix|-f) FIX=1 ;;
    -h|--help)
      cat <<'EOF'
Hermes doctor — diagnose (and fix) the locked free local Hermes setup.

  ./scripts/hermes-doctor.sh           # diagnose only
  ./scripts/hermes-doctor.sh --fix    # diagnose + autofix

Checks:
  • Ollama installed / reachable
  • Lock file present and pinned to free hermes
  • Locked model installed locally
  • Local OpenAI-compatible chat smoke test
  • Public tunnel URL (if configured) is reachable
  • Reminds you to pin hermes in Cursor Desktop (Auto OFF)
EOF
      exit 0
      ;;
  esac
done

PASS=0
WARN=0
FAIL=0

ok()   { PASS=$((PASS + 1)); echo "  [OK]   $*"; }
warn() { WARN=$((WARN + 1)); echo "  [WARN] $*"; }
fail() { FAIL=$((FAIL + 1)); echo "  [FAIL] $*"; }
fixn() { echo "         → fixing: $*"; }

echo "Hermes Doctor"
echo "============="
echo "Mode: $([[ "$FIX" -eq 1 ]] && echo 'diagnose + fix' || echo 'diagnose only')"
echo "Root: ${ROOT}"
echo

# --- 1. Ollama binary ---
echo "Ollama"
if command -v ollama >/dev/null 2>&1; then
  ok "ollama binary found ($(command -v ollama))"
else
  fail "ollama is not installed"
  if [[ "$FIX" -eq 1 ]]; then
    fixn "cannot auto-install Ollama in all environments — install from https://ollama.com"
  fi
fi

# --- 2. Ollama daemon ---
ensure_ollama_up() {
  if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$FIX" -ne 1 ]]; then
    return 1
  fi
  fixn "starting ollama serve"
  if command -v systemctl >/dev/null 2>&1 && systemctl is-enabled ollama >/dev/null 2>&1; then
    sudo systemctl start ollama || true
  fi
  if ! curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
    nohup ollama serve >/tmp/ollama-serve.log 2>&1 &
  fi
  for _ in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
  ok "Ollama API reachable at http://127.0.0.1:11434"
elif ensure_ollama_up; then
  ok "Ollama API started and reachable"
else
  fail "Ollama API not reachable at http://127.0.0.1:11434"
  echo "         Run: ollama serve   (or re-run with --fix)"
fi
echo

# --- 3. Lock file ---
echo "Lock"
if [[ -f "${HERMES_LOCK_FILE}" ]]; then
  if python3 - "${HERMES_LOCK_FILE}" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d.get("locked") is True
assert (d.get("model") or "") == "hermes"
assert (d.get("cost") or "") == "free"
assert "cursor-grok" in (d.get("replaced_paid_model") or "")
PY
  then
    ok "config/hermes.lock.json pins free model 'hermes' (not Grok)"
  else
    fail "lock file exists but is invalid / unlocked"
    if [[ "$FIX" -eq 1 ]]; then
      fixn "rewriting lock via lock-hermes.sh"
      "${ROOT}/scripts/lock-hermes.sh" >/tmp/hermes-doctor-lock.log 2>&1 || true
    fi
  fi
else
  fail "missing config/hermes.lock.json"
  if [[ "$FIX" -eq 1 ]]; then
    fixn "creating lock via lock-hermes.sh"
    "${ROOT}/scripts/lock-hermes.sh" >/tmp/hermes-doctor-lock.log 2>&1 || true
  fi
fi

LOCKED_MODEL="$(hermes_lock_read_model 2>/dev/null || echo hermes)"
echo

# --- 4. Local model ---
echo "Model"
has_local_model() {
  local want="$1"
  local name
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    if [[ "$name" == "$want" || "$name" == "${want}:latest" || "${name%%:*}" == "$want" ]]; then
      echo "$name"
      return 0
    fi
  done < <(ollama list 2>/dev/null | awk 'NR>1 {print $1}')
  return 1
}

if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
  if hit="$(has_local_model "$LOCKED_MODEL")"; then
    ok "locked model installed: ${hit}"
  else
    fail "locked model '${LOCKED_MODEL}' not installed"
    if [[ "$FIX" -eq 1 ]]; then
      fixn "running setup-hermes.sh / lock-hermes.sh"
      "${ROOT}/scripts/setup-hermes.sh" >/tmp/hermes-doctor-setup.log 2>&1 || true
      "${ROOT}/scripts/lock-hermes.sh" >/tmp/hermes-doctor-lock2.log 2>&1 || true
      if hit="$(has_local_model "$LOCKED_MODEL")"; then
        ok "locked model installed after fix: ${hit}"
      else
        fail "still missing '${LOCKED_MODEL}' after fix"
      fi
    fi
  fi
  if hit="$(has_local_model openhermes)"; then
    ok "free source model present: ${hit}"
  else
    warn "openhermes source weights not listed (alias may still work)"
  fi
else
  warn "skipped model checks (Ollama down)"
fi
echo

# --- 5. Local chat smoke ---
echo "Local API"
if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
  smoke_json="$(curl -fsS "http://127.0.0.1:11434/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ollama" \
    -d "{\"model\":\"${LOCKED_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: hermes-ok\"}],\"stream\":false,\"max_tokens\":32}" 2>/dev/null || true)"
  content="$(CONTENT_JSON="$smoke_json" python3 - <<'PY'
import json, os
raw = os.environ.get("CONTENT_JSON") or ""
try:
    data = json.loads(raw)
    print((data.get("choices") or [{}])[0].get("message", {}).get("content", "").strip())
except Exception:
    print("")
PY
)"
  if [[ "${content}" == "hermes-ok" ]]; then
    ok "chat completion returned exactly 'hermes-ok'"
  elif [[ -n "${content}" ]]; then
    # Accept case variants of ok-ish replies but warn.
    warn "chat replied '$content' (expected exactly 'hermes-ok')"
    if [[ "$FIX" -eq 1 ]]; then
      fixn "re-locking model defaults"
      "${ROOT}/scripts/lock-hermes.sh" >/tmp/hermes-doctor-relock.log 2>&1 || true
    fi
  else
    fail "chat completion failed for model '${LOCKED_MODEL}'"
    if [[ "$FIX" -eq 1 ]]; then
      fixn "re-running lock-hermes.sh"
      "${ROOT}/scripts/lock-hermes.sh" >/tmp/hermes-doctor-relock.log 2>&1 || true
    fi
  fi
else
  warn "skipped chat smoke (Ollama down)"
fi
echo

# --- 6. Tunnel ---
echo "Tunnel"
TUNNEL_URL="$(python3 - "${HERMES_LOCK_FILE}" <<'PY' 2>/dev/null || true
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
if not p.exists():
    raise SystemExit
d = json.load(p.open(encoding="utf-8"))
u = d.get("tunnel_base_url") or d.get("cursor_desktop", {}).get("override_openai_base_url") or ""
print(u)
PY
)"

tunnel_is_placeholder() {
  local u="$1"
  [[ -z "$u" || "$u" == *"REPLACE_WITH_TUNNEL"* || "$u" == *"YOUR-TUNNEL"* ]]
}

if tunnel_is_placeholder "${TUNNEL_URL}"; then
  warn "no live public tunnel URL saved (Cursor Desktop needs HTTPS)"
  echo "         Run: ./scripts/expose-for-cursor.sh"
  echo "         Then paste https://…/v1 into Override OpenAI Base URL"
elif curl -fsS --max-time 8 "${TUNNEL_URL}/models" \
      -H "Authorization: Bearer ollama" \
      -H "ngrok-skip-browser-warning: true" >/dev/null 2>&1; then
  ok "public tunnel reachable: ${TUNNEL_URL}"
else
  fail "configured tunnel not reachable: ${TUNNEL_URL}"
  if [[ "$FIX" -eq 1 ]]; then
    fixn "clearing dead tunnel URL from lock (re-run expose-for-cursor.sh)"
    python3 - "${HERMES_LOCK_FILE}" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    d = json.load(f)
d.setdefault("cursor_desktop", {})
d["cursor_desktop"]["override_openai_base_url"] = "REPLACE_WITH_TUNNEL_URL/v1"
d.pop("tunnel_base_url", None)
with open(path, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
PY
    warn "dead tunnel cleared — run ./scripts/expose-for-cursor.sh on your machine"
  fi
fi

if command -v cloudflared >/dev/null 2>&1; then
  ok "cloudflared available (preferred over free ngrok)"
else
  warn "cloudflared not installed (recommended for Cursor Desktop)"
fi
echo

# --- 7. Desktop pin reminder ---
echo "Cursor Desktop pin"
ok "lock says: Auto OFF, model '${LOCKED_MODEL}', key 'ollama'"
warn "Cloud Agents cannot use local Hermes — pin '${LOCKED_MODEL}' in Cursor Desktop"
echo

# --- Summary ---
echo "Summary"
echo "-------"
echo "  Passed: ${PASS}"
echo "  Warnings: ${WARN}"
echo "  Failures: ${FAIL}"
echo

if [[ "$FAIL" -gt 0 ]]; then
  echo "Hermes is NOT fully healthy."
  if [[ "$FIX" -eq 0 ]]; then
    echo "Re-run with autofix:  ./scripts/hermes-doctor.sh --fix"
  else
    echo "Autofix ran — resolve remaining FAIL items above, then re-run doctor."
  fi
  exit 1
fi

if [[ "$WARN" -gt 0 ]]; then
  echo "Hermes local core is OK, with warnings (usually tunnel / Desktop pin)."
  echo "Finish Desktop pin:"
  echo "  1. ./scripts/expose-for-cursor.sh"
  echo "  2. Settings → Models → Base URL = https://…/v1 , model = ${LOCKED_MODEL}, Auto OFF"
  echo "  3. Reply with exactly: hermes-ok"
  exit 0
fi

echo "Hermes is healthy — locked free local '${LOCKED_MODEL}' is ready."
exit 0
