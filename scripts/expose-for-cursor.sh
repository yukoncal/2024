#!/usr/bin/env bash
# Expose local Ollama as public HTTPS so Cursor's backend can reach the locked free Hermes model.
# Prefer Cloudflare Tunnel; fall back to ngrok if installed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/hermes-lock.sh
source "${ROOT}/scripts/lib/hermes-lock.sh"

PORT="${OLLAMA_PORT:-11434}"
TARGET="http://127.0.0.1:${PORT}"
LOCKED_MODEL="$(hermes_lock_read_model)"

if ! curl -fsS "${TARGET}/api/tags" >/dev/null 2>&1; then
  echo "Ollama is not reachable at ${TARGET}" >&2
  echo "Run ./scripts/lock-hermes.sh first (or: ollama serve)." >&2
  exit 1
fi

cat <<EOF
Cursor routes chat through its cloud backend, so http://localhost:11434 will NOT work
as the OpenAI Base URL override. You need a public HTTPS URL that ends in /v1.

Locked free model to add in Cursor: ${LOCKED_MODEL}
(Do not use Grok 4.5 High Fast — that is paid cloud usage.)

EOF

write_lock_from_log() {
  local log_file="$1"
  local url
  url="$(grep -Eo 'https://[a-zA-Z0-9.-]+\.(trycloudflare\.com|ngrok-free\.(app|dev)|ngrok\.io)' "${log_file}" | head -n1 || true)"
  if [[ -n "${url}" ]]; then
    hermes_lock_write_tunnel "${url}" >/dev/null
    echo
    echo "Saved tunnel into config/hermes.lock.json"
    echo "Cursor Override OpenAI Base URL: ${url}/v1"
    echo "Add custom model: ${LOCKED_MODEL}  (Auto OFF)"
  fi
}

if command -v cloudflared >/dev/null 2>&1; then
  echo "Using Cloudflare Tunnel (cloudflared) — recommended..."
  echo "Copy the https://….trycloudflare.com URL it prints, then set Cursor Base URL to:"
  echo "  https://YOUR-SUBDOMAIN.trycloudflare.com/v1"
  echo "Add model: ${LOCKED_MODEL}"
  echo
  log="$(mktemp)"
  # shellcheck disable=SC2064
  trap 'write_lock_from_log "${log}"; rm -f "${log}"' EXIT
  cloudflared tunnel --url "${TARGET}" 2>&1 | tee "${log}"
  exit "${PIPESTATUS[0]}"
fi

if command -v ngrok >/dev/null 2>&1; then
  echo "Using ngrok..."
  echo "WARNING: free ngrok may block Cursor (missing ngrok-skip-browser-warning)."
  echo "Prefer cloudflared. If you continue, set Cursor Base URL to:"
  echo "  https://YOUR-SUBDOMAIN.ngrok-free.app/v1"
  echo "Add model: ${LOCKED_MODEL}"
  echo
  exec ngrok http "${PORT}"
fi

cat <<EOF
Neither cloudflared nor ngrok is installed.

Install Cloudflare Tunnel (recommended):
  macOS:  brew install cloudflared
  Linux:  https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
  Then:   ./scripts/expose-for-cursor.sh

After the tunnel is up, in Cursor Settings → Models:
  OpenAI API Key:            ollama
  Override OpenAI Base URL:  https://YOUR-TUNNEL-HOST/v1
  Add custom model:          ${LOCKED_MODEL}
  Chat picker:               Auto OFF → ${LOCKED_MODEL}
EOF
exit 1
