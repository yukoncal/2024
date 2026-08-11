#!/usr/bin/env bash
# Install Nous Hermes Agent CLI (non-interactive) and pin free local Ollama.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Installing Hermes Agent CLI"
curl -fsSL https://hermes-agent.nousresearch.com/install.sh \
  | bash -s -- --skip-setup --non-interactive --skip-browser

export PATH="${HOME}/.local/bin:${PATH}"

if ! command -v hermes >/dev/null 2>&1 && [[ ! -x "${HOME}/.local/bin/hermes" ]]; then
  echo "error: hermes binary not found after install" >&2
  exit 1
fi

echo "==> Pinning Hermes Agent to locked free local Ollama"
"${ROOT}/scripts/hermes-use-ollama.sh"

echo
echo "Hermes CLI ready: $(command -v hermes 2>/dev/null || echo "${HOME}/.local/bin/hermes")"
echo "Reload shell if needed:  source ~/.bashrc"
echo "Chat:  hermes"
