# Hermes doctor — diagnose and optionally fix the locked free local Hermes setup.
# Usage:
#   .\scripts\hermes-doctor.ps1
#   .\scripts\hermes-doctor.ps1 -Fix
param(
    [switch]$Fix
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$LockFile = Join-Path $Root "config\hermes.lock.json"

$script:Pass = 0
$script:Warn = 0
$script:Fail = 0

function Ok([string]$msg)   { $script:Pass++; Write-Host "  [OK]   $msg" }
function WarnMsg([string]$msg) { $script:Warn++; Write-Host "  [WARN] $msg" }
function FailMsg([string]$msg) { $script:Fail++; Write-Host "  [FAIL] $msg" }
function FixNote([string]$msg) { Write-Host "         → fixing: $msg" }

function Test-Ollama {
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 2 | Out-Null
        return $true
    } catch {
        return $false
    }
}

Write-Host "Hermes Doctor"
Write-Host "============="
Write-Host ("Mode: " + ($(if ($Fix) { "diagnose + fix" } else { "diagnose only" })))
Write-Host "Root: $Root"
Write-Host ""

Write-Host "Ollama"
if (Get-Command ollama -ErrorAction SilentlyContinue) {
    Ok "ollama binary found"
} else {
    FailMsg "ollama is not installed"
    if ($Fix) { FixNote "install from https://ollama.com/download" }
}

if (Test-Ollama) {
    Ok "Ollama API reachable at http://127.0.0.1:11434"
} elseif ($Fix) {
    FixNote "starting ollama serve"
    Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        if (Test-Ollama) { break }
    }
    if (Test-Ollama) { Ok "Ollama API started and reachable" } else { FailMsg "Ollama API not reachable" }
} else {
    FailMsg "Ollama API not reachable at http://127.0.0.1:11434"
}
Write-Host ""

Write-Host "Lock"
$lockedModel = "hermes"
if (Test-Path $LockFile) {
    try {
        $lock = Get-Content $LockFile -Raw | ConvertFrom-Json
        if ($lock.locked -eq $true -and $lock.model -eq "hermes" -and $lock.cost -eq "free") {
            Ok "config/hermes.lock.json pins free model 'hermes' (not Grok)"
            $lockedModel = $lock.model
        } else {
            FailMsg "lock file exists but is invalid / unlocked"
            if ($Fix) {
                FixNote "rewriting lock via lock-hermes.ps1"
                & "$Root\scripts\lock-hermes.ps1" | Out-Null
            }
        }
    } catch {
        FailMsg "lock file unreadable"
    }
} else {
    FailMsg "missing config/hermes.lock.json"
    if ($Fix) {
        FixNote "creating lock via lock-hermes.ps1"
        & "$Root\scripts\lock-hermes.ps1" | Out-Null
    }
}
Write-Host ""

Write-Host "Model"
if (Test-Ollama) {
    $names = @()
    foreach ($line in (ollama list 2>$null)) {
        if ($line -match '^\s*NAME\b') { continue }
        $parts = ($line -split '\s+') | Where-Object { $_ -ne "" }
        if ($parts.Count -ge 1) { $names += $parts[0] }
    }
    $hasHermes = $false
    foreach ($n in $names) {
        if ($n -eq $lockedModel -or $n -eq "${lockedModel}:latest" -or ($n -split ':')[0] -eq $lockedModel) {
            $hasHermes = $true
            Ok "locked model installed: $n"
            break
        }
    }
    if (-not $hasHermes) {
        FailMsg "locked model '$lockedModel' not installed"
        if ($Fix) {
            FixNote "running setup-hermes.ps1 / lock-hermes.ps1"
            & "$Root\scripts\setup-hermes.ps1"
            & "$Root\scripts\lock-hermes.ps1"
        }
    }
} else {
    WarnMsg "skipped model checks (Ollama down)"
}
Write-Host ""

Write-Host "Local API"
if (Test-Ollama) {
    try {
        $body = @{
            model = $lockedModel
            messages = @(@{ role = "user"; content = "Reply with exactly: hermes-ok" })
            stream = $false
            max_tokens = 32
        } | ConvertTo-Json -Depth 5
        $resp = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:11434/v1/chat/completions" `
            -Headers @{ Authorization = "Bearer ollama"; "Content-Type" = "application/json" } `
            -Body $body
        $content = [string]$resp.choices[0].message.content
        if ($content.Trim() -eq "hermes-ok") {
            Ok "chat completion returned exactly 'hermes-ok'"
        } elseif ($content) {
            WarnMsg "chat replied '$content' (expected exactly 'hermes-ok')"
        } else {
            FailMsg "chat completion failed for model '$lockedModel'"
        }
    } catch {
        FailMsg "chat completion request failed"
        if ($Fix) {
            FixNote "re-running lock-hermes.ps1"
            & "$Root\scripts\lock-hermes.ps1" | Out-Null
        }
    }
} else {
    WarnMsg "skipped chat smoke (Ollama down)"
}
Write-Host ""

Write-Host "Tunnel"
$tunnel = $null
if (Test-Path $LockFile) {
    $lock = Get-Content $LockFile -Raw | ConvertFrom-Json
    if ($lock.tunnel_base_url) { $tunnel = $lock.tunnel_base_url }
    elseif ($lock.cursor_desktop.override_openai_base_url) { $tunnel = $lock.cursor_desktop.override_openai_base_url }
}
if (-not $tunnel -or $tunnel -match 'REPLACE_WITH_TUNNEL|YOUR-TUNNEL') {
    WarnMsg "no live public tunnel URL saved (Cursor Desktop needs HTTPS)"
    Write-Host "         Run: .\scripts\expose-for-cursor.ps1"
} else {
    try {
        Invoke-RestMethod -Uri "$tunnel/models" -Headers @{ Authorization = "Bearer ollama" } -TimeoutSec 8 | Out-Null
        Ok "public tunnel reachable: $tunnel"
    } catch {
        FailMsg "configured tunnel not reachable: $tunnel"
        if ($Fix) {
            FixNote "clearing dead tunnel URL from lock"
            $lock.cursor_desktop.override_openai_base_url = "REPLACE_WITH_TUNNEL_URL/v1"
            if ($lock.PSObject.Properties.Name -contains "tunnel_base_url") {
                $lock.PSObject.Properties.Remove("tunnel_base_url")
            }
            $lock | ConvertTo-Json -Depth 8 | Set-Content -Path $LockFile -Encoding utf8
            WarnMsg "dead tunnel cleared — run .\scripts\expose-for-cursor.ps1"
        }
    }
}
if (Get-Command cloudflared -ErrorAction SilentlyContinue) {
    Ok "cloudflared available (preferred over free ngrok)"
} else {
    WarnMsg "cloudflared not installed (recommended for Cursor Desktop)"
}
Write-Host ""

Write-Host "Hermes Agent"
$hermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME } else { Join-Path $HOME ".hermes" }
$hermesCfg = Join-Path $hermesHome "config.yaml"
$localBin = Join-Path $HOME ".local\bin"
if (Test-Path $localBin) {
    $env:Path = "$localBin;$env:Path"
}

function Resolve-HermesCli {
    $cmd = Get-Command hermes -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($cand in @(
        (Join-Path $HOME ".local\bin\hermes"),
        (Join-Path $HOME ".local\bin\hermes.exe"),
        "C:\Program Files\Hermes\hermes.exe"
    )) {
        if (Test-Path $cand) { return $cand }
    }
    return $null
}

$hermesBin = Resolve-HermesCli
if ($hermesBin) {
    Ok "hermes CLI found ($hermesBin)"
} elseif ($Fix) {
    FixNote "installing Hermes Agent CLI (non-interactive)"
    try {
        $installer = Join-Path $env:TEMP "hermes-install.sh"
        Invoke-WebRequest -Uri "https://hermes-agent.nousresearch.com/install.sh" -OutFile $installer
        if (Get-Command bash -ErrorAction SilentlyContinue) {
            & bash $installer --skip-setup --non-interactive --skip-browser
        } else {
            Write-Host "         On Windows, install via: https://hermes-agent.nousresearch.com/  or  ollama launch hermes"
        }
        $env:Path = "$(Join-Path $HOME '.local\bin');$env:Path"
        $hermesBin = Resolve-HermesCli
        if ($hermesBin) { Ok "hermes CLI installed ($hermesBin)" }
        else { FailMsg "hermes CLI install did not produce a hermes binary" }
    } catch {
        FailMsg "hermes CLI install failed: $_"
    }
} else {
    WarnMsg "hermes CLI not installed"
    Write-Host "         Fix: .\scripts\hermes-doctor.ps1 -Fix"
    Write-Host "         Or:  https://hermes-agent.nousresearch.com/  /  ollama launch hermes"
}

if (Test-Path $hermesCfg) {
    $cfgText = Get-Content -Raw $hermesCfg
    $provider = $null; $base = $null; $default = $null
    foreach ($line in ($cfgText -split "`n")) {
        $s = $line.Trim()
        if ($s -match '^provider:\s*(.+)$') { $provider = $Matches[1].Trim().Trim('"').Trim("'") }
        elseif ($s -match '^base_url:\s*(.+)$') { $base = $Matches[1].Trim().Trim('"').Trim("'") }
        elseif ($s -match '^default:\s*(.+)$') { $default = $Matches[1].Trim().Trim('"').Trim("'") }
    }
    if ($provider -eq "custom" -and $base -match "11434" -and ($default -eq $lockedModel -or $default -eq "$lockedModel`:latest")) {
        Ok "Hermes Agent pinned to free local Ollama (provider=custom, model=$default)"
    } elseif ($provider -eq "ollama" -or $provider -eq "ollama-cloud") {
        FailMsg "Hermes Agent provider is '$provider' (cloud) — should be 'custom' for free local"
        if ($Fix) {
            FixNote "running hermes-use-ollama.ps1"
            & "$Root\scripts\hermes-use-ollama.ps1" | Out-Null
        }
    } else {
        WarnMsg "Hermes Agent config present but not pinned to locked '$lockedModel' (provider=$provider, model=$default)"
        if ($Fix) {
            FixNote "running hermes-use-ollama.ps1"
            & "$Root\scripts\hermes-use-ollama.ps1" | Out-Null
        }
    }
} else {
    WarnMsg "no ~/.hermes/config.yaml yet — run .\scripts\hermes-use-ollama.ps1 after installing Hermes Agent"
    if ($Fix -and (Test-Ollama)) {
        FixNote "writing ~/.hermes/config.yaml via hermes-use-ollama.ps1"
        & "$Root\scripts\hermes-use-ollama.ps1" | Out-Null
    }
}
Write-Host ""

Write-Host "Cursor Desktop pin"
Ok "lock says: Auto OFF, model '$lockedModel', key 'ollama'"
WarnMsg "Cloud Agents cannot use local Hermes — pin '$lockedModel' in Cursor Desktop"
Write-Host "         If you MUST use Cloud Agents, pick the cheapest cloud fallback:"
Write-Host "         - claude-3-haiku  (approx 100x cheaper than Grok 4.5 Fast)"
Write-Host "         - gpt-4o-mini"
Write-Host ""

Write-Host "Summary"
Write-Host "-------"
Write-Host "  Passed: $($script:Pass)"
Write-Host "  Warnings: $($script:Warn)"
Write-Host "  Failures: $($script:Fail)"
Write-Host ""

if ($script:Fail -gt 0) {
    Write-Host "Hermes is NOT fully healthy."
    if (-not $Fix) { Write-Host "Re-run with autofix:  .\scripts\hermes-doctor.ps1 -Fix" }
    exit 1
}

if ($script:Warn -gt 0) {
    Write-Host "Hermes local core is OK, with warnings (usually tunnel / Desktop pin / Agent CLI)."
    Write-Host "  Cursor Desktop: .\scripts\expose-for-cursor.ps1 → model $lockedModel, Auto OFF"
    Write-Host "  Hermes Agent:   .\scripts\hermes-use-ollama.ps1"
    exit 0
}

Write-Host "Hermes is healthy — locked free local '$lockedModel' is ready."
exit 0
