# etc/deploy.ps1 — Windows / PowerShell counterpart to etc/deploy (bash).
#
# Symlinks the Windows-relevant subset of the dotfiles tree:
#
#   xdg-config/windows/powershell/Microsoft.PowerShell_profile.ps1  ->  $PROFILE
#   home/windows/.psmux.conf                                        ->  $HOME/.psmux.conf
#   xdg-config/common/starship.toml                                 ->  $HOME/.config/starship.toml
#   xdg-config/common/lazygit/config.yml                            ->  $HOME/.config/lazygit/config.yml
#   xdg-config/common/git/config                                    ->  $HOME/.config/git/config
#   xdg-config/common/git/ignore                                    ->  $HOME/.config/git/ignore
#   xdg-config/common/git/hooks/pre-commit                          ->  $HOME/.config/git/hooks/
#
# And, only when the tree being deployed actually carries them, the extension
# slots a stacked tree is expected to fill (the base repo tracks none of these,
# so for it every line is a no-op):
#
#   xdg-config/common/git/config.local                              ->  $HOME/.config/git/config.local
#   xdg-config/common/lazygit/config.local.yml                      ->  $HOME/.config/lazygit/config.local.yml
#   xdg-config/windows/powershell/profile.local.ps1                 ->  next to $PROFILE
#
# The PowerShell deploy is intentionally narrower than the bash side — apps
# without a clean Windows XDG story (gh, rstudio, ...) are skipped. .tmux.conf
# isn't linked: native Windows has no tmux, and WSL has its own filesystem, so a
# Windows-side symlink doesn't reach any tmux runtime. psmux (PowerShell-native
# tmux alternative) gets its own .psmux.conf since psmux reads .psmux.conf first
# and the shared .tmux.conf assumes /bin/zsh.
#
# git is NOT in that skipped list: git-for-windows reads ~/.config/git/config
# like every other platform, so the tracked config (delta as the pager, the
# difftastic aliases, the gitleaks hooksPath) applies here as well. It also
# brings core.autocrlf = input, which overrides the Git-for-Windows system
# default of converting to CRLF on checkout — see README, "Line endings on
# Windows", for what that means and how to opt back out per machine.
#
# Symlink creation requires either an elevated shell (Run as Administrator) or
# Developer Mode enabled (Settings -> For developers -> Developer Mode = ON).
#
# Usage:
#   pwsh -File etc/deploy.ps1                    # deploy this repo
#   pwsh -File etc/deploy.ps1 -Root <dir>        # deploy another tree, same layout
#   pwsh -File etc/deploy.ps1 -DryRun            # preview only
#
# -Root is how layering works, and it is all this script knows about it: run it
# once per tree, in the order you want, and the later run wins. This script has
# no notion of an "overlay" and never looks for one.

[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$Root
)

$ErrorActionPreference = 'Stop'

$Dotfiles = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ($Root) {
    if (-not (Test-Path $Root)) { throw "Not a directory: $Root" }
    $Tree = (Resolve-Path $Root).Path
} else {
    $Tree = $Dotfiles
}

Write-Host "Tree:    $Tree"
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
    param([string]$TreeRoot)

    # PowerShell profile -> $PROFILE
    New-DotfileLink (Join-Path $TreeRoot 'xdg-config\windows\powershell\Microsoft.PowerShell_profile.ps1') $PROFILE

    # Nothing from home/common is linked here. It holds .Rprofile, .rsyncignore
    # and .tmux.conf, none of which has a Windows runtime this deploy can assume;
    # .vimrc and .vim/ used to be linked from here and were dead lines from the
    # commit that switched this repo to neovim, since the files went with it.

    # home/windows/* -> $HOME (Windows-only dotfiles, e.g. psmux config)
    New-DotfileLink (Join-Path $TreeRoot 'home\windows\.psmux.conf') (Join-Path $HOME '.psmux.conf')

    # starship reads ~/.config/starship.toml on Windows too, so the prompt's
    # symbols come from the same tracked file as everywhere else — which is what
    # keeps them inside the Nerd font pkg/windows-fonts.txt installs.
    New-DotfileLink (Join-Path $TreeRoot 'xdg-config\common\starship.toml') `
                    (Join-Path $HOME '.config\starship.toml')

    # lazygit reads %LOCALAPPDATA%\lazygit on Windows, not ~/.config, so linking
    # this is only half the job: the deployed PowerShell profile points
    # LG_CONFIG_FILE at the link, the way ~/.shell/lazygit.sh does on Unix.
    New-DotfileLink (Join-Path $TreeRoot 'xdg-config\common\lazygit\config.yml') `
                    (Join-Path $HOME '.config\lazygit\config.yml')

    # git — the same three destinations the bash deploy's xdg-config/common
    # recursion produces on macOS/Linux. git-for-windows resolves ~/.config the
    # same way, and the bash hook script runs under its MSYS shell.
    New-DotfileLink (Join-Path $TreeRoot 'xdg-config\common\git\config') `
                    (Join-Path $HOME '.config\git\config')
    # core.excludesfile in that config points at this file.
    New-DotfileLink (Join-Path $TreeRoot 'xdg-config\common\git\ignore') `
                    (Join-Path $HOME '.config\git\ignore')
    New-DotfileLink (Join-Path $TreeRoot 'xdg-config\common\git\hooks\pre-commit') `
                    (Join-Path $HOME '.config\git\hooks\pre-commit')

    # Extension slots. The base repo tracks none of these, and New-DotfileLink
    # returns early on a missing source, so each line does nothing until a
    # stacked tree deployed with -Root supplies the file. Without them the slots
    # documented in README were Unix-only in practice: the bash deploy walks
    # xdg-config/ per file and picks them up, this script links a fixed list.
    #
    # Nothing writes to any of these three, which is what makes linking them into
    # a repo safe — unlike ~/.gitconfig, the file `git config --global` edits.
    New-DotfileLink (Join-Path $TreeRoot 'xdg-config\common\git\config.local') `
                    (Join-Path $HOME '.config\git\config.local')
    New-DotfileLink (Join-Path $TreeRoot 'xdg-config\common\lazygit\config.local.yml') `
                    (Join-Path $HOME '.config\lazygit\config.local.yml')
    # Dot-sourced by the deployed profile from its own directory, so it has to
    # land beside $PROFILE rather than under ~/.config.
    New-DotfileLink (Join-Path $TreeRoot 'xdg-config\windows\powershell\profile.local.ps1') `
                    (Join-Path (Split-Path $PROFILE) 'profile.local.ps1')
}

# Guard the ~/.gitconfig invariant before linking anything — the same rule the
# bash deploy enforces, and it starts mattering on Windows the moment
# Invoke-DeployTree links the git config.
#
# `git config --global` writes to ~/.gitconfig when that file exists, and
# otherwise falls back to ~/.config/git/config — which Invoke-DeployTree
# symlinks into this repo. Git follows the symlink and rewrites the *target*, so
# on a box without ~/.gitconfig a plain `git config --global user.email ...`
# silently lands a personal address in a tracked file of this repo.
#
# Creating the file removes that fallback for good: ~/.gitconfig is then both the
# write target and, being read after ~/.config/git/config, the winner for
# single-valued keys. Only ever created, never modified.
function Initialize-GitConfig {
    $gitconfig = Join-Path $HOME '.gitconfig'
    # Get-Item rather than Test-Path: a dangling symlink here still counts as
    # "exists", and must not be replaced by a regular file.
    if (Get-Item -LiteralPath $gitconfig -Force -ErrorAction SilentlyContinue) { return }

    if ($DryRun) {
        Write-Host "would create: $gitconfig (keeps 'git config --global' out of this repo)"
        return
    }

    Set-Content -LiteralPath $gitconfig -Value @'
# Machine-local git config. Untracked on purpose: this is where identity and
# anything else host-specific belongs, and it is what `git config --global`
# edits. Shared, non-personal settings come from ~/.config/git/config, which
# etc/deploy.ps1 symlinks in from the dotfiles repo.
#
# Git reads ~/.config/git/config first and this file second, so a single-valued
# key set here wins. Created by the deploy so that `git config --global` can
# never fall back to writing into a tracked file.
'@
    Write-Host "created: $gitconfig (keeps 'git config --global' out of this repo)" -ForegroundColor Green
}

Initialize-GitConfig

Invoke-DeployTree $Tree

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
