# etc/deploy.ps1 — Windows / PowerShell counterpart to etc/deploy (bash).
#
# Symlinks the Windows-relevant subset of the dotfiles tree:
#
#   xdg-config/windows/powershell/Microsoft.PowerShell_profile.ps1  ->  $PROFILE
#   home/common/.vimrc                                              ->  $HOME/.vimrc
#   home/common/.vim/                                               ->  $HOME/.vim/
#
# The PowerShell deploy is intentionally narrower than the bash side — apps
# without a clean Windows XDG story (gh, git, rstudio, ...) are skipped.
# .tmux.conf isn't linked: native Windows has no tmux, and WSL has its own
# filesystem, so a Windows-side symlink doesn't reach any tmux runtime.
#
# Symlink creation requires either an elevated shell (Run as Administrator) or
# Developer Mode enabled (Settings -> For developers -> Developer Mode = ON).
#
# Usage:
#   pwsh -File etc/deploy.ps1              # apply
#   pwsh -File etc/deploy.ps1 -DryRun      # preview only

[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$Dotfiles = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

$Private = $null
if ($Env:DOTFILES_PRIVATE -and (Test-Path $Env:DOTFILES_PRIVATE)) {
    $Private = $Env:DOTFILES_PRIVATE
}

Write-Host "Public:  $Dotfiles"
if ($Private) {
    Write-Host "Private: $Private"
} else {
    Write-Host "Private: (none — run dotfiles-private/etc/deploy.ps1 to overlay)"
}
if ($DryRun) { Write-Host "(dry-run — no changes will be made)" -ForegroundColor Yellow }
Write-Host ""

function Test-CanCreateSymlinks {
    # Symlink creation requires either an elevated session or Developer Mode.
    $isAdmin = ([Security.Principal.WindowsPrincipal]::new(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    if ($isAdmin) { return $true }

    try {
        $devMode = Get-ItemPropertyValue `
            -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
            -Name 'AllowDevelopmentWithoutDevLicense' `
            -ErrorAction Stop
        return $devMode -eq 1
    } catch {
        return $false
    }
}

if (-not (Test-CanCreateSymlinks)) {
    Write-Host "Cannot create symlinks in this session." -ForegroundColor Red
    Write-Host "Either enable Developer Mode, or re-run from an elevated PowerShell." -ForegroundColor Red
    Write-Host ""
    Write-Host "Enable Developer Mode (recommended — persists across reboots):"
    Write-Host "  - GUI: Settings -> System -> For developers -> Developer Mode = ON" -ForegroundColor DarkGray
    Write-Host "  - or in an elevated PowerShell, run once:" -ForegroundColor DarkGray
    Write-Host "      New-ItemProperty ``"
    Write-Host "          -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' ``"
    Write-Host "          -Name 'AllowDevelopmentWithoutDevLicense' ``"
    Write-Host "          -Value 1 -PropertyType DWORD -Force"
    Write-Host ""
    Write-Host "Then open a fresh (non-elevated) PowerShell session and re-run this script."
    exit 1
}

$script:Skipped = [System.Collections.Generic.List[string]]::new()

function New-DotfileLink {
    param([string]$Source, [string]$Target)

    if (-not (Test-Path $Source)) { return }

    if (Test-Path $Target) {
        $item = Get-Item $Target -Force
        if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            Write-Host "skip $Target (exists and is not a symlink)" -ForegroundColor Yellow
            $script:Skipped.Add($Target)
            return
        }
    }
    if ($DryRun) {
        Write-Host "would link: $Target -> $Source"
        return
    }
    $parent = Split-Path $Target -Parent
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (Test-Path $Target) { Remove-Item $Target -Force -Recurse }
    New-Item -ItemType SymbolicLink -Path $Target -Value $Source | Out-Null
    Write-Host "linked: $Target -> $Source" -ForegroundColor Green
}

function Invoke-DeployTree {
    param([string]$Root)

    # PowerShell profile -> $PROFILE
    New-DotfileLink (Join-Path $Root 'xdg-config\windows\powershell\Microsoft.PowerShell_profile.ps1') $PROFILE

    # home/common/* -> $HOME (the genuinely cross-platform dotfiles)
    New-DotfileLink (Join-Path $Root 'home\common\.vimrc') (Join-Path $HOME '.vimrc')
    New-DotfileLink (Join-Path $Root 'home\common\.vim')   (Join-Path $HOME '.vim')

    # Global git hooks — same path as the bash deploy's xdg-config/common
    # recursion produces on macOS/Linux. The bash hook script works under
    # git-for-windows' MSYS shell.
    New-DotfileLink (Join-Path $Root 'xdg-config\common\git\hooks\pre-commit') `
                    (Join-Path $HOME '.config\git\hooks\pre-commit')
}

Write-Host "--- public ---"
Invoke-DeployTree $Dotfiles

if ($Private) {
    Write-Host ""
    Write-Host "--- private overlay ---"
    Invoke-DeployTree $Private
}

if ($script:Skipped.Count -gt 0) {
    Write-Host ""
    Write-Host "Skipped $($script:Skipped.Count) target(s) — existing non-symlink files were not overwritten:" -ForegroundColor Yellow
    foreach ($p in $script:Skipped) {
        Write-Host "  $p" -ForegroundColor Yellow
    }
    Write-Host "Remove these manually (Remove-Item <path>) and re-run deploy if you want them linked." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Deploy complete!" -ForegroundColor Green
Write-Host "Open a new PowerShell session to load the updated profile."
