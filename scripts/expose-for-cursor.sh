#!/usr/bin/env bash
# Expose local Ollama as public HTTPS so Cursor's backend can reach it.
# Prefer Cloudflare Tunnel; fall back to ngrok if installed.
set -euo pipefail

PORT="${OLLAMA_PORT:-11434}"
TARGET="http://127.0.0.1:${PORT}"

if ! curl -fsS "${TARGET}/api/tags" >/dev/null 2>&1; then
  echo "Ollama is not reachable at ${TARGET}" >&2
  echo "Run ./scripts/setup-qwen.sh first (or: ollama serve)." >&2
  exit 1
fi

cat <<'EOF'
Cursor routes chat through its cloud backend, so http://localhost:11434 will NOT work
as the OpenAI Base URL override. You need a public HTTPS URL that ends in /v1.

EOF

if command -v cloudflared >/dev/null 2>&1; then
  echo "Using Cloudflare Tunnel (cloudflared)..."
  echo "Copy the https://….trycloudflare.com URL it prints, then set Cursor Base URL to:"
  echo "  https://YOUR-SUBDOMAIN.trycloudflare.com/v1"
  echo
  exec cloudflared tunnel --url "${TARGET}"
fi

if command -v ngrok >/dev/null 2>&1; then
  echo "Using ngrok..."
  echo "Copy the https://….ngrok-free.app URL it prints, then set Cursor Base URL to:"
  echo "  https://YOUR-SUBDOMAIN.ngrok-free.app/v1"
  echo
  exec ngrok http "${PORT}"
fi

cat <<'EOF'
Neither cloudflared nor ngrok is installed.

Install one of:
  Cloudflare Tunnel:
    macOS:  brew install cloudflared
    Linux:  https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
    Then:   cloudflared tunnel --url http://127.0.0.1:11434

  ngrok:
    https://ngrok.com/download
    Then:   ngrok http 11434

After the tunnel is up, in Cursor Settings → Models:
  OpenAI API Key:            ollama
  Override OpenAI Base URL:  https://YOUR-TUNNEL-HOST/v1
  Add custom model:          qwen359b
EOF
exit 1
