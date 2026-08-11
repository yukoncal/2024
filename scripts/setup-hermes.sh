#!/usr/bin/env bash
# Pull OpenHermes into Ollama so it's ready to use from Cursor.
# OpenHermes has no "." in its name, so (unlike Qwen3.5) no Cursor-safe alias is needed.
set -euo pipefail

MODEL_SOURCE="${MODEL_SOURCE:-openhermes}"

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

echo "Pulling ${MODEL_SOURCE} (about 4.1GB)..."
ollama pull "${MODEL_SOURCE}"

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
       - Add model: ${MODEL_SOURCE}
  3. Pick ${MODEL_SOURCE} in the chat model picker (turn Auto off)

Local sanity check:
  ./scripts/verify-hermes.sh
EOF
