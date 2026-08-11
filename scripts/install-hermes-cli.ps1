# Install Nous Hermes Agent CLI (non-interactive) and pin free local Ollama.
# Usage:  .\scripts\install-hermes-cli.ps1
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$localBin = Join-Path $HOME ".local\bin"
if (Test-Path $localBin) { $env:Path = "$localBin;$env:Path" }

Write-Host "==> Checking Ollama (needed to pin free local hermes)"
if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
    Write-Error "ollama is not installed. Install from https://ollama.com then re-run."
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
    Write-Host "Starting ollama serve..."
    Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        if (Test-Ollama) { break }
    }
}
if (-not (Test-Ollama)) {
    Write-Error "Ollama API not reachable at http://127.0.0.1:11434. Start it with: ollama serve"
}

$haveHermesModel = $false
$listed = & ollama list 2>$null
foreach ($line in $listed) {
    if ($line -match '^\s*hermes(:|\s|$)') { $haveHermesModel = $true; break }
}
if (-not $haveHermesModel) {
    Write-Host "==> Locked model 'hermes' missing — running lock-hermes.ps1"
    & "$Root\scripts\lock-hermes.ps1"
}

$hermesCmd = Get-Command hermes -ErrorAction SilentlyContinue
if ($hermesCmd) {
    Write-Host "==> Hermes CLI already present: $($hermesCmd.Source)"
    Write-Host "==> Refreshing install (idempotent)..."
} else {
    Write-Host "==> Installing Hermes Agent CLI"
}

$installer = Join-Path $env:TEMP "hermes-install.sh"
Invoke-WebRequest -Uri "https://hermes-agent.nousresearch.com/install.sh" -OutFile $installer
if (Get-Command bash -ErrorAction SilentlyContinue) {
    & bash $installer --skip-setup --non-interactive --skip-browser
} elseif (Get-Command wsl -ErrorAction SilentlyContinue) {
    wsl bash -c "curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup --non-interactive --skip-browser"
} else {
    Write-Host "Official installer is a bash script. On Windows prefer:"
    Write-Host "  ollama launch hermes"
    Write-Host "Or install from: https://hermes-agent.nousresearch.com/"
    Write-Host "Then run: .\scripts\hermes-use-ollama.ps1"
    exit 1
}

$env:Path = "$(Join-Path $HOME '.local\bin');$env:Path"
$hermesCmd = Get-Command hermes -ErrorAction SilentlyContinue
if (-not $hermesCmd) {
    Write-Error "hermes binary not found after install. Try a new shell, or: ollama launch hermes"
}

Write-Host "==> Pinning Hermes Agent to locked free local Ollama"
& "$Root\scripts\hermes-use-ollama.ps1"

Write-Host ""
Write-Host "============================================================"
Write-Host "Hermes CLI ready"
Write-Host "  binary:  $($hermesCmd.Source)"
Write-Host "  config:  $(Join-Path $HOME '.hermes\config.yaml')  (provider=custom, model=hermes)"
Write-Host "Chat:     hermes"
Write-Host "Doctor:   .\scripts\hermes-doctor.ps1 -Fix"
Write-Host "============================================================"
