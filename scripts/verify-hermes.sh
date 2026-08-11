#!/usr/bin/env bash
# Verify the OpenAI-compatible Ollama endpoint for the locked free Hermes model.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/hermes-lock.sh
source "${ROOT}/scripts/lib/hermes-lock.sh"

BASE_URL="${BASE_URL:-http://127.0.0.1:11434/v1}"
MODEL="$(hermes_lock_assert "${MODEL:-}")" || exit 1

echo "Listing models at ${BASE_URL}/models ..."
curl -fsS "${BASE_URL}/models" | sed 's/},{/},\n{/g'
echo
echo

echo "Chat completion smoke test with locked free model '${MODEL}' ..."
response="$(curl -fsS "${BASE_URL}/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ollama" \
  -d "{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: ok\"}],\"stream\":false,\"max_tokens\":32}")"

echo "${response}"
if echo "${response}" | grep -qi '"content"'; then
  echo
  echo "OK — locked free Hermes is ready (not Grok)."
else
  echo
  echo "Unexpected response — run ./scripts/lock-hermes.sh first." >&2
  exit 1
fi
