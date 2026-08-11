#!/usr/bin/env bash
# Verify the OpenAI-compatible Ollama endpoint for OpenHermes.
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:11434/v1}"
MODEL="${MODEL:-openhermes}"

echo "Listing models at ${BASE_URL}/models ..."
curl -fsS "${BASE_URL}/models" | sed 's/},{/},\n{/g'
echo
echo

echo "Chat completion smoke test with model '${MODEL}' ..."
response="$(curl -fsS "${BASE_URL}/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ollama" \
  -d "{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: ok\"}],\"stream\":false,\"max_tokens\":32}")"

echo "${response}"
if echo "${response}" | grep -qi '"content"'; then
  echo
  echo "OK — endpoint looks ready for Cursor (use a public HTTPS base URL in Cursor settings)."
else
  echo
  echo "Unexpected response — check that the model is pulled: ollama list" >&2
  exit 1
fi
