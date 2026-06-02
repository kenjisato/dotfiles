# etc/install-windows-fonts.ps1 — install fonts declared in pkg/windows-fonts.txt
#
# Per-user font install (no admin required, Windows 10 1809+):
#   files     -> %LOCALAPPDATA%\Microsoft\Windows\Fonts\
#   registry  -> HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts
#
# Idempotent: skips fonts already registered to the same path.
#
# Usage:
#   pwsh -File etc\install-windows-fonts.ps1            # apply
#   pwsh -File etc\install-windows-fonts.ps1 -DryRun    # preview
#   pwsh -File etc\install-windows-fonts.ps1 -Manifest <path>  # custom manifest

[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$Manifest
)

$ErrorActionPreference = 'Stop'

$Dotfiles = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $Manifest) { $Manifest = Join-Path $Dotfiles 'pkg\windows-fonts.txt' }

if (-not (Test-Path $Manifest)) {
    Write-Host "no font manifest at $Manifest — skipping" -ForegroundColor DarkGray
    return
}

$FontsDir = Join-Path $Env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$RegPath  = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

if (-not $DryRun) {
    if (-not (Test-Path $FontsDir)) { New-Item -ItemType Directory -Path $FontsDir -Force | Out-Null }
    if (-not (Test-Path $RegPath))  { New-Item -Path $RegPath -Force | Out-Null }
}

function Get-FontRegistryName {
    # Best-effort registry display name derived from filename.
    # The actual font face exposed to apps comes from the file's internal
    # 'name' table — this string just needs to be unique within the registry.
    # Suffix follows the convention Windows uses for double-click installs:
    # .ttf -> (TrueType), .otf -> (OpenType).
    param([string]$FileName)
    $base   = [IO.Path]::GetFileNameWithoutExtension($FileName)
    $suffix = if ([IO.Path]::GetExtension($FileName).ToLowerInvariant() -eq '.otf') {
        '(OpenType)'
    } else {
        '(TrueType)'
    }
    return ($base -replace '-', ' ') + " $suffix"
}

function Install-FontFile {
    param([string]$Src)
    $name    = Split-Path -Leaf $Src
    $dst     = Join-Path $FontsDir $name
    $regName = Get-FontRegistryName $name

    # On first install the registry value doesn't exist yet. Use
    # Get-ItemPropertyValue + try/catch instead of (Get-ItemProperty ...).$X —
    # the latter raises "property cannot be found on this object" when the
    # value is missing, which $ErrorActionPreference='Stop' then turns into
    # a terminating error.
    $existing = try {
        Get-ItemPropertyValue -Path $RegPath -Name $regName -ErrorAction Stop
    } catch { $null }

    if ((Test-Path $dst) -and ($existing -eq $dst)) {
        Write-Host "  already installed: $name" -ForegroundColor DarkGray
        return
    }
    if ($DryRun) {
        Write-Host "  would install: $name"
        return
    }
    Copy-Item $Src $dst -Force
    New-ItemProperty -Path $RegPath -Name $regName -Value $dst -PropertyType String -Force | Out-Null
    Write-Host "  installed: $name" -ForegroundColor Green
}

function Show-RegisteredFonts {
    # Prints a table of fonts registered under HKCU and located in $FontsDir,
    # with each TTF's internal family name (the value to use as 'face' in
    # Windows Terminal / starship / etc.). Helps avoid the cycle of "the face
    # name in my config doesn't match what Windows actually has".
    if (-not (Test-Path $RegPath)) { return }
    try { Add-Type -AssemblyName PresentationCore -ErrorAction Stop } catch { return }

    $entries = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue
    if (-not $entries) { return }

    $rows = $entries.PSObject.Properties |
        Where-Object {
            -not $_.Name.StartsWith('PS') -and
            $_.Value -is [string] -and
            $_.Value.StartsWith($FontsDir, [StringComparison]::OrdinalIgnoreCase)
        } |
        Sort-Object Name |
        ForEach-Object {
            $path = $_.Value
            $family = '?'
            if (Test-Path $path) {
                try {
                    $gtf = New-Object Windows.Media.GlyphTypeface ($path)
                    $family = ($gtf.Win32FamilyNames.Values | Select-Object -First 1)
                } catch { }
            }
            [pscustomobject]@{
                File   = Split-Path -Leaf $path
                Family = $family
            }
        }

    if ($rows) {
        Write-Host ""
        Write-Host "Registered per-user fonts (use 'Family' as the 'face' value in WT / starship):" -ForegroundColor Cyan
        $rows | Format-Table -AutoSize | Out-Host
    }
}

function Get-FontFilesFromArchive {
    param([string]$ArchiveDir, [string]$FontGlob)
    Get-ChildItem -Path $ArchiveDir -Recurse | Where-Object {
        $_.Name -like $FontGlob -and
        ($_.Extension.ToLowerInvariant() -in '.ttf', '.otf')
    }
}

function Install-FontFromGitHub {
    param(
        [string]$Repo,
        [string]$AssetGlob,
        [string]$FontGlob
    )
    Write-Host "Source: $Repo  asset=$AssetGlob  font=$FontGlob" -ForegroundColor Cyan
    # Use `gh api` rather than a raw Invoke-RestMethod: gh is a hard dependency
    # here, and it supplies the auth token automatically, lifting the API rate
    # limit from 60/hr (unauthenticated, per IP) to 5000/hr.
    $json = & gh api "repos/$Repo/releases/latest" 2>$null | Out-String
    if ($LASTEXITCODE -ne 0 -or -not $json.Trim()) {
        Write-Warning "gh api failed for $Repo (not authenticated? run 'gh auth login') — skipping"
        return
    }
    $rel = $json | ConvertFrom-Json
    $asset = $rel.assets | Where-Object { $_.name -like $AssetGlob } | Select-Object -First 1
    if (-not $asset) {
        Write-Warning "no asset matching '$AssetGlob' in $Repo $($rel.tag_name) — skipping"
        return
    }
    Write-Host "  release $($rel.tag_name) -> $($asset.name)"

    if ($DryRun) {
        Write-Host "  would download $($asset.browser_download_url) and install fonts matching '$FontGlob'"
        return
    }

    $tmpDir = New-Item -ItemType Directory -Path (Join-Path $Env:TEMP "windows-fonts-$([guid]::NewGuid().ToString('N'))")
    try {
        $zipPath = Join-Path $tmpDir $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $tmpDir -Force

        $fonts = Get-FontFilesFromArchive -ArchiveDir $tmpDir -FontGlob $FontGlob
        if (-not $fonts) {
            Write-Warning "no font files matching '$FontGlob' inside $($asset.name) — skipping"
            return
        }
        foreach ($f in $fonts) { Install-FontFile $f.FullName }
    } finally {
        Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Some font repos (e.g. trueroad/HaranoAjiFonts) ship via git tags only —
# no release assets. For those we pull the auto-generated tag archive zip
# from `archive/refs/tags/<tag>.zip`.
function Install-FontFromGitHubTag {
    param(
        [string]$Repo,
        [string]$FontGlob
    )
    Write-Host "Source: $Repo  tag-archive  font=$FontGlob" -ForegroundColor Cyan
    # `gh api` for the auth token (see Install-FontFromGitHub) — lifts the rate limit.
    $json = & gh api "repos/$Repo/tags?per_page=1" 2>$null | Out-String
    if ($LASTEXITCODE -ne 0 -or -not $json.Trim()) {
        Write-Warning "gh api failed for $Repo (not authenticated? run 'gh auth login') — skipping"
        return
    }
    $tags = $json | ConvertFrom-Json
    if (-not $tags -or $tags.Count -eq 0) {
        Write-Warning "no tags in $Repo — skipping"
        return
    }
    $tag = $tags[0].name
    $url = "https://github.com/$Repo/archive/refs/tags/$tag.zip"
    Write-Host "  tag $tag -> archive zip"

    if ($DryRun) {
        Write-Host "  would download $url and install fonts matching '$FontGlob'"
        return
    }

    $tmpDir = New-Item -ItemType Directory -Path (Join-Path $Env:TEMP "windows-fonts-$([guid]::NewGuid().ToString('N'))")
    try {
        $zipPath = Join-Path $tmpDir "$tag.zip"
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $tmpDir -Force

        $fonts = Get-FontFilesFromArchive -ArchiveDir $tmpDir -FontGlob $FontGlob
        if (-not $fonts) {
            Write-Warning "no font files matching '$FontGlob' inside $tag — skipping"
            return
        }
        foreach ($f in $fonts) { Install-FontFile $f.FullName }
    } finally {
        Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- main ---

Get-Content $Manifest | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    $parts = $line -split ':', 3
    if ($parts.Count -ne 3) {
        Write-Warning "invalid manifest line (expected owner/repo:asset-glob:font-glob): $line"
        return
    }
    if ($parts[1] -eq '@tag') {
        Install-FontFromGitHubTag -Repo $parts[0] -FontGlob $parts[2]
    } else {
        Install-FontFromGitHub -Repo $parts[0] -AssetGlob $parts[1] -FontGlob $parts[2]
    }
}

Show-RegisteredFonts

Write-Host ""
Write-Host "Note: newly installed fonts may not appear until apps are restarted." -ForegroundColor DarkGray
