#!/usr/bin/env bash
# Pull Qwen2.5-Coder 7B into Ollama and create a Cursor-safe alias.
# Cursor rejects model names with ":" or "." (e.g. qwen2.5-coder:latest),
# which surfaces as: "The model you chose is not available."
set -euo pipefail

MODEL_SOURCE="${MODEL_SOURCE:-qwen2.5-coder:7b}"
MODEL_ALIAS="${MODEL_ALIAS:-qwen25-7b-coder}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Prefer the dedicated Modelfile when using the default coder model.
if [[ "${MODEL_SOURCE}" == "qwen2.5-coder:7b" && -f "${ROOT}/ollama/Modelfile-qwen25-7b-coder" ]]; then
  MODELFILE="${ROOT}/ollama/Modelfile-qwen25-7b-coder"
else
  MODELFILE="${ROOT}/ollama/Modelfile"
fi

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

echo "Pulling ${MODEL_SOURCE}..."
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
  2. In Cursor Desktop: Settings → Models
       - OpenAI API Key: ollama
       - Override OpenAI Base URL: https://YOUR-TUNNEL/v1
       - Add model: ${MODEL_ALIAS}
       - Do NOT add qwen2.5-coder:latest (Cursor rejects ":" / ".")
  3. In the chat model picker, turn Auto off and select ${MODEL_ALIAS}
  4. Send: Reply with exactly: ollama-ok

Local sanity check:
  MODEL_ALIAS=${MODEL_ALIAS} ./scripts/verify-qwen.sh
EOF
