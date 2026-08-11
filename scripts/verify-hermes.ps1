# Verify the OpenAI-compatible Ollama endpoint for the locked free Hermes model.
# Run in PowerShell:  .\scripts\verify-hermes.ps1
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$LockFile = Join-Path $Root "config\hermes.lock.json"
$lock = Get-Content $LockFile -Raw | ConvertFrom-Json
$LockedModel = if ($lock.model) { $lock.model } else { "hermes" }

$BaseUrl = if ($env:BASE_URL) { $env:BASE_URL } else { "http://127.0.0.1:11434/v1" }
$Model = $LockedModel
if ($env:MODEL -and $env:MODEL -ne $LockedModel -and $env:MODEL -ne "${LockedModel}:latest") {
    Write-Error "model '$($env:MODEL)' is blocked. Hermes is locked to free local model '$LockedModel'."
    exit 1
}

Write-Host "Listing models at $BaseUrl/models ..."
$models = Invoke-RestMethod -Uri "$BaseUrl/models" -Headers @{ Authorization = "Bearer ollama" }
$models | ConvertTo-Json -Depth 6
Write-Host ""

Write-Host "Chat completion smoke test with locked free model '$Model' ..."
$body = @{
    model      = $Model
    messages   = @(@{ role = "user"; content = "Reply with exactly: hermes-ok" })
    stream     = $false
    max_tokens = 32
} | ConvertTo-Json -Depth 5

$response = Invoke-RestMethod -Method Post -Uri "$BaseUrl/chat/completions" `
    -Headers @{
        Authorization  = "Bearer ollama"
        "Content-Type" = "application/json"
    } `
    -Body $body

$response | ConvertTo-Json -Depth 8

$content = ([string]$response.choices[0].message.content).Trim()
$expect = if ($env:EXPECT) { $env:EXPECT } else { "hermes-ok" }
if ($content.ToLower() -eq $expect.ToLower()) {
    Write-Host ""
    Write-Host "OK — locked free Hermes is ready (not Grok)."
} else {
    Write-Error "expected '$expect' (case-insensitive), got '$content'. Run .\scripts\hermes-doctor.ps1 -Fix"
    exit 1
}
