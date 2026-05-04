# etc/wt-apply-settings.ps1 — merge xdg-config/windows/windows-terminal/overlay.json
# into the user's Windows Terminal settings.json.
#
# WT's settings.json is a single monolithic file containing both generic
# (font, color schemes, keys) and host-specific (profile GUIDs, WSL distros,
# startup paths) data, so symlinking the whole file across PCs is impractical.
# This merges only the keys we declare in overlay.json, leaving everything
# else intact. Idempotent — re-running just re-applies the same overrides.
#
# Caveats:
#   - WT settings.json is JSONC (allows // and /* */ comments). We strip
#     comments before parsing, and write back without them.
#   - Original file is backed up to settings.json.bak.<timestamp>.
#   - Targets the Microsoft Store stable WT (Microsoft.WindowsTerminal_8wekyb3d8bbwe).
#     Preview / Unpackaged builds use different paths and are not handled here.
#
# Usage:
#   pwsh -File etc\wt-apply-settings.ps1            # apply
#   pwsh -File etc\wt-apply-settings.ps1 -DryRun    # preview merged result

[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$Dotfiles = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Overlay  = Join-Path $Dotfiles 'xdg-config\windows\windows-terminal\overlay.json'
$Settings = Join-Path $Env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'

if (-not (Test-Path $Overlay)) {
    Write-Host "no Windows Terminal overlay at $Overlay — skipping" -ForegroundColor DarkGray
    return
}
if (-not (Test-Path $Settings)) {
    Write-Warning "Windows Terminal settings not found at $Settings — start WT once and re-run"
    return
}

function Remove-JsonComments {
    param([string]$Text)
    # Strip block comments first (non-greedy), then line comments.
    # Note: this is a simple regex strip — values containing // or /* will be
    # mangled. WT settings.json doesn't normally hold such strings.
    $stripped = [regex]::Replace($Text, '(?s)/\*.*?\*/', '')
    $stripped = [regex]::Replace($stripped, '(?m)//.*?$', '')
    return $stripped
}

function Merge-Hashtable {
    param([hashtable]$Base, [hashtable]$Overlay)
    foreach ($key in $Overlay.Keys) {
        if ($Base.ContainsKey($key) -and $Base[$key] -is [hashtable] -and $Overlay[$key] -is [hashtable]) {
            Merge-Hashtable -Base $Base[$key] -Overlay $Overlay[$key]
        } else {
            $Base[$key] = $Overlay[$key]
        }
    }
}

Write-Host "Windows Terminal: merging overlay -> settings.json" -ForegroundColor Cyan
Write-Host "  overlay:  $Overlay"
Write-Host "  settings: $Settings"

$rawSettings = Get-Content $Settings -Raw
$cleanSettings = Remove-JsonComments $rawSettings
$settingsObj = $cleanSettings | ConvertFrom-Json -AsHashtable -Depth 100

$overlayObj = Get-Content $Overlay -Raw | ConvertFrom-Json -AsHashtable -Depth 100

Merge-Hashtable -Base $settingsObj -Overlay $overlayObj

$merged = $settingsObj | ConvertTo-Json -Depth 100

if ($DryRun) {
    Write-Host ""
    Write-Host "(dry-run) merged settings.json would be:"
    Write-Host $merged
    return
}

$backup = "$Settings.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
Copy-Item $Settings $backup
Write-Host "  backup -> $backup" -ForegroundColor DarkGray

Set-Content -Path $Settings -Value $merged -Encoding utf8
Write-Host "  applied" -ForegroundColor Green
