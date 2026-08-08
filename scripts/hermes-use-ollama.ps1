# Point Hermes Agent / Hermes Desktop at local Ollama (Custom Endpoint).
# Local Ollama uses provider "custom" + OpenAI-compatible /v1 base URL.
param(
    [string]$OllamaHost = $(if ($env:OLLAMA_HOST) { $env:OLLAMA_HOST } else { "127.0.0.1" }),
    [int]$OllamaPort = $(if ($env:OLLAMA_PORT) { [int]$env:OLLAMA_PORT } else { 11434 }),
    [string]$Model = $(if ($env:OLLAMA_MODEL) { $env:OLLAMA_MODEL } else { "qwen2.5-coder:latest" }),
    [int]$ContextLength = $(if ($env:OLLAMA_CONTEXT_LENGTH) { [int]$env:OLLAMA_CONTEXT_LENGTH } else { 8192 }),
    [string]$BaseUrl = $(if ($env:OLLAMA_BASE_URL) { $env:OLLAMA_BASE_URL } else { "" }),
    [switch]$NoPull
)

$ErrorActionPreference = "Stop"

if (-not $BaseUrl) {
    $BaseUrl = "http://${OllamaHost}:${OllamaPort}/v1"
}

$tagsUrl = "http://${OllamaHost}:${OllamaPort}/api/tags"
try {
    Invoke-RestMethod -Uri $tagsUrl -TimeoutSec 5 | Out-Null
} catch {
    Write-Error "Ollama is not reachable at $tagsUrl. Start it with: ollama serve"
}

if (-not $NoPull -and (Get-Command ollama -ErrorAction SilentlyContinue)) {
    $listed = & ollama list 2>$null
    $have = $listed | Select-String -SimpleMatch $Model
    if (-not $have) {
        Write-Host "Pulling $Model..."
        & ollama pull $Model
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
}

$hermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME } else { Join-Path $HOME ".hermes" }
$configPath = Join-Path $hermesHome "config.yaml"
New-Item -ItemType Directory -Force -Path $hermesHome | Out-Null

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
        # Singleline off so '.' cannot swallow later top-level keys.
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

Write-Host ""
Write-Host "Changed Hermes to local Ollama ($wroteVia):"
Write-Host "  provider:       custom"
Write-Host "  base_url:       $BaseUrl"
Write-Host "  default model:  $Model"
Write-Host "  context_length: $ContextLength"
Write-Host ""
Write-Host "Config: $configPath"
Write-Host ""
Write-Host "Next:"
Write-Host "  1. Keep Ollama running:  ollama serve"
Write-Host "  2. Restart Hermes Desktop (or run: hermes)"
Write-Host "  3. In Desktop model picker, select $Model"
Write-Host ""
Write-Host "Note: provider must be 'custom' for local Ollama — not 'ollama'"
Write-Host "      ('ollama' / 'ollama-cloud' is the hosted Ollama Cloud API)."
