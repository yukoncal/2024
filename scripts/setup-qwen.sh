#!/usr/bin/env bash
# Pull Qwen3.5 9B into Ollama and create a Cursor-safe alias.
set -euo pipefail

MODEL_SOURCE="${MODEL_SOURCE:-qwen3.5:9b}"
MODEL_ALIAS="${MODEL_ALIAS:-qwen359b}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODELFILE="${ROOT}/ollama/Modelfile"

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

echo "Pulling ${MODEL_SOURCE} (about 6.6GB)..."
ollama pull "${MODEL_SOURCE}"

echo "Creating Cursor-safe alias '${MODEL_ALIAS}' from ${MODELFILE}..."
# Keep Modelfile FROM in sync with MODEL_SOURCE when overridden.
tmp_modelfile="$(mktemp)"
trap 'rm -f "${tmp_modelfile}"' EXIT
sed "s|^FROM .*|FROM ${MODEL_SOURCE}|" "${MODELFILE}" >"${tmp_modelfile}"
ollama create "${MODEL_ALIAS}" -f "${tmp_modelfile}"

echo
echo "Installed models:"
ollama list

cat <<EOF

Next steps for Cursor:
  1. Expose Ollama over public HTTPS (Cursor cannot call localhost):
       ./scripts/expose-for-cursor.sh
  2. In Cursor: Settings → Models
       - OpenAI API Key: ollama
       - Override OpenAI Base URL: https://YOUR-TUNNEL/v1
       - Add model: ${MODEL_ALIAS}
  3. Pick ${MODEL_ALIAS} in the chat model picker (turn Auto off)

Local sanity check:
  ./scripts/verify-qwen.sh
EOF
