# Expose local Ollama as public HTTPS so Cursor's backend can reach it.
# Prefer Cloudflare Tunnel; fall back to ngrok if installed.
# Run in PowerShell:  .\scripts\expose-for-cursor.ps1
$ErrorActionPreference = "Stop"

$Port   = if ($env:OLLAMA_PORT) { $env:OLLAMA_PORT } else { "11434" }
$Target = "http://127.0.0.1:$Port"

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

$cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
if ($cloudflared) {
    Write-Host "Using Cloudflare Tunnel (cloudflared)..."
    Write-Host "Copy the https://….trycloudflare.com URL it prints, then set Cursor Base URL to:"
    Write-Host "  https://YOUR-SUBDOMAIN.trycloudflare.com/v1"
    Write-Host ""
    & cloudflared tunnel --url $Target
    exit $LASTEXITCODE
}

$ngrok = Get-Command ngrok -ErrorAction SilentlyContinue
if ($ngrok) {
    Write-Host "Using ngrok..."
    Write-Host "Copy the https://….ngrok-free.app URL it prints, then set Cursor Base URL to:"
    Write-Host "  https://YOUR-SUBDOMAIN.ngrok-free.app/v1"
    Write-Host ""
    & ngrok http $Port
    exit $LASTEXITCODE
}

Write-Host @"
Neither cloudflared nor ngrok is installed.

Install one of:
  Cloudflare Tunnel (recommended):
    winget install --id Cloudflare.cloudflared
    Then:  cloudflared tunnel --url http://127.0.0.1:11434

  ngrok:
    https://ngrok.com/download
    Then:  ngrok http 11434

After the tunnel is up, in Cursor Settings → Models:
  OpenAI API Key:            ollama
  Override OpenAI Base URL:  https://YOUR-TUNNEL-HOST/v1
  Add custom model:          qwen359b
"@
exit 1
