#!/usr/bin/env bash
# Lock Hermes to the free local Ollama model and print the Cursor Desktop pin steps.
# Replaces paid Grok 4.5 High Fast for everyday Hermes use.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/hermes-lock.sh
source "${ROOT}/scripts/lib/hermes-lock.sh"

echo "==> Ensuring free local Hermes model is installed (no paid cloud model)"
"${ROOT}/scripts/setup-hermes.sh"

LOCKED_MODEL="$(hermes_lock_read_model)"
SOURCE="$(python3 - "${HERMES_LOCK_FILE}" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
print(d.get("source_model", "openhermes:latest"))
PY
)"

# Refresh lock metadata from the live Ollama install when possible.
if command -v ollama >/dev/null 2>&1 && curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
  live_source="$(ollama list 2>/dev/null | awk 'NR>1 && $1 ~ /^openhermes/ {print $1; exit}')"
  if [[ -n "${live_source}" ]]; then
    SOURCE="${live_source}"
  fi
fi

python3 - "${HERMES_LOCK_FILE}" "${LOCKED_MODEL}" "${SOURCE}" <<'PY'
import json, sys
path, model, source = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
data["locked"] = True
data["model"] = model
data["source_model"] = source
data["cost"] = "free"
data["provider"] = "ollama-local"
data["replaced_paid_model"] = "cursor-grok-4.5-high-fast"
data.setdefault("replaced_paid_pricing", {
    "variant": "Grok 4.5 Fast",
    "input_per_million_usd": 4,
    "output_per_million_usd": 18,
})
data.setdefault("cursor_desktop", {})
data["cursor_desktop"]["openai_api_key"] = "ollama"
data["cursor_desktop"]["add_custom_model"] = model
data["cursor_desktop"]["turn_auto_off"] = True
data["cursor_desktop"]["select_model"] = model
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

echo
echo "==> Smoke-testing locked model '${LOCKED_MODEL}'"
MODEL="${LOCKED_MODEL}" "${ROOT}/scripts/verify-hermes.sh"

BASE_URL="$(python3 - "${HERMES_LOCK_FILE}" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
print(d.get("tunnel_base_url") or d.get("cursor_desktop", {}).get("override_openai_base_url") or "")
PY
)"

cat <<EOF

============================================================
HERMES LOCKED — FREE LOCAL MODEL (replaces Grok 4.5 High Fast)
============================================================
Lock file:  ${HERMES_LOCK_FILE}
Model:      ${LOCKED_MODEL}  (source: ${SOURCE})
Cost:       \$0  (runs on your machine via Ollama)

Grok 4.5 High Fast pricing (what this replaces):
  Fast variant: \$4 / M input tokens, \$18 / M output tokens
  Base Grok 4.5: \$2 / M input, \$6 / M output
  "High" effort does not change the rate — it burns more tokens per task.

IMPORTANT:
  • This Cloud Agent tab CANNOT switch off Grok mid-run.
  • For free Hermes every time: use Cursor DESKTOP (not Cloud Agents).
  • Turn Auto OFF and pin model '${LOCKED_MODEL}'.

Cursor Desktop → Settings → Models (lock these):
  OpenAI API Key:            ollama
  Override OpenAI Base URL:  ${BASE_URL:-https://YOUR-TUNNEL/v1}
  Add custom model:          ${LOCKED_MODEL}
  Chat model picker:         Auto OFF → select ${LOCKED_MODEL}

Next steps to finish the fix:
  1. On your machine: keep Ollama running (\`ollama serve\`)
  2. Hermes Agent (free local): ./scripts/hermes-use-ollama.sh && hermes
  3. Cursor Desktop — expose HTTPS (Cloudflare preferred):
       ./scripts/expose-for-cursor.sh
  4. Paste the printed https://…/v1 URL into Override OpenAI Base URL
  5. Add model \`${LOCKED_MODEL}\`, turn Auto off, select \`${LOCKED_MODEL}\`
  6. Smoke test: Reply with exactly: hermes-ok
  7. For future Cloud Agents: do NOT pick Grok 4.5 High Fast for Hermes work

Open local free chat anytime:
  ./scripts/open-hermes.sh
Diagnose anytime:
  ./scripts/hermes-doctor.sh --fix
============================================================
EOF
