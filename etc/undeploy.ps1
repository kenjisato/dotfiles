# etc/undeploy.ps1 — Windows / PowerShell counterpart to etc/undeploy (bash).
#
# Removes symlinks at $PROFILE and beside it, under $HOME (top-level) and under
# $HOME\.config (recursive) whose target resolves into one of the trees it is
# given (this repo by default; add more with -Also). Regular files are never
# touched, and symlinks pointing anywhere else (e.g. user-created links into
# other repos) are left alone.
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

# Paths already handled. The walks below overlap by design — $PROFILE is also an
# entry in its own directory — and without this a dry-run reports such a link
# twice and inflates the count. (A real run does not, only because the first
# removal makes the second call's Test-Path fail, which is luck, not a design.)
$script:Seen = [System.Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase)

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
    # Normalised, so the same link reached through two walks compares equal.
    if (-not $script:Seen.Add([IO.Path]::GetFullPath($Path))) { return }
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

# --- $PROFILE and its directory (typically $HOME\Documents\PowerShell\) ---
#
# The directory holds the profile itself plus profile.local.ps1, which the deploy
# links there when a stacked tree carries one. Scanning the directory covers both
# without naming either, and Remove-DotfileLink still only touches links that
# resolve into one of the trees given — a user's own scripts and modules there are
# left alone. The explicit $PROFILE call is kept for intent; the $script:Seen
# guard is what keeps it from being counted twice.
if ($PROFILE) {
    Remove-DotfileLink $PROFILE
    $profileDir = Split-Path $PROFILE
    if ($profileDir -and (Test-Path -LiteralPath $profileDir)) {
        $profileLinks = @(
            Get-ChildItem -Path $profileDir -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }
        )
        foreach ($link in $profileLinks) { Remove-DotfileLink $link.FullName }
    }
}

# --- $HOME top-level (.vimrc, .vim/, plus orphans like .tmux.conf) ---
Get-ChildItem -Path $HOME -Force | ForEach-Object {
    Remove-DotfileLink $_.FullName
}

# --- $HOME\.config (recursive — mirrors the deploy's per-file git links) ---
#
# The top-level walk above cannot reach these: ~/.config is a real directory, so
# nothing in it is visible as a link from $HOME. Materialise the list before
# removing anything — the enumeration would otherwise run while its own entries
# are being deleted. -Recurse does not descend into reparse points, so a linked
# directory is removed as the link it is.
$configRoot = Join-Path $HOME '.config'
if (Test-Path -LiteralPath $configRoot) {
    $configLinks = @(
        Get-ChildItem -Path $configRoot -Force -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }
    )
    foreach ($link in $configLinks) { Remove-DotfileLink $link.FullName }
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
