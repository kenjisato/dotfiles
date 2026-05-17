# PowerShell profile (Windows / pwsh).
#
# Deployed by etc/deploy.ps1 to $PROFILE
# (typically $HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1).

# UTF-8 everywhere — fixes mojibake for Japanese filenames and command output.
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$Env:PYTHONUTF8 = '1'

# PSReadLine — emacs-ish keys + history search via up/down arrows.
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -EditMode Emacs
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete

    # Ctrl+] — jump to a ghq-managed repo via fzf (mirrors shell/zsh/.zsh/20-fzf.zsh).
    function Invoke-FzfGhq {
        $selected = ghq list --full-path | fzf --query "$($null)"
        if ($selected) {
            Set-Location $selected
            [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
        }
    }
    Set-PSReadLineKeyHandler -Chord 'Ctrl+]' -ScriptBlock {
        Invoke-FzfGhq
    }
}

# Add ~/bin and ~/.local/bin to PATH (matches the bash/zsh setup;
# Claude Code's native installer places claude.exe under ~/.local/bin).
foreach ($dir in @(
    (Join-Path $HOME 'bin'),
    (Join-Path $HOME '.local\bin')
)) {
    if ((Test-Path $dir) -and ($Env:PATH -notlike "*$dir*")) {
        $Env:PATH = "$dir;$Env:PATH"
    }
}

# Reload PATH from registry then re-apply this profile — refreshenv alone
# would clobber the ~/bin / ~/.local/bin additions above.
function Reload-Env {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
    . $PROFILE
}

# Editor preference — Neovim, then VS Code.
if (Get-Command nvim -ErrorAction SilentlyContinue) {
    $Env:EDITOR = 'nvim'
} elseif (Get-Command code -ErrorAction SilentlyContinue) {
    $Env:EDITOR = 'code -w'
}

# Common navigation aliases (functions, since PowerShell aliases can't take args).
function ll { Get-ChildItem -Force @args }
function la { Get-ChildItem -Force -Hidden @args }
function ..  { Set-Location .. }
function ... { Set-Location ../.. }
function g  { git @args }

# Starship prompt — falls back to default prompt if not installed.
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}

# Personal env hooks.
$Env:ZM_HOME = "$HOME/.zm"

# Local overlay (e.g. from dotfiles-private deploy step).
$localProfile = Join-Path (Split-Path $PROFILE) 'profile.local.ps1'
if (Test-Path $localProfile) {
    . $localProfile
}
