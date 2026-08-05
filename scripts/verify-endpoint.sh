#!/usr/bin/env bash
# Smoke-test the public Ollama OpenAI-compatible endpoint for Cursor.
set -euo pipefail

BASE_URL="${OLLAMA_BASE_URL:-https://brought-passage-trapeze.ngrok-free.dev/v1}"
MODEL="${OLLAMA_MODEL:-qwen359b}"
HDR=(-H "ngrok-skip-browser-warning: true" -H "Authorization: Bearer ollama")

echo "Checking models at ${BASE_URL}/models ..."
curl -sS "${BASE_URL}/models" "${HDR[@]}" | head -c 2000
echo
echo

echo "Chat completion with model=${MODEL} ..."
curl -sS "${BASE_URL}/chat/completions" \
  "${HDR[@]}" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: ok\"}],\"max_tokens\":256}"
echo
