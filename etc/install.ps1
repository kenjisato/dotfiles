# etc/install.ps1 — Windows installer (public dotfiles).
#
# Installs scoop + scoop packages + winget packages declared under pkg/.
# Manifests with the .metal.txt suffix are applied only on bare-metal hosts;
# Parallels VMs skip them because the host Mac already has those tools.
#
# Host detection:
#   $Env:DOTFILES_HOST_PROFILE overrides everything (values: parallels|metal).
#   Otherwise: presence of the prl_tools_service service => parallels.
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
    # WMI Manufacturer / Model is stable across Parallels Desktop versions.
    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        if ($cs.Manufacturer -like '*Parallels*' -or $cs.Model -like '*Parallels*') {
            return 'parallels'
        }
    } catch {}
    # Fallback: any prl_* service (newer Parallels versions sometimes rename
    # prl_tools_service).
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

function Install-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "scoop: already installed"
        return
    }
    if ($DryRun) { Write-Host "would install scoop"; return }
    Write-Host "Installing scoop..." -ForegroundColor Cyan
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
}

function Add-ScoopBuckets {
    param([string[]]$Buckets)
    if ($DryRun) {
        foreach ($bucket in $Buckets) { Write-Host "would ensure scoop bucket: $bucket" }
        return
    }
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Warning "scoop not on PATH — skipping bucket setup"
        return
    }
    $existing = (& scoop bucket list 2>$null | Out-String)
    foreach ($bucket in $Buckets) {
        if ($existing -match "(?m)^\s*$bucket\b") {
            Write-Host "scoop bucket: $bucket (already added)"
            continue
        }
        Write-Host "Adding scoop bucket: $bucket" -ForegroundColor Cyan
        & scoop bucket add $bucket
    }
}

function Install-ScoopPackages {
    param([string[]]$Packages)
    if (-not $DryRun -and -not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        if ($Packages.Count -gt 0) {
            Write-Warning "scoop not on PATH — skipping scoop packages"
        }
        return
    }
    foreach ($pkg in $Packages) {
        if ($DryRun) { Write-Host "would scoop install: $pkg"; continue }
        Write-Host "scoop install: $pkg" -ForegroundColor Cyan
        & scoop install $pkg
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "scoop install failed for $pkg (exit $LASTEXITCODE) — continuing"
        }
    }
}

function Install-WingetPackages {
    param([string[]]$Packages)
    foreach ($pkg in $Packages) {
        if ($DryRun) { Write-Host "would winget install: $pkg"; continue }
        Write-Host "winget install: $pkg" -ForegroundColor Cyan
        & winget install --id $pkg --exact `
            --accept-source-agreements --accept-package-agreements `
            --silent --disable-interactivity
        # Non-zero exit codes include "already installed" — warn and continue.
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "winget install returned exit $LASTEXITCODE for $pkg — continuing"
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

Install-Scoop
Add-ScoopBuckets -Buckets @('extras', 'nerd-fonts')

$scoopCommon  = Read-PackageList (Join-Path $Dotfiles 'pkg\scoop-packages.txt')
$wingetCommon = Read-PackageList (Join-Path $Dotfiles 'pkg\winget-packages.txt')

Install-ScoopPackages  $scoopCommon
Install-WingetPackages $wingetCommon

if ($hostProfile -eq 'metal') {
    $scoopMetal  = Read-PackageList (Join-Path $Dotfiles 'pkg\scoop-packages.metal.txt')
    $wingetMetal = Read-PackageList (Join-Path $Dotfiles 'pkg\winget-packages.metal.txt')
    Install-ScoopPackages  $scoopMetal
    Install-WingetPackages $wingetMetal
} else {
    Write-Host ""
    Write-Host "Skipping metal-only manifests (host profile: $hostProfile)" -ForegroundColor DarkGray
    Write-Host "Override with: `$Env:DOTFILES_HOST_PROFILE = 'metal'"
}

Write-Host ""
Write-Host "Install complete!" -ForegroundColor Green
Write-Host "Open a new PowerShell session so scoop's PATH updates take effect."
