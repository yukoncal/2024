#!/usr/bin/env bash
# Smoke-test the public Ollama OpenAI-compatible endpoint for Cursor.
# Lists models, runs one chat completion, exits non-zero on failure.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="${ROOT}/config/hermes.lock.json"

# Prefer env, then locked tunnel URL, then local Ollama (dead ngrok URLs are not defaults).
if [[ -z "${OLLAMA_BASE_URL:-}" && -f "${LOCK_FILE}" ]]; then
  OLLAMA_BASE_URL="$(python3 - "${LOCK_FILE}" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
print(d.get("tunnel_base_url") or d.get("cursor_desktop", {}).get("override_openai_base_url") or "")
PY
)"
fi
if [[ -z "${OLLAMA_BASE_URL:-}" || "${OLLAMA_BASE_URL}" == *"REPLACE_WITH_TUNNEL"* || "${OLLAMA_BASE_URL}" == *"YOUR-TUNNEL"* ]]; then
  OLLAMA_BASE_URL="http://127.0.0.1:11434/v1"
fi
BASE_URL="${OLLAMA_BASE_URL}"

if [[ -z "${OLLAMA_MODEL:-}" && -f "${LOCK_FILE}" ]]; then
  OLLAMA_MODEL="$(python3 - "${LOCK_FILE}" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8")).get("model", "hermes"))
PY
)"
fi
MODEL="${OLLAMA_MODEL:-hermes}"
EXPECT="${OLLAMA_EXPECT:-ok}"

if ! command -v curl >/dev/null 2>&1; then
  echo "error: missing required command: curl" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "error: missing required command: python3" >&2
  exit 1
fi

if [[ "$BASE_URL" == *"ngrok-free"* ]]; then
  echo "note: ngrok endpoint detected. if this script passes but Cursor fails,"
  echo "      it is likely because Cursor does not send the 'ngrok-skip-browser-warning' header."
fi

echo "==> GET ${BASE_URL}/models"
models_json=$(curl -sS --fail \
  -H "ngrok-skip-browser-warning: true" \
  -H "Authorization: Bearer ollama" \
  "${BASE_URL}/models")

MODELS_JSON="$models_json" python3 -c '
import json, os, sys
data = json.loads(os.environ["MODELS_JSON"])
ids = [m.get("id", "?") for m in data.get("data", [])]
print("models:", ", ".join(ids) if ids else "(none)")
sys.exit(0 if ids else 1)
'

echo
echo "==> POST ${BASE_URL}/chat/completions (model=${MODEL})"
payload=$(MODEL="$MODEL" EXPECT="$EXPECT" python3 -c '
import json, os
print(json.dumps({
    "model": os.environ["MODEL"],
    "messages": [{"role": "user", "content": "Reply with exactly: " + os.environ["EXPECT"]}],
    "max_tokens": 32,
}))
')

chat_json=$(curl -sS --fail \
  -H "ngrok-skip-browser-warning: true" \
  -H "Authorization: Bearer ollama" \
  -H "Content-Type: application/json" \
  -d "$payload" \
  "${BASE_URL}/chat/completions")

CHAT_JSON="$chat_json" OLLAMA_EXPECT="$EXPECT" python3 -c '
import json, os, sys
expect = os.environ["OLLAMA_EXPECT"]
data = json.loads(os.environ["CHAT_JSON"])
content = (
    data.get("choices", [{}])[0]
    .get("message", {})
    .get("content", "")
    .strip()
)
print("assistant:", content)
if content != expect:
    print("error: expected exactly %r, got %r" % (expect, content), file=sys.stderr)
    sys.exit(1)
print("ok: chat completion matched expected reply")
'

echo
echo "Smoke test passed for ${MODEL} at ${BASE_URL}"
