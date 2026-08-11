# Open an interactive Hermes chat using the locked free local Ollama model.
# Run in PowerShell:  .\scripts\open-hermes.ps1
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$LockFile = Join-Path $Root "config\hermes.lock.json"
$lock = Get-Content $LockFile -Raw | ConvertFrom-Json
$Model = if ($lock.model) { $lock.model } else { "hermes" }

if ($env:MODEL -and $env:MODEL -ne $Model -and $env:MODEL -ne "${Model}:latest") {
    Write-Error "model '$($env:MODEL)' is blocked. Hermes is locked to free local model '$Model'."
    exit 1
}

if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
    Write-Error "Ollama is not installed. Install from https://ollama.com then re-run."
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

function Get-LocalModels {
    $lines = ollama list 2>$null
    $names = @()
    foreach ($line in $lines) {
        if ($line -match '^\s*NAME\b') { continue }
        $parts = ($line -split '\s+') | Where-Object { $_ -ne "" }
        if ($parts.Count -ge 1) { $names += $parts[0] }
    }
    return $names
}

function Test-HasModel([string]$Want, [string[]]$LocalModels) {
    foreach ($name in $LocalModels) {
        $base = ($name -split ':')[0]
        if ($name -eq $Want -or $name -eq "${Want}:latest" -or $base -eq $Want) {
            return $true
        }
    }
    return $false
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

$localModels = @(Get-LocalModels)
if (-not (Test-HasModel $Model $localModels)) {
    Write-Error "Locked model '$Model' not found locally. Run: $($Root)\scripts\lock-hermes.ps1"
    exit 1
}

Write-Host "Opening locked free Hermes model: $Model"
Write-Host "(Ctrl+D or /bye to exit) — not Grok; `$0 local Ollama"
Write-Host ""
ollama run $Model
