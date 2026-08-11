# Verify the OpenAI-compatible Ollama endpoint for the Hermes alias.
# Run in PowerShell:  .\scripts\verify-hermes.ps1
$ErrorActionPreference = "Stop"

$BaseUrl = if ($env:BASE_URL) { $env:BASE_URL } else { "http://127.0.0.1:11434/v1" }
$Model   = if ($env:MODEL)    { $env:MODEL }    else { "hermes" }

Write-Host "Listing models at $BaseUrl/models ..."
$models = Invoke-RestMethod -Uri "$BaseUrl/models" -Headers @{ Authorization = "Bearer ollama" }
$models | ConvertTo-Json -Depth 6
Write-Host ""

Write-Host "Chat completion smoke test with model '$Model' ..."
$body = @{
    model      = $Model
    messages   = @(@{ role = "user"; content = "Reply with exactly: ok" })
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

$content = $response.choices[0].message.content
if ($content) {
    Write-Host ""
    Write-Host "OK — Hermes endpoint looks ready for Cursor (use a public HTTPS base URL in Cursor settings)."
} else {
    Write-Error "Unexpected response — run .\scripts\setup-hermes.ps1 first (uses your local free model)."
    exit 1
}
