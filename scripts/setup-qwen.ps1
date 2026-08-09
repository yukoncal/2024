# Pull Qwen2.5-Coder 7B into Ollama and create a Cursor-safe alias.
# Cursor rejects model names with ":" or "." (e.g. qwen2.5-coder:latest),
# which surfaces as: "The model you chose is not available."
# Run in PowerShell:  .\scripts\setup-qwen.ps1
$ErrorActionPreference = "Stop"

$ModelSource = if ($env:MODEL_SOURCE) { $env:MODEL_SOURCE } else { "qwen2.5-coder:7b" }
$ModelAlias  = if ($env:MODEL_ALIAS)  { $env:MODEL_ALIAS }  else { "qwen25-7b-coder" }
$Root        = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

if ($ModelSource -eq "qwen2.5-coder:7b" -and (Test-Path (Join-Path $Root "ollama\Modelfile-qwen25-7b-coder"))) {
    $Modelfile = Join-Path $Root "ollama\Modelfile-qwen25-7b-coder"
} else {
    $Modelfile = Join-Path $Root "ollama\Modelfile"
}

if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
    Write-Host @"
Ollama is not installed.

Install it from: https://ollama.com/download
Then re-run: .\scripts\setup-qwen.ps1
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

Write-Host "Pulling $ModelSource..."
ollama pull $ModelSource

$tmp = [System.IO.Path]::GetTempFileName()
try {
    (Get-Content $Modelfile) -replace '^FROM .*', "FROM $ModelSource" | Set-Content -Path $tmp -Encoding utf8
    Write-Host "Creating Cursor-safe alias '$ModelAlias'..."
    ollama create $ModelAlias -f $tmp
} finally {
    Remove-Item -Force $tmp -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Installed models:"
ollama list

Write-Host @"

Next steps for Cursor:
  1. Expose Ollama over public HTTPS (Cursor cannot call localhost):
       .\scripts\expose-for-cursor.ps1
  2. In Cursor Desktop: Settings → Models
       - OpenAI API Key: ollama
       - Override OpenAI Base URL: https://YOUR-TUNNEL/v1
       - Add model: $ModelAlias
       - Do NOT add qwen2.5-coder:latest (Cursor rejects ":" / ".")
  3. In the chat model picker, turn Auto off and select $ModelAlias
  4. Send: Reply with exactly: ollama-ok

Local sanity check:
  `$env:MODEL_ALIAS='$ModelAlias'; .\scripts\verify-qwen.ps1
"@
