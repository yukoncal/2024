#!/usr/bin/env bash
# Install Nous Hermes Agent CLI (non-interactive) and pin free local Ollama.
# Usage:  ./scripts/install-hermes-cli.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"

# Friendly tip if someone typed the double-dot typo in docs/chat.
if [[ "${BASH_SOURCE[0]}" == *'install-hermes-cli..sh' ]]; then
  echo "note: correct script name is install-hermes-cli.sh (one dot before sh)"
fi

echo "==> Checking Ollama (needed to pin free local hermes)"
if ! command -v ollama >/dev/null 2>&1; then
  echo "error: ollama is not installed. Install from https://ollama.com then re-run." >&2
  exit 1
fi

if ! curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
  echo "Starting ollama serve..."
  if command -v systemctl >/dev/null 2>&1 && systemctl is-enabled ollama >/dev/null 2>&1; then
    sudo systemctl start ollama || true
  fi
  if ! curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
    nohup ollama serve >/tmp/ollama-serve.log 2>&1 &
    for _ in $(seq 1 30); do
      curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1 && break
      sleep 1
    done
  fi
fi

if ! curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
  echo "error: Ollama API not reachable at http://127.0.0.1:11434" >&2
  echo "       Start it with: ollama serve" >&2
  exit 1
fi

# Ensure locked free model alias exists before pinning Hermes Agent.
if ! ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -Eq '^hermes(:|$)'; then
  echo "==> Locked model 'hermes' missing — running lock-hermes.sh"
  "${ROOT}/scripts/lock-hermes.sh"
fi

if command -v hermes >/dev/null 2>&1 || [[ -x "${HOME}/.local/bin/hermes" ]]; then
  echo "==> Hermes CLI already present: $(command -v hermes 2>/dev/null || echo "${HOME}/.local/bin/hermes")"
  echo "==> Refreshing install (idempotent)..."
else
  echo "==> Installing Hermes Agent CLI"
fi

curl -fsSL https://hermes-agent.nousresearch.com/install.sh \
  | bash -s -- --skip-setup --non-interactive --skip-browser

export PATH="${HOME}/.local/bin:${PATH}"

HERMES_BIN="$(command -v hermes 2>/dev/null || true)"
if [[ -z "${HERMES_BIN}" && -x "${HOME}/.local/bin/hermes" ]]; then
  HERMES_BIN="${HOME}/.local/bin/hermes"
fi
if [[ -z "${HERMES_BIN}" ]]; then
  echo "error: hermes binary not found after install" >&2
  echo "       Expected: ~/.local/bin/hermes — try: source ~/.bashrc" >&2
  exit 1
fi

echo "==> Pinning Hermes Agent to locked free local Ollama"
"${ROOT}/scripts/hermes-use-ollama.sh"

echo
echo "============================================================"
echo "Hermes CLI ready"
echo "  binary:  ${HERMES_BIN}"
echo "  version: $(${HERMES_BIN} --version 2>/dev/null | head -n1 || echo unknown)"
echo "  config:  ${HOME}/.hermes/config.yaml  (provider=custom, model=hermes)"
echo
echo "Reload shell if 'hermes' is not found:"
echo "  source ~/.bashrc"
echo "Chat:"
echo "  hermes"
echo "Doctor:"
echo "  ./scripts/hermes-doctor.sh --fix"
echo "============================================================"
