# Open Hermes using a free model you already downloaded in Ollama.
# Prefers a local openhermes (or MODEL_SOURCE). Only pulls if nothing suitable is present.
# Creates a short Cursor-safe alias: hermes
# Run in PowerShell:  .\scripts\setup-hermes.ps1
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$LockFile = Join-Path $Root "config\hermes.lock.json"
$lock = Get-Content $LockFile -Raw | ConvertFrom-Json
$ModelAlias = if ($lock.model) { $lock.model } else { "hermes" }
if ($env:MODEL_ALIAS) { $ModelAlias = $env:MODEL_ALIAS }
$PreferredSource = if ($env:MODEL_SOURCE) { $env:MODEL_SOURCE } else { "" }
$Modelfile = Join-Path $Root "ollama\Modelfile.hermes"
$Candidates = @("openhermes", "openhermes:latest", "llama3.1:8b", "mistral", "phi3")

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

function Find-LocalModel([string]$Want, [string[]]$LocalModels) {
    foreach ($name in $LocalModels) {
        $base = ($name -split ':')[0]
        if ($name -eq $Want -or $name -eq "${Want}:latest" -or $base -eq $Want) {
            return $name
        }
    }
    return $null
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
$ModelSource = $null

if ($PreferredSource) {
    $hit = Find-LocalModel $PreferredSource $localModels
    if ($hit) { $ModelSource = $hit } else { $ModelSource = $PreferredSource }
} else {
    foreach ($candidate in $Candidates) {
        $hit = Find-LocalModel $candidate $localModels
        if ($hit) { $ModelSource = $hit; break }
    }
    if (-not $ModelSource) { $ModelSource = "openhermes" }
}

$localHit = Find-LocalModel $ModelSource $localModels
if ($localHit) {
    $ModelSource = $localHit
    Write-Host "Using already-downloaded free model: $ModelSource"
} else {
    Write-Host "No matching local free model found. Pulling $ModelSource..."
    ollama pull $ModelSource
    $localModels = @(Get-LocalModels)
    $localHit = Find-LocalModel $ModelSource $localModels
    if ($localHit) { $ModelSource = $localHit }
}

$tmp = [System.IO.Path]::GetTempFileName()
try {
    (Get-Content $Modelfile) -replace '^FROM .*', "FROM $ModelSource" | Set-Content -Path $tmp -Encoding utf8
    Write-Host "Creating Cursor-safe alias '$ModelAlias' from $ModelSource..."
    ollama create $ModelAlias -f $tmp
} finally {
    Remove-Item -Force $tmp -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Installed models:"
ollama list

Write-Host @"

Hermes is ready (backed by free model: $ModelSource).

Open a local chat:
  .\scripts\open-hermes.ps1

Next steps for Cursor:
  1. Expose Ollama over public HTTPS (Cursor cannot call localhost):
       .\scripts\expose-for-cursor.ps1
  2. In Cursor: Settings → Models
       - OpenAI API Key: ollama
       - Override OpenAI Base URL: https://YOUR-TUNNEL/v1
       - Add model: $ModelAlias
  3. Pick $ModelAlias in the chat model picker (turn Auto off)

Local sanity check:
  .\scripts\verify-hermes.ps1

Override the source model anytime:
  `$env:MODEL_SOURCE='llama3.1:8b'; .\scripts\setup-hermes.ps1
"@
