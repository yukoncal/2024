# Verify the OpenAI-compatible Ollama endpoint for the Cursor alias.
# Run in PowerShell:  .\scripts\verify-qwen.ps1
$ErrorActionPreference = "Stop"

$BaseUrl    = if ($env:BASE_URL)    { $env:BASE_URL }    else { "http://127.0.0.1:11434/v1" }
$ModelAlias = if ($env:MODEL_ALIAS) { $env:MODEL_ALIAS } else { "qwen359b" }

Write-Host "Listing models at $BaseUrl/models ..."
$models = Invoke-RestMethod -Uri "$BaseUrl/models" -Headers @{ Authorization = "Bearer ollama" }
$models | ConvertTo-Json -Depth 6
Write-Host ""

Write-Host "Chat completion smoke test with model '$ModelAlias' ..."
$body = @{
    model      = $ModelAlias
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
    Write-Host "OK — endpoint looks ready for Cursor (use a public HTTPS base URL in Cursor settings)."
} else {
    Write-Error "Unexpected response — check that the alias exists: ollama list"
    exit 1
}
