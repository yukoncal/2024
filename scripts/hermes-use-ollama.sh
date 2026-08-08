#!/usr/bin/env bash
# Point Hermes Agent / Hermes Desktop at local Ollama (Custom Endpoint).
# Local Ollama is NOT provider "ollama" — use provider "custom" + /v1 base URL.
set -euo pipefail

OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
BASE_URL="${OLLAMA_BASE_URL:-http://${OLLAMA_HOST}:${OLLAMA_PORT}/v1}"
MODEL="${OLLAMA_MODEL:-qwen2.5-coder:latest}"
CONTEXT_LENGTH="${OLLAMA_CONTEXT_LENGTH:-8192}"
HERMES_HOME="${HERMES_HOME:-${HOME}/.hermes}"
CONFIG="${HERMES_HOME}/config.yaml"
PULL="${PULL:-1}"

if ! command -v curl >/dev/null 2>&1; then
  echo "error: missing required command: curl" >&2
  exit 1
fi

if ! curl -fsS "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/tags" >/dev/null 2>&1; then
  echo "Ollama is not reachable at http://${OLLAMA_HOST}:${OLLAMA_PORT}" >&2
  echo "Start it with: ollama serve   (or ./scripts/setup-qwen.sh)" >&2
  exit 1
fi

if [[ "${PULL}" == "1" ]] && command -v ollama >/dev/null 2>&1; then
  if ! ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "${MODEL}"; then
    echo "Pulling ${MODEL}..."
    ollama pull "${MODEL}"
  fi
fi

mkdir -p "${HERMES_HOME}"

wrote_via=""
if command -v hermes >/dev/null 2>&1; then
  # Prefer CLI when available (Hermes Desktop / Agent).
  if hermes config set model.provider custom \
    && hermes config set model.base_url "${BASE_URL}" \
    && hermes config set model.default "${MODEL}"; then
    # Optional keys — ignore failures on older Hermes builds.
    hermes config set model.context_length "${CONTEXT_LENGTH}" >/dev/null 2>&1 || true
    hermes config set model.api_mode chat_completions >/dev/null 2>&1 || true
    wrote_via="hermes config set"
  fi
fi

if [[ -z "${wrote_via}" ]]; then
  if ! command -v python3 >/dev/null 2>&1; then
    echo "error: need hermes CLI or python3 to write ${CONFIG}" >&2
    exit 1
  fi
  CONFIG="${CONFIG}" BASE_URL="${BASE_URL}" MODEL="${MODEL}" CONTEXT_LENGTH="${CONTEXT_LENGTH}" python3 - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["CONFIG"])
base_url = os.environ["BASE_URL"]
model = os.environ["MODEL"]
ctx = int(os.environ["CONTEXT_LENGTH"])

try:
    import yaml  # type: ignore
except ImportError:
    yaml = None

data = {}
if path.exists():
    text = path.read_text(encoding="utf-8")
    if yaml is not None:
        data = yaml.safe_load(text) or {}
    else:
    # Minimal fallback: replace/append model block without PyYAML.
        # Use (?m) only — (?s) would let '.' eat following top-level keys.
        import re
        body = re.sub(
            r"(?m)^model:\n(?:[ \t]+.+\n)*",
            "",
            text,
        )
        block = (
            "model:\n"
            f"  provider: custom\n"
            f"  default: {model}\n"
            f"  base_url: {base_url}\n"
            f"  context_length: {ctx}\n"
            f"  api_mode: chat_completions\n"
        )
        rest = body.lstrip("\n")
        path.write_text(block + ("\n" + rest if rest else ""), encoding="utf-8")
        print(path)
        raise SystemExit(0)

if not isinstance(data, dict):
    data = {}

model_cfg = data.get("model")
if not isinstance(model_cfg, dict):
    model_cfg = {}
model_cfg["provider"] = "custom"
model_cfg["default"] = model
model_cfg["base_url"] = base_url
model_cfg["context_length"] = ctx
model_cfg["api_mode"] = "chat_completions"
data["model"] = model_cfg

if yaml is not None:
    path.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
else:
    raise SystemExit("python3 PyYAML missing and hermes CLI unavailable")
print(path)
PY
  wrote_via="config.yaml edit"
fi

cat <<EOF

Changed Hermes to local Ollama (${wrote_via}):

  provider:       custom
  base_url:       ${BASE_URL}
  default model:  ${MODEL}
  context_length: ${CONTEXT_LENGTH}

Config: ${CONFIG}

Next:
  1. Keep Ollama running:  ollama serve
  2. Restart Hermes Desktop (or run: hermes)
  3. In Desktop model picker, select ${MODEL}
     (turn Auto off if present)

Overrides:
  OLLAMA_MODEL=hermes3:8b ./scripts/hermes-use-ollama.sh
  OLLAMA_MODEL=llama3.1:8b PULL=0 ./scripts/hermes-use-ollama.sh

Note: provider must be "custom" for local Ollama — not "ollama"
      ("ollama" / "ollama-cloud" is the hosted Ollama Cloud API).
EOF
