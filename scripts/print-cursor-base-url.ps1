# Print the Override OpenAI Base URL for Cursor when ngrok basic auth (TUNNEL_AUTH) is in use.
# Requires: ngrok running and $env:TUNNEL_AUTH = 'user:pass'
$ErrorActionPreference = "Stop"

if (-not $env:TUNNEL_AUTH -or $env:TUNNEL_AUTH -notmatch ':') {
    Write-Error "Set `$env:TUNNEL_AUTH first, e.g. `$env:TUNNEL_AUTH = 'myuser:my-password'"
}

try {
    $null = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 3
} catch {
    Write-Error @"
ngrok does not appear to be running on this machine.
In another window, run: .\scripts\expose-for-cursor.ps1
"@
}

$data = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 3
$public = ($data.tunnels | Where-Object { $_.public_url -like "https://*" } | Select-Object -First 1).public_url
if (-not $public) {
    Write-Error "No HTTPS ngrok URL found. Wait for ngrok to show Forwarding https://…"
}

$user, $password = $env:TUNNEL_AUTH -split ':', 2
if (-not $user -or -not $password) {
    Write-Error "TUNNEL_AUTH must be user:password"
}

$hostPart = ($public -replace '^https://', '').TrimEnd('/')
$u = [uri]::EscapeDataString($user)
$p = [uri]::EscapeDataString($password)
$base = "https://${u}:${p}@${hostPart}/v1"

Write-Host ""
Write-Host "Paste this into Cursor → Settings → Models → Override OpenAI Base URL:"
Write-Host ""
Write-Host $base
Write-Host ""
Write-Host "(Keep this private. Do not share screenshots of this line.)"
