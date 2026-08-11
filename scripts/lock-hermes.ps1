# Lock Hermes to the free local Ollama model and print the Cursor Desktop pin steps.
# Replaces paid Grok 4.5 High Fast for everyday Hermes use.
# Run in PowerShell:  .\scripts\lock-hermes.ps1
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$LockFile = Join-Path $Root "config\hermes.lock.json"

Write-Host "==> Ensuring free local Hermes model is installed (no paid cloud model)"
& "$Root\scripts\setup-hermes.ps1"

$lock = Get-Content $LockFile -Raw | ConvertFrom-Json
$lockedModel = if ($lock.model) { $lock.model } else { "hermes" }
$source = if ($lock.source_model) { $lock.source_model } else { "openhermes:latest" }

try {
    $list = ollama list 2>$null
    foreach ($line in $list) {
        if ($line -match '^(openhermes\S*)\s') {
            $source = $Matches[1]
            break
        }
    }
} catch {}

$lock.locked = $true
$lock.model = $lockedModel
$lock.source_model = $source
$lock.cost = "free"
$lock.provider = "ollama-local"
$lock.replaced_paid_model = "cursor-grok-4.5-high-fast"
if (-not $lock.replaced_paid_pricing) {
    $lock | Add-Member -NotePropertyName replaced_paid_pricing -NotePropertyValue ([pscustomobject]@{
        variant = "Grok 4.5 Fast"
        input_per_million_usd = 4
        output_per_million_usd = 18
    }) -Force
}
if (-not $lock.cursor_desktop) {
    $lock | Add-Member -NotePropertyName cursor_desktop -NotePropertyValue ([pscustomobject]@{}) -Force
}
$lock.cursor_desktop.openai_api_key = "ollama"
$lock.cursor_desktop.add_custom_model = $lockedModel
$lock.cursor_desktop.turn_auto_off = $true
$lock.cursor_desktop.select_model = $lockedModel
$lock | ConvertTo-Json -Depth 8 | Set-Content -Path $LockFile -Encoding utf8

Write-Host ""
Write-Host "==> Smoke-testing locked model '$lockedModel'"
$env:MODEL = $lockedModel
& "$Root\scripts\verify-hermes.ps1"

$baseUrl = $null
if ($lock.tunnel_base_url) { $baseUrl = $lock.tunnel_base_url }
elseif ($lock.cursor_desktop.override_openai_base_url) { $baseUrl = $lock.cursor_desktop.override_openai_base_url }
if (-not $baseUrl) { $baseUrl = "https://YOUR-TUNNEL/v1" }

Write-Host @"

============================================================
HERMES LOCKED — FREE LOCAL MODEL (replaces Grok 4.5 High Fast)
============================================================
Lock file:  $LockFile
Model:      $lockedModel  (source: $source)
Cost:       `$0  (runs on your machine via Ollama)

Grok 4.5 High Fast pricing (what this replaces):
  Fast variant: `$4 / M input tokens, `$18 / M output tokens
  Base Grok 4.5: `$2 / M input, `$6 / M output
  "High" effort does not change the rate — it burns more tokens per task.

IMPORTANT:
  • This Cloud Agent tab CANNOT switch off Grok mid-run.
  • For free Hermes every time: use Cursor DESKTOP (not Cloud Agents).
  • Turn Auto OFF and pin model '$lockedModel'.

Cursor Desktop → Settings → Models (lock these):
  OpenAI API Key:            ollama
  Override OpenAI Base URL:  $baseUrl
  Add custom model:          $lockedModel
  Chat model picker:         Auto OFF → select $lockedModel

Next steps to finish the fix:
  1. Keep Ollama running
  2. Expose it:  .\scripts\expose-for-cursor.ps1
  3. Paste the printed https://…/v1 URL into Override OpenAI Base URL
  4. Add model `$lockedModel`, turn Auto off, select `$lockedModel`
  5. Smoke test: Reply with exactly: hermes-ok
  6. For future Cloud Agents: do NOT pick Grok 4.5 High Fast for Hermes work

Open local free chat anytime:
  .\scripts\open-hermes.ps1
============================================================
"@
