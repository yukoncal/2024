# Point Hermes Agent / Hermes Desktop at local Ollama (Custom Endpoint).
# Local Ollama uses provider "custom" + OpenAI-compatible /v1 base URL.
# Defaults to the locked free model from config/hermes.lock.json (usually hermes).
param(
    [string]$OllamaHost = $(if ($env:OLLAMA_HOST) { $env:OLLAMA_HOST } else { "127.0.0.1" }),
    [int]$OllamaPort = $(if ($env:OLLAMA_PORT) { [int]$env:OLLAMA_PORT } else { 11434 }),
    [string]$Model = $(if ($env:OLLAMA_MODEL) { $env:OLLAMA_MODEL } else { "" }),
    [int]$ContextLength = $(if ($env:OLLAMA_CONTEXT_LENGTH) { [int]$env:OLLAMA_CONTEXT_LENGTH } else { 8192 }),
    [string]$BaseUrl = $(if ($env:OLLAMA_BASE_URL) { $env:OLLAMA_BASE_URL } else { "" }),
    [switch]$NoPull,
    [switch]$SkipEnsureModel
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$LockFile = Join-Path $Root "config\hermes.lock.json"

$lockedModel = "hermes"
if (Test-Path $LockFile) {
    $lock = Get-Content $LockFile -Raw | ConvertFrom-Json
    if ($lock.model) { $lockedModel = [string]$lock.model }
}

if (-not $Model) { $Model = $lockedModel }
if ($Model -ne $lockedModel -and $Model -ne "$lockedModel`:latest") {
    Write-Error "model '$Model' is blocked. Hermes is locked to free local model '$lockedModel'."
}

if (-not $BaseUrl) {
    $BaseUrl = "http://${OllamaHost}:${OllamaPort}/v1"
}

$tagsUrl = "http://${OllamaHost}:${OllamaPort}/api/tags"
try {
    Invoke-RestMethod -Uri $tagsUrl -TimeoutSec 5 | Out-Null
} catch {
    Write-Error "Ollama is not reachable at $tagsUrl. Start it with: ollama serve (or .\scripts\lock-hermes.ps1)"
}

function Test-HasModel([string]$want) {
    $listed = & ollama list 2>$null
    foreach ($line in $listed) {
        if ($line -match "^\s*$([regex]::Escape($want))(:|\s|$)") { return $true }
    }
    return $false
}

if (-not $SkipEnsureModel) {
    if (-not (Test-HasModel $Model)) {
        Write-Host "==> Locked model '$Model' missing — running setup-hermes.ps1"
        & "$Root\scripts\setup-hermes.ps1"
    }
}

if (-not $NoPull -and (Get-Command ollama -ErrorAction SilentlyContinue)) {
    if (-not (Test-HasModel $Model)) {
        Write-Host "Pulling $Model..."
        & ollama pull $Model
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
}

$hermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME } else { Join-Path $HOME ".hermes" }
$configPath = Join-Path $hermesHome "config.yaml"
$envPath = Join-Path $hermesHome ".env"
New-Item -ItemType Directory -Force -Path $hermesHome | Out-Null

if (-not (Test-Path $envPath) -or -not (Select-String -Path $envPath -Pattern '^HERMES_API_TIMEOUT=' -Quiet)) {
    $timeout = if ($env:HERMES_API_TIMEOUT) { $env:HERMES_API_TIMEOUT } else { "1800" }
    Add-Content -Path $envPath -Value "# Auto-added by hermes-use-ollama.ps1 for local Ollama"
    Add-Content -Path $envPath -Value "HERMES_API_TIMEOUT=$timeout"
}

$wroteVia = $null
if (Get-Command hermes -ErrorAction SilentlyContinue) {
    & hermes config set model.provider custom
    if ($LASTEXITCODE -eq 0) {
        & hermes config set model.base_url $BaseUrl
        & hermes config set model.default $Model
        & hermes config set model.context_length "$ContextLength" 2>$null
        & hermes config set model.api_mode chat_completions 2>$null
        $wroteVia = "hermes config set"
    }
}

if (-not $wroteVia) {
    $block = @"
model:
  provider: custom
  default: $Model
  base_url: $BaseUrl
  context_length: $ContextLength
  api_mode: chat_completions
"@
    if (Test-Path $configPath) {
        $existing = Get-Content -Raw $configPath
        $stripped = [regex]::Replace($existing, '(?m)^model:\r?\n(?:[ \t]+.+\r?\n)*', '')
        $rest = $stripped.TrimStart()
        if ($rest) {
            Set-Content -Path $configPath -Value ($block.TrimEnd() + "`n`n" + $rest)
        } else {
            Set-Content -Path $configPath -Value $block
        }
    } else {
        Set-Content -Path $configPath -Value $block
    }
    $wroteVia = "config.yaml edit"
}

# Record Hermes Agent pin in the lock file.
$lockObj = Get-Content $LockFile -Raw | ConvertFrom-Json
$agent = [ordered]@{
    provider        = "custom"
    base_url        = $BaseUrl
    default         = $Model
    context_length  = $ContextLength
    api_mode        = "chat_completions"
    cost            = "free"
    note            = "Local Ollama via Custom Endpoint — never provider ollama-cloud for free local use."
}
$lockObj | Add-Member -NotePropertyName hermes_agent -NotePropertyValue $agent -Force
$lockObj | ConvertTo-Json -Depth 8 | Set-Content -Path $LockFile

Write-Host ""
Write-Host "Changed Hermes Agent to free local Ollama ($wroteVia):"
Write-Host "  provider:       custom"
Write-Host "  base_url:       $BaseUrl"
Write-Host "  default model:  $Model  (locked free)"
Write-Host "  context_length: $ContextLength"
Write-Host ""
Write-Host "Config: $configPath"
Write-Host "Env:    $envPath  (HERMES_API_TIMEOUT for slow CPU models)"
Write-Host ""
Write-Host "Next:"
Write-Host "  1. Keep Ollama running:  ollama serve"
Write-Host "  2. Install Hermes Agent if needed: https://hermes-agent.nousresearch.com/"
Write-Host "  3. Restart Hermes / run: hermes"
Write-Host ""
Write-Host "Note: provider must be 'custom' for local Ollama — not 'ollama'"
Write-Host "      ('ollama' / 'ollama-cloud' is the hosted Ollama Cloud API)."
