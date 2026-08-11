# Expose local Ollama as public HTTPS so Cursor's backend can reach the locked free Hermes model.
# Prefer Cloudflare Tunnel; fall back to ngrok if installed.
# Run in PowerShell:  .\scripts\expose-for-cursor.ps1
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$LockFile = Join-Path $Root "config\hermes.lock.json"
$Port = if ($env:OLLAMA_PORT) { $env:OLLAMA_PORT } else { "11434" }
$Target = "http://127.0.0.1:$Port"

$lock = Get-Content $LockFile -Raw | ConvertFrom-Json
$LockedModel = if ($lock.model) { $lock.model } else { "hermes" }

try {
    Invoke-RestMethod -Uri "$Target/api/tags" -TimeoutSec 2 | Out-Null
} catch {
    Write-Error "Ollama is not reachable at $Target. Run .\scripts\lock-hermes.ps1 first."
    exit 1
}

Write-Host @"
Cursor routes chat through its cloud backend, so http://localhost:11434 will NOT work
as the OpenAI Base URL override. You need a public HTTPS URL that ends in /v1.

Locked free model to add in Cursor: $LockedModel
(Do not use Grok 4.5 High Fast — that is paid cloud usage.)

"@

$cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
if ($cloudflared) {
    Write-Host "Using Cloudflare Tunnel (cloudflared) — recommended..."
    Write-Host "Copy the https://….trycloudflare.com URL it prints, then set Cursor Base URL to:"
    Write-Host "  https://YOUR-SUBDOMAIN.trycloudflare.com/v1"
    Write-Host "Add model: $LockedModel"
    Write-Host ""
    & cloudflared tunnel --url $Target
    exit $LASTEXITCODE
}

$ngrok = Get-Command ngrok -ErrorAction SilentlyContinue
if ($ngrok) {
    Write-Host "Using ngrok..."
    Write-Host "WARNING: free ngrok may block Cursor (missing ngrok-skip-browser-warning)."
    Write-Host "Prefer cloudflared. If you continue, set Cursor Base URL to:"
    Write-Host "  https://YOUR-SUBDOMAIN.ngrok-free.app/v1"
    Write-Host "Add model: $LockedModel"
    Write-Host ""
    & ngrok http $Port
    exit $LASTEXITCODE
}

Write-Host @"
Neither cloudflared nor ngrok is installed.

Install Cloudflare Tunnel (recommended):
  winget install --id Cloudflare.cloudflared
  Then:  .\scripts\expose-for-cursor.ps1

After the tunnel is up, in Cursor Settings → Models:
  OpenAI API Key:            ollama
  Override OpenAI Base URL:  https://YOUR-TUNNEL-HOST/v1
  Add custom model:          $LockedModel
  Chat picker:               Auto OFF → $LockedModel
"@
exit 1
