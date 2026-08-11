#!/usr/bin/env bash
# Point Hermes Agent / Hermes Desktop at local Ollama (Custom Endpoint).
# Local Ollama is NOT provider "ollama" / "ollama-cloud" — use provider "custom" + /v1.
# Defaults to the locked free model from config/hermes.lock.json (usually `hermes`).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/hermes-lock.sh
source "${ROOT}/scripts/lib/hermes-lock.sh"

OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
BASE_URL="${OLLAMA_BASE_URL:-http://${OLLAMA_HOST}:${OLLAMA_PORT}/v1}"
LOCKED_MODEL="$(hermes_lock_read_model)"
MODEL="$(hermes_lock_assert "${OLLAMA_MODEL:-$LOCKED_MODEL}")"
CONTEXT_LENGTH="${OLLAMA_CONTEXT_LENGTH:-8192}"
HERMES_HOME="${HERMES_HOME:-${HOME}/.hermes}"
CONFIG="${HERMES_HOME}/config.yaml"
ENV_FILE="${HERMES_HOME}/.env"
PULL="${PULL:-0}"
ENSURE_MODEL="${ENSURE_MODEL:-1}"

if ! command -v curl >/dev/null 2>&1; then
  echo "error: missing required command: curl" >&2
  exit 1
fi

if ! curl -fsS "http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/tags" >/dev/null 2>&1; then
  echo "Ollama is not reachable at http://${OLLAMA_HOST}:${OLLAMA_PORT}" >&2
  echo "Start it with: ollama serve   (or ./scripts/lock-hermes.sh)" >&2
  exit 1
fi

if [[ "${ENSURE_MODEL}" == "1" ]]; then
  if ! ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -Eq "^${MODEL}(:|$)"; then
    echo "==> Locked model '${MODEL}' missing — running setup-hermes.sh"
    "${ROOT}/scripts/setup-hermes.sh"
  fi
fi

if [[ "${PULL}" == "1" ]] && command -v ollama >/dev/null 2>&1; then
  if ! ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -Eq "^${MODEL}(:|$)"; then
    echo "Pulling ${MODEL}..."
    ollama pull "${MODEL}"
  fi
fi

mkdir -p "${HERMES_HOME}"

# Generous timeout for CPU-only local models (Hermes Agent docs).
if [[ ! -f "${ENV_FILE}" ]] || ! grep -q '^HERMES_API_TIMEOUT=' "${ENV_FILE}" 2>/dev/null; then
  {
    echo "# Auto-added by hermes-use-ollama.sh for local Ollama"
    echo "HERMES_API_TIMEOUT=${HERMES_API_TIMEOUT:-1800}"
  } >> "${ENV_FILE}"
fi

wrote_via=""
if command -v hermes >/dev/null 2>&1; then
  if hermes config set model.provider custom \
    && hermes config set model.base_url "${BASE_URL}" \
    && hermes config set model.default "${MODEL}"; then
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
import re
from pathlib import Path

path = Path(os.environ["CONFIG"])
base_url = os.environ["BASE_URL"]
model = os.environ["MODEL"]
ctx = int(os.environ["CONTEXT_LENGTH"])

try:
    import yaml  # type: ignore
except ImportError:
    yaml = None

block = (
    "model:\n"
    "  provider: custom\n"
    f"  default: {model}\n"
    f"  base_url: {base_url}\n"
    f"  context_length: {ctx}\n"
    "  api_mode: chat_completions\n"
)

if path.exists():
    text = path.read_text(encoding="utf-8")
else:
    text = ""

if yaml is not None:
    data = yaml.safe_load(text) if text.strip() else {}
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
    path.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
else:
    # Minimal fallback: replace/append model block without PyYAML.
    body = re.sub(r"(?m)^model:\n(?:[ \t]+.+\n)*", "", text)
    rest = body.lstrip("\n")
    path.write_text(block + ("\n" + rest if rest else ""), encoding="utf-8")

print(path)
PY
  wrote_via="config.yaml edit"
fi

# Record Hermes Agent pin in the lock file (local path; free).
python3 - "${HERMES_LOCK_FILE}" "${BASE_URL}" "${MODEL}" "${CONTEXT_LENGTH}" <<'PY'
import json, sys
path, base, model, ctx = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
with open(path, encoding="utf-8") as f:
    data = json.load(f)
data.setdefault("hermes_agent", {})
data["hermes_agent"].update({
    "provider": "custom",
    "base_url": base,
    "default": model,
    "context_length": ctx,
    "api_mode": "chat_completions",
    "cost": "free",
    "note": "Local Ollama via Custom Endpoint — never provider ollama-cloud for free local use.",
})
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

cat <<EOF

Changed Hermes Agent to free local Ollama (${wrote_via}):

  provider:       custom
  base_url:       ${BASE_URL}
  default model:  ${MODEL}  (locked free)
  context_length: ${CONTEXT_LENGTH}

Config: ${CONFIG}
Env:    ${ENV_FILE}  (HERMES_API_TIMEOUT for slow CPU models)

Next:
  1. Keep Ollama running:  ollama serve
  2. Install Hermes Agent if needed:
       curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
       # or:  ollama launch hermes
  3. Restart Hermes / run: hermes
  4. Confirm model ${MODEL} (provider custom, not ollama-cloud)

Overrides (must stay on the locked free model unless you unlock):
  OLLAMA_CONTEXT_LENGTH=32768 ./scripts/hermes-use-ollama.sh

Note: provider must be "custom" for local Ollama — not "ollama"
      ("ollama" / "ollama-cloud" is the hosted Ollama Cloud API).
EOF
