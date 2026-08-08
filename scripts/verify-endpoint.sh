#!/usr/bin/env bash
# Smoke-test an Ollama OpenAI-compatible /v1 endpoint for Cursor.
# Lists models, runs one chat completion, exits non-zero on failure.
set -euo pipefail

# Prefer a live local daemon; fall back to OLLAMA_BASE_URL if set.
# Do not ship a hardcoded ngrok host — free tunnels die when restarted.
if [[ -n "${OLLAMA_BASE_URL:-}" ]]; then
  BASE_URL="${OLLAMA_BASE_URL}"
elif curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
  BASE_URL="http://127.0.0.1:11434/v1"
else
  cat <<'EOF' >&2
error: no Ollama endpoint configured.

Start local Ollama:
  ollama serve

Or point at a public HTTPS tunnel (required for Cursor Desktop):
  OLLAMA_BASE_URL='https://YOUR-TUNNEL-HOST/v1' ./scripts/verify-endpoint.sh

Create a tunnel with:
  ./scripts/expose-for-cursor.sh
EOF
  exit 1
fi

MODEL="${OLLAMA_MODEL:-qwen2.5-coder:latest}"
EXPECT="${OLLAMA_EXPECT:-ollama-ok}"

if ! command -v curl >/dev/null 2>&1; then
  echo "error: missing required command: curl" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "error: missing required command: python3" >&2
  exit 1
fi

if [[ "$BASE_URL" == *"ngrok"* ]]; then
  echo "note: ngrok endpoint detected. if this script passes but Cursor fails,"
  echo "      it is likely because Cursor does not send the 'ngrok-skip-browser-warning' header."
  echo "      Prefer ./scripts/expose-for-cursor.sh with cloudflared."
fi

echo "==> GET ${BASE_URL}/models"
set +e
models_json=$(curl -sS --fail \
  -H "ngrok-skip-browser-warning: true" \
  -H "Authorization: Bearer ollama" \
  "${BASE_URL}/models" 2>/tmp/verify-endpoint.err)
curl_status=$?
set -e
if [[ $curl_status -ne 0 ]]; then
  echo "error: GET ${BASE_URL}/models failed" >&2
  cat /tmp/verify-endpoint.err >&2 || true
  echo "hint: free ngrok/cloudflare URLs change when the tunnel restarts — refresh OLLAMA_BASE_URL" >&2
  exit 1
fi

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
