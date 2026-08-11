#!/usr/bin/env bash
# Open Hermes using a free model you already downloaded in Ollama.
# Prefers a local openhermes (or MODEL_SOURCE). Only pulls if nothing suitable is present.
# Creates a short Cursor-safe alias: hermes
set -euo pipefail

MODEL_ALIAS="${MODEL_ALIAS:-hermes}"
PREFERRED_SOURCE="${MODEL_SOURCE:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODELFILE="${ROOT}/ollama/Modelfile.hermes"
# Free models we will reuse if already downloaded (first match wins when MODEL_SOURCE unset).
CANDIDATES=(openhermes openhermes:latest llama3.1:8b mistral phi3)

if ! command -v ollama >/dev/null 2>&1; then
  cat <<'EOF'
Ollama is not installed.

Install it, then re-run this script:
  macOS/Linux:  curl -fsSL https://ollama.com/install.sh | sh
  Windows:      https://ollama.com/download

Docs: https://ollama.com
EOF
  exit 1
fi

# Ensure the Ollama daemon is reachable.
if ! curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
  echo "Starting Ollama serve in the background..."
  if command -v systemctl >/dev/null 2>&1 && systemctl is-enabled ollama >/dev/null 2>&1; then
    sudo systemctl start ollama || true
  fi
  if ! curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
    nohup ollama serve >/tmp/ollama-serve.log 2>&1 &
    for _ in $(seq 1 30); do
      if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done
  fi
fi

if ! curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
  echo "Could not reach Ollama at http://127.0.0.1:11434" >&2
  echo "Start it manually with: ollama serve" >&2
  exit 1
fi

local_models="$(ollama list 2>/dev/null | awk 'NR>1 {print $1}')"

model_is_local() {
  local want="$1"
  local name
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    if [[ "$name" == "$want" || "$name" == "${want}:latest" || "${name%%:*}" == "$want" ]]; then
      echo "$name"
      return 0
    fi
  done <<<"$local_models"
  return 1
}

resolve_source() {
  local hit
  if [[ -n "$PREFERRED_SOURCE" ]]; then
    if hit="$(model_is_local "$PREFERRED_SOURCE")"; then
      echo "$hit"
      return 0
    fi
    # Explicit override may not be local yet — caller will pull.
    echo "$PREFERRED_SOURCE"
    return 0
  fi

  local candidate
  for candidate in "${CANDIDATES[@]}"; do
    if hit="$(model_is_local "$candidate")"; then
      echo "$hit"
      return 0
    fi
  done

  # Nothing free/local found — fall back to openhermes (will pull).
  echo "openhermes"
}

MODEL_SOURCE="$(resolve_source)"

if hit="$(model_is_local "$MODEL_SOURCE")"; then
  MODEL_SOURCE="$hit"
  echo "Using already-downloaded free model: ${MODEL_SOURCE}"
else
  echo "No matching local free model found. Pulling ${MODEL_SOURCE}..."
  ollama pull "${MODEL_SOURCE}"
  # Refresh list after pull so alias FROM matches the installed tag.
  local_models="$(ollama list 2>/dev/null | awk 'NR>1 {print $1}')"
  if hit="$(model_is_local "$MODEL_SOURCE")"; then
    MODEL_SOURCE="$hit"
  fi
fi

echo "Creating Cursor-safe alias '${MODEL_ALIAS}' from ${MODEL_SOURCE}..."
tmp_modelfile="$(mktemp)"
trap 'rm -f "${tmp_modelfile}"' EXIT
sed "s|^FROM .*|FROM ${MODEL_SOURCE}|" "${MODELFILE}" >"${tmp_modelfile}"
ollama create "${MODEL_ALIAS}" -f "${tmp_modelfile}"

echo
echo "Installed models:"
ollama list

cat <<EOF

Hermes is ready (backed by free model: ${MODEL_SOURCE}).

Open a local chat:
  ./scripts/open-hermes.sh

Next steps for Cursor:
  1. Expose Ollama over public HTTPS (Cursor cannot call localhost):
       ./scripts/expose-for-cursor.sh
  2. In Cursor: Settings → Models
       - OpenAI API Key: ollama
       - Override OpenAI Base URL: https://YOUR-TUNNEL/v1
       - Add model: ${MODEL_ALIAS}
  3. Pick ${MODEL_ALIAS} in the chat model picker (turn Auto off)

Local sanity check:
  ./scripts/verify-hermes.sh

Override the source model anytime:
  MODEL_SOURCE=llama3.1:8b ./scripts/setup-hermes.sh
EOF
