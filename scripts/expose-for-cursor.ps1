# Expose local Ollama as public HTTPS so Cursor's backend can reach it.
# Requires TUNNEL_AUTH (user:pass) so ngrok can enforce HTTP basic auth on the tunnel.
# Run in PowerShell:  .\scripts\expose-for-cursor.ps1
$ErrorActionPreference = "Stop"

$Port   = if ($env:OLLAMA_PORT) { $env:OLLAMA_PORT } else { "11434" }
$Target = "http://127.0.0.1:$Port"

if (-not $env:TUNNEL_AUTH -or $env:TUNNEL_AUTH -notmatch ':') {
    Write-Error @"
TUNNEL_AUTH must be set to user:password before exposing Ollama on the public internet.
Example: `$env:TUNNEL_AUTH = 'myuser:my-strong-password'
Then run this script again. ngrok will require that login on the tunnel URL.
"@
    exit 1
}

try {
    Invoke-RestMethod -Uri "$Target/api/tags" -TimeoutSec 2 | Out-Null
} catch {
    Write-Error "Ollama is not reachable at $Target. Run .\scripts\setup-qwen.ps1 first."
    exit 1
}

Write-Host @"
Cursor routes chat through its cloud backend, so http://localhost:11434 will NOT work
as the OpenAI Base URL override. You need a public HTTPS URL that ends in /v1.

"@

$ngrok = Get-Command ngrok -ErrorAction SilentlyContinue
if ($ngrok) {
    Write-Host "Using ngrok with HTTP basic auth (TUNNEL_AUTH)..."
    Write-Host ""
    Write-Host "Leave this window open. In a SECOND PowerShell window (same TUNNEL_AUTH), run:"
    Write-Host "  .\scripts\print-cursor-base-url.ps1"
    Write-Host "That prints the full Base URL to paste into Cursor (includes your tunnel login)."
    Write-Host "Step-by-step help: EXPOSE_OLLAMA_BEGINNER.md"
    Write-Host ""
    & ngrok http $Port --basic-auth=$env:TUNNEL_AUTH
    exit $LASTEXITCODE
}

Write-Host @"
ngrok is not installed (required for an authenticated tunnel).

Quick Cloudflare trycloudflare tunnels have no built-in login — this script refuses to
start an unauthenticated public Ollama endpoint.

Install ngrok:
  https://ngrok.com/download
Then:
  `$env:TUNNEL_AUTH = 'user:password'
  ngrok http 11434 --basic-auth=`$env:TUNNEL_AUTH

After the tunnel is up, in Cursor Settings → Models:
  OpenAI API Key:            ollama
  Override OpenAI Base URL:  https://YOUR-TUNNEL-HOST/v1
  Add custom model:          qwen25
  (Do not use qwen2.5-coder:latest — Cursor rejects ":" / ".")
"@
exit 1
