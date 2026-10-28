#!/usr/bin/env bash
# Expose local Ollama as public HTTPS so Cursor's backend can reach it.
# Requires TUNNEL_AUTH (user:pass) so ngrok can enforce HTTP basic auth on the tunnel.
set -euo pipefail

PORT="${OLLAMA_PORT:-11434}"
TARGET="http://127.0.0.1:${PORT}"

if [[ -z "${TUNNEL_AUTH:-}" || "${TUNNEL_AUTH}" != *:* ]]; then
  echo "TUNNEL_AUTH must be set to user:password before exposing Ollama on the public internet." >&2
  echo "Example: export TUNNEL_AUTH='myuser:my-strong-password'" >&2
  echo "Then run this script again. ngrok will require that login on the tunnel URL." >&2
  exit 1
fi

if ! curl -fsS "${TARGET}/api/tags" >/dev/null 2>&1; then
  echo "Ollama is not reachable at ${TARGET}" >&2
  echo "Run ./scripts/setup-qwen.sh first (or: ollama serve)." >&2
  exit 1
fi

cat <<'EOF'
Cursor routes chat through its cloud backend, so http://localhost:11434 will NOT work
as the OpenAI Base URL override. You need a public HTTPS URL that ends in /v1.

EOF

if command -v ngrok >/dev/null 2>&1; then
  echo "Using ngrok with HTTP basic auth (TUNNEL_AUTH)..."
  echo
  echo "Leave this window open. In a SECOND terminal (same TUNNEL_AUTH), run:"
  echo "  ./scripts/print-cursor-base-url.sh"
  echo "That prints the full Base URL to paste into Cursor (includes your tunnel login)."
  echo "Step-by-step help: EXPOSE_OLLAMA_BEGINNER.md"
  echo
  exec ngrok http "${PORT}" --basic-auth="${TUNNEL_AUTH}"
fi

cat <<'EOF'
ngrok is not installed (required for an authenticated tunnel).

Quick Cloudflare trycloudflare tunnels have no built-in login — this script refuses to
start an unauthenticated public Ollama endpoint.

Install ngrok:
  https://ngrok.com/download
Then:
  export TUNNEL_AUTH='user:password'
  ngrok http 11434 --basic-auth="$TUNNEL_AUTH"

After the tunnel is up, in Cursor Settings → Models:
  OpenAI API Key:            ollama
  Override OpenAI Base URL:  https://YOUR-TUNNEL-HOST/v1
  Add custom model:          qwen25
  (Do not use qwen2.5-coder:latest — Cursor rejects ":" / ".")
EOF
exit 1
