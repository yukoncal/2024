#!/usr/bin/env bash
# Open an interactive Hermes chat using a free local Ollama model.
# Prefers the hermes alias created by setup-hermes.sh; falls back to openhermes.
set -euo pipefail

MODEL="${MODEL:-hermes}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v ollama >/dev/null 2>&1; then
  echo "Ollama is not installed. Install from https://ollama.com then re-run." >&2
  exit 1
fi

if ! curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
  echo "Starting Ollama serve in the background..."
  nohup ollama serve >/tmp/ollama-serve.log 2>&1 &
  for _ in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

if ! curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
  echo "Could not reach Ollama at http://127.0.0.1:11434" >&2
  echo "Start it with: ollama serve" >&2
  exit 1
fi

local_models="$(ollama list 2>/dev/null | awk 'NR>1 {print $1}')"

has_model() {
  local want="$1"
  local name
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    if [[ "$name" == "$want" || "$name" == "${want}:latest" || "${name%%:*}" == "$want" ]]; then
      return 0
    fi
  done <<<"$local_models"
  return 1
}

if ! has_model "$MODEL"; then
  if has_model openhermes; then
    MODEL="openhermes"
  else
    echo "No hermes/openhermes model found locally." >&2
    echo "Run first (uses your already-downloaded free model when present):" >&2
    echo "  ${ROOT}/scripts/setup-hermes.sh" >&2
    exit 1
  fi
fi

echo "Opening Hermes with free local model: ${MODEL}"
echo "(Ctrl+D or /bye to exit)"
echo
exec ollama run "${MODEL}"
