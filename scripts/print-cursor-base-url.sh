#!/usr/bin/env bash
# Print the Override OpenAI Base URL for Cursor when ngrok basic auth (TUNNEL_AUTH) is in use.
# Requires: ngrok running (e.g. ./scripts/expose-for-cursor.sh) and TUNNEL_AUTH=user:pass
set -euo pipefail

if [[ -z "${TUNNEL_AUTH:-}" || "${TUNNEL_AUTH}" != *:* ]]; then
  echo "Set TUNNEL_AUTH first, e.g. export TUNNEL_AUTH='myuser:my-password'" >&2
  exit 1
fi

if ! curl -fsS "http://127.0.0.1:4040/api/tunnels" >/dev/null 2>&1; then
  echo "ngrok does not appear to be running on this machine." >&2
  echo "In another window, run: ./scripts/expose-for-cursor.sh" >&2
  exit 1
fi

TUNNEL_AUTH="$TUNNEL_AUTH" python3 <<'PY'
import json, os, urllib.parse, urllib.request

auth = os.environ["TUNNEL_AUTH"]
user, _, password = auth.partition(":")
if not user or not password:
    raise SystemExit("TUNNEL_AUTH must be user:password")

raw = urllib.request.urlopen("http://127.0.0.1:4040/api/tunnels", timeout=3).read()
data = json.loads(raw)
public = None
for t in data.get("tunnels", []):
    url = t.get("public_url", "")
    if url.startswith("https://"):
        public = url.rstrip("/")
        break
if not public:
    raise SystemExit("No HTTPS ngrok URL found. Wait for ngrok to show Forwarding https://…")

host = public.replace("https://", "", 1)
u = urllib.parse.quote(user, safe="")
p = urllib.parse.quote(password, safe="")
base = f"https://{u}:{p}@{host}/v1"
print()
print("Paste this into Cursor → Settings → Models → Override OpenAI Base URL:")
print()
print(base)
print()
print("(Keep this private. Do not share screenshots of this line.)")
PY
