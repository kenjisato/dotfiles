# etc/install.ps1 — Windows installer (public dotfiles).
#
# Installs winget packages declared under pkg/winget-packages*.txt.
# Manifests with the .metal.txt suffix are applied only on bare-metal hosts;
# Parallels VMs skip them because the host Mac already has those tools.
#
# Host detection:
#   $Env:DOTFILES_HOST_PROFILE overrides everything (values: parallels|metal).
#   Otherwise: WMI Win32_ComputerSystem.Manufacturer/Model = *Parallels* => parallels.
#
# Usage:
#   pwsh -File etc\install.ps1              # apply
#   pwsh -File etc\install.ps1 -DryRun      # preview

[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Get-HostProfile {
    if ($Env:DOTFILES_HOST_PROFILE) { return $Env:DOTFILES_HOST_PROFILE }
    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        if ($cs.Manufacturer -like '*Parallels*' -or $cs.Model -like '*Parallels*') {
            return 'parallels'
        }
    } catch {}
    if (Get-Service -Name 'prl*' -ErrorAction SilentlyContinue) { return 'parallels' }
    return 'metal'
}

function Read-PackageList {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return @() }
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) { $line }
    }
}

# Squirrel-based installers (GitHub Desktop, ...) auto-update outside winget,
# so winget always re-runs their installer. The installer then tries to wipe
# the existing app directory and fails if the app is running. Stop the process
# first so reinstall can proceed.
$PreInstallStopProcess = @{
    'GitHub.GitHubDesktop' = 'GitHubDesktop'
}

$script:WingetInstalledCache = $null

function Get-WingetInstalledIds {
    if ($null -ne $script:WingetInstalledCache) { return $script:WingetInstalledCache }
    $ids = @{}
    $tmp = New-TemporaryFile
    try {
        & winget export --output $tmp.FullName --disable-interactivity `
            --accept-source-agreements 2>&1 | Out-Null
        if (Test-Path $tmp.FullName) {
            $data = Get-Content -Raw -Encoding UTF8 $tmp.FullName | ConvertFrom-Json
            foreach ($src in @($data.Sources)) {
                foreach ($pkg in @($src.Packages)) {
                    $ids[$pkg.PackageIdentifier] = $true
                }
            }
        }
    } catch {
        Write-Warning "winget export failed ($_) — falling back to per-package check"
    } finally {
        Remove-Item $tmp.FullName -ErrorAction SilentlyContinue
    }
    $script:WingetInstalledCache = $ids
    return $ids
}

function Test-WingetInstalled {
    param([string]$Id)
    return (Get-WingetInstalledIds).ContainsKey($Id)
}

function Install-WingetPackages {
    param([string[]]$Packages)
    foreach ($pkg in $Packages) {
        if ($DryRun) {
            if (Test-WingetInstalled $pkg) {
                Write-Host "would skip (already installed): $pkg"
            } else {
                Write-Host "would winget install: $pkg"
            }
            continue
        }
        if (Test-WingetInstalled $pkg) {
            Write-Host "already installed: $pkg" -ForegroundColor DarkGray
            continue
        }
        if ($PreInstallStopProcess.ContainsKey($pkg)) {
            $procName = $PreInstallStopProcess[$pkg]
            $running = Get-Process -Name $procName -ErrorAction SilentlyContinue
            if ($running) {
                Write-Host "stopping $procName before reinstalling $pkg" -ForegroundColor DarkGray
                $running | Stop-Process -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "winget install: $pkg" -ForegroundColor Cyan
        try {
            & winget install --id $pkg --exact `
                --accept-source-agreements --accept-package-agreements `
                --silent --disable-interactivity
            # Non-zero exit codes include "already installed" — warn and continue.
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "winget install returned exit $LASTEXITCODE for $pkg — continuing"
            }
        } catch {
            Write-Warning "winget install threw for $pkg ($_) — continuing"
        }
    }
}

# --- main ---
$Dotfiles = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$hostProfile = Get-HostProfile

Write-Host "Dotfiles:     $Dotfiles"
Write-Host "Host profile: $hostProfile"
if ($DryRun) { Write-Host "(dry-run — no changes will be made)" -ForegroundColor Yellow }
Write-Host ""

$wingetCommon = Read-PackageList (Join-Path $Dotfiles 'pkg\winget-packages.txt')
Install-WingetPackages $wingetCommon

if ($hostProfile -eq 'metal') {
    $wingetMetal = Read-PackageList (Join-Path $Dotfiles 'pkg\winget-packages.metal.txt')
    Install-WingetPackages $wingetMetal
} else {
    Write-Host ""
    Write-Host "Skipping metal-only manifests (host profile: $hostProfile)" -ForegroundColor DarkGray
    Write-Host "Override with: `$Env:DOTFILES_HOST_PROFILE = 'metal'"
}

# Install Claude Code via official native installer
Write-Host ""
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Host "Claude Code is already installed." -ForegroundColor DarkGray
} elseif ($DryRun) {
    Write-Host "would install Claude Code via native installer"
} else {
    Write-Host "Installing Claude Code..." -ForegroundColor Cyan
    try {
        Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    } catch {
        Write-Warning "Claude Code install failed ($_) — continuing"
    }
}

# Wire global git hooks at ~/.config/git/hooks (deployed from
# xdg-config/common/git/hooks/).
#
# core.hooksPath also ships in the tracked xdg-config/common/git/config, which
# etc/deploy.ps1 links to ~/.config/git/config — so this global write is now only
# a fallback for a box where that link is not there: deploy has not run yet, or
# symlink creation was refused because Developer Mode is off.
#
# Skipping the write when the link exists is not cosmetic. `git config --global`
# falls back to ~/.config/git/config whenever ~/.gitconfig is absent, and git
# rewrites the symlink's *target* — so the write would land in this repo's
# tracked file. The deploy creates ~/.gitconfig to close that hole; this guard
# means the installer never depends on the deploy having done so.
Write-Host ""
$deployedGitConfig = Join-Path $HOME '.config\git\config'
if (Test-Path -LiteralPath $deployedGitConfig) {
    Write-Host "core.hooksPath comes from the deployed ~/.config/git/config — nothing to set." -ForegroundColor DarkGray
} elseif ($DryRun) {
    Write-Host "would set git core.hooksPath -> ~/.config/git/hooks"
} else {
    Write-Host "Setting git core.hooksPath -> ~/.config/git/hooks ..." -ForegroundColor Cyan
    & git config --global core.hooksPath '~/.config/git/hooks'
}

# Install Windows fonts declared in pkg/windows-fonts.txt
$fontsScript = Join-Path $PSScriptRoot 'install-windows-fonts.ps1'
if (Test-Path $fontsScript) {
    Write-Host ""
    try {
        & $fontsScript @PSBoundParameters
    } catch {
        Write-Warning "install-windows-fonts failed ($_) — continuing"
    }
}

# Apply Windows Terminal overlay (xdg-config/windows/windows-terminal/overlay.json)
$wtScript = Join-Path $PSScriptRoot 'wt-apply-settings.ps1'
if (Test-Path $wtScript) {
    Write-Host ""
    try {
        & $wtScript @PSBoundParameters
    } catch {
        Write-Warning "wt-apply-settings failed ($_) — continuing"
    }
}

# Register gh as git's credential helper. `gh auth login` does not always do
# this, leaving `git push` over HTTPS to prompt for a password.
# `gh auth setup-git` is idempotent.
Write-Host ""
if (Get-Command gh -ErrorAction SilentlyContinue) {
    & gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        if ($DryRun) {
            Write-Host "would: gh auth setup-git"
        } else {
            Write-Host "Configuring gh as git credential helper..." -ForegroundColor Cyan
            & gh auth setup-git
        }
    }
}

Write-Host ""
Write-Host "Install complete!" -ForegroundColor Green
