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
#     comments before parsing using a small state machine that respects
#     string literals (so URLs containing // inside quoted values survive).
#     Comments themselves are not preserved on write-back.
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
    # State-machine strip: skip // line comments and /* */ block comments,
    # but only when not inside a string literal. URLs in JSON values
    # ("https://...") would otherwise be mangled by a naive regex.
    $sb = [System.Text.StringBuilder]::new($Text.Length)
    $len = $Text.Length
    $i = 0
    $inString = $false
    $escape = $false
    while ($i -lt $len) {
        $c = $Text[$i]
        if ($inString) {
            [void]$sb.Append($c)
            if ($escape)        { $escape = $false }
            elseif ($c -eq '\') { $escape = $true }
            elseif ($c -eq '"') { $inString = $false }
            $i++
            continue
        }
        if ($c -eq '"') {
            $inString = $true
            [void]$sb.Append($c)
            $i++
            continue
        }
        if ($c -eq '/' -and ($i + 1) -lt $len) {
            $next = $Text[$i + 1]
            if ($next -eq '/') {
                $i += 2
                while ($i -lt $len -and $Text[$i] -ne "`n") { $i++ }
                continue   # leave the newline (if any) for the outer loop
            }
            if ($next -eq '*') {
                $i += 2
                while ($i -lt $len -and -not ($Text[$i] -eq '*' -and ($i + 1) -lt $len -and $Text[$i + 1] -eq '/')) { $i++ }
                if ($i -lt $len) { $i += 2 }
                continue
            }
        }
        [void]$sb.Append($c)
        $i++
    }
    return $sb.ToString()
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
