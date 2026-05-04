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

function Install-WingetPackages {
    param([string[]]$Packages)
    foreach ($pkg in $Packages) {
        if ($DryRun) { Write-Host "would winget install: $pkg"; continue }
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

Write-Host ""
Write-Host "Install complete!" -ForegroundColor Green
