#!/usr/bin/env bash
# Verify the OpenAI-compatible Ollama endpoint for the locked free Hermes model.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/hermes-lock.sh
source "${ROOT}/scripts/lib/hermes-lock.sh"

BASE_URL="${BASE_URL:-http://127.0.0.1:11434/v1}"
MODEL="$(hermes_lock_assert "${MODEL:-}")" || exit 1
EXPECT="${EXPECT:-hermes-ok}"

echo "Listing models at ${BASE_URL}/models ..."
curl -fsS "${BASE_URL}/models" | sed 's/},{/},\n{/g'
echo
echo

echo "Chat completion smoke test with locked free model '${MODEL}' ..."
response="$(curl -fsS "${BASE_URL}/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ollama" \
  -d "{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: ${EXPECT}\"}],\"stream\":false,\"max_tokens\":32}")"

echo "${response}"
CONTENT_JSON="$response" EXPECT="$EXPECT" python3 - <<'PY'
import json, os, sys
expect = os.environ["EXPECT"].strip().lower()
data = json.loads(os.environ["CONTENT_JSON"])
content = (
    data.get("choices", [{}])[0]
    .get("message", {})
    .get("content", "")
    .strip()
)
print("assistant:", content)
if content.lower() != expect:
    print("error: expected %r (case-insensitive), got %r" % (expect, content), file=sys.stderr)
    print("hint: run ./scripts/hermes-doctor.sh --fix", file=sys.stderr)
    sys.exit(1)
print("OK — locked free Hermes is ready (not Grok).")
PY
