# Pull OpenHermes into Ollama so it's ready to use from Cursor.
# OpenHermes has no "." in its name, so (unlike Qwen3.5) no Cursor-safe alias is needed.
# Run in PowerShell:  .\scripts\setup-hermes.ps1
$ErrorActionPreference = "Stop"

$ModelSource = if ($env:MODEL_SOURCE) { $env:MODEL_SOURCE } else { "openhermes" }

if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
    Write-Host @"
Ollama is not installed.

Install it from: https://ollama.com/download
Then re-run: .\scripts\setup-hermes.ps1
"@
    exit 1
}

function Test-Ollama {
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 2 | Out-Null
        return $true
    } catch {
        return $false
    }
}

if (-not (Test-Ollama)) {
    Write-Host "Starting Ollama..."
    Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        if (Test-Ollama) { break }
    }
}

if (-not (Test-Ollama)) {
    Write-Error "Could not reach Ollama at http://127.0.0.1:11434. Start it from the Start menu, then retry."
    exit 1
}

Write-Host "Pulling $ModelSource (about 4.1GB)..."
ollama pull $ModelSource

Write-Host ""
Write-Host "Installed models:"
ollama list

Write-Host @"

Next steps for Cursor:
  1. Expose Ollama over public HTTPS (Cursor cannot call localhost):
       .\scripts\expose-for-cursor.ps1
  2. In Cursor: Settings → Models
       - OpenAI API Key: ollama
       - Override OpenAI Base URL: https://YOUR-TUNNEL/v1
       - Add model: $ModelSource
  3. Pick $ModelSource in the chat model picker (turn Auto off)

Local sanity check:
  .\scripts\verify-hermes.ps1
"@
