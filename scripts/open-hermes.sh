#!/usr/bin/env bash
# Open an interactive Hermes chat using the locked free local Ollama model.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/hermes-lock.sh
source "${ROOT}/scripts/lib/hermes-lock.sh"

MODEL="$(hermes_lock_assert "${MODEL:-}")" || exit 1

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
  echo "Locked model '${MODEL}' not found locally." >&2
  echo "Run: ${ROOT}/scripts/lock-hermes.sh" >&2
  exit 1
fi

echo "Opening locked free Hermes model: ${MODEL}"
echo "(Ctrl+D or /bye to exit) — not Grok; \$0 local Ollama"
echo
exec ollama run "${MODEL}"
