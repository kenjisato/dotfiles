# etc/undeploy.ps1 — Windows / PowerShell counterpart to etc/undeploy (bash).
#
# Removes symlinks at $PROFILE and under $HOME (top-level) whose target
# resolves into one of the trees it is given (this repo by default; add more
# with -Also). Regular files are never touched, and symlinks
# pointing anywhere else (e.g. user-created links into other repos) are
# left alone.
#
# This complements etc/deploy.ps1 — it inspects exactly the same targets
# the deploy creates, plus any orphans left behind when previous deploys
# linked something we no longer link (e.g. .tmux.conf before that line
# was removed).
#
# Naming the trees is the caller's job: this script has no notion of an
# "overlay" and never goes looking for one. Whatever stacked another tree on top
# of this repo is what knows to pass it here as well.
#
# Usage:
#   pwsh -File etc\undeploy.ps1                   # this repo only
#   pwsh -File etc\undeploy.ps1 -Also <dir>       # plus another tree
#   pwsh -File etc\undeploy.ps1 -DryRun           # preview

[CmdletBinding()]
param(
    [switch]$DryRun,
    [string[]]$Also = @()
)

$ErrorActionPreference = 'Stop'

$Dotfiles = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

$Trees = @($Dotfiles)
foreach ($extra in $Also) {
    if (-not (Test-Path $extra)) { throw "Not a directory: $extra" }
    $Trees += (Resolve-Path $extra).Path
}

foreach ($t in $Trees) { Write-Host "Tree:    $t" }
if ($DryRun) { Write-Host "(dry-run — no changes will be made)" -ForegroundColor Yellow }
Write-Host ""

$script:RemovedCount = 0

function Test-LinkPointsToRepo {
    param([string]$Path)
    $item = Get-Item $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $false }
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }

    $target = $item.Target
    if (-not $target) { return $false }
    if ($target -is [array]) { $target = $target[0] }

    try {
        $resolved = (Resolve-Path -LiteralPath $target -ErrorAction Stop).Path
    } catch {
        $resolved = $target   # dangling symlink — fall back to literal
    }

    foreach ($t in $Trees) {
        if ($resolved.StartsWith($t, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Remove-DotfileLink {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    if (-not (Test-LinkPointsToRepo $Path)) { return }

    $item = Get-Item $Path -Force
    $shown = if ($item.Target) {
        if ($item.Target -is [array]) { $item.Target[0] } else { $item.Target }
    } else { '?' }

    if ($DryRun) {
        Write-Host "would remove: $Path -> $shown"
    } else {
        Write-Host "remove: $Path -> $shown"
        # -Force without -Recurse: on PS 7+ this removes the link itself for
        # both file and directory symlinks, and refuses to delete real
        # non-empty directories — exactly the safety we want.
        Remove-Item -Path $Path -Force
    }
    $script:RemovedCount++
}

# --- $PROFILE (typically under $HOME\Documents\PowerShell\, not top-level) ---
if ($PROFILE) { Remove-DotfileLink $PROFILE }

# --- $HOME top-level (.vimrc, .vim/, plus orphans like .tmux.conf) ---
Get-ChildItem -Path $HOME -Force | ForEach-Object {
    Remove-DotfileLink $_.FullName
}

Write-Host ""
if ($script:RemovedCount -eq 0) {
    Write-Host "Nothing to remove."
} else {
    if ($DryRun) {
        Write-Host "Would remove $($script:RemovedCount) symlink(s). Re-run without -DryRun to apply." -ForegroundColor Yellow
    } else {
        Write-Host "Removed $($script:RemovedCount) symlink(s)." -ForegroundColor Green
    }
}
