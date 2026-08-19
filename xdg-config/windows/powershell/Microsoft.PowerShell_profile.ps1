# PowerShell profile (Windows / pwsh).
#
# Deployed by etc/deploy.ps1 to $PROFILE
# (typically $HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1).

# UTF-8 everywhere — fixes mojibake for Japanese filenames and command output.
# Use UTF8Encoding($false) (no BOM); [Encoding]::UTF8 emits a BOM that gets
# injected at the head of pipes to native commands.
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom
[Console]::InputEncoding  = $utf8NoBom
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
    # vim/view を nvim に寄せる (bash/zsh 側の alias と揃える)。
    # Set-Alias は引数を持てず view の -R を表現できないので、両方とも関数にする。
    # `nvim -R` は vim の `view` と同じ読み取り専用モード。
    function vim  { nvim @args }
    function view { nvim -R @args }
} elseif (Get-Command code -ErrorAction SilentlyContinue) {
    $Env:EDITOR = 'code -w'
}

# Common navigation aliases (functions, since PowerShell aliases can't take args).
function ll { Get-ChildItem -Force @args }
function la { Get-ChildItem -Force -Hidden @args }
function ..  { Set-Location .. }
function ... { Set-Location ../.. }
function g  { git @args }

# Set the current psmux pane's title (shown in status-right via #{pane_title}).
# Useful for distinguishing multiple Claude Code panes — e.g. `Set-PaneTitle projA`.
function Set-PaneTitle {
    param([Parameter(Mandatory)][string]$Title)
    if (-not $env:TMUX) {
        Write-Warning "Not inside psmux/tmux — pane title not set."
        return
    }
    psmux select-pane -T $Title
}

# Starship prompt — falls back to default prompt if not installed.
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}

# lazygit — name the deployed config explicitly.
#
# On Windows lazygit's config home is %LOCALAPPDATA%\lazygit, which nothing
# links, so point it at the file etc/deploy.ps1 puts under ~/.config. Mirrors
# ~/.shell/lazygit.sh on the Unix side, including the two rules that matter: the
# value is a comma-separated list lazygit merges left to right, which is how a
# machine-local file joins in, and every listed file must exist — a missing one
# aborts lazygit before its UI opens.
#
# This reaches PowerShell sessions only. lazygit started from cmd, Git Bash or a
# shortcut falls back to %LOCALAPPDATA% and its own defaults; promote this to a
# user environment variable if that ever matters.
$lazygitConfig = Join-Path $HOME '.config\lazygit\config.yml'
if (Test-Path -LiteralPath $lazygitConfig) {
    $lazygitLocal = Join-Path $HOME '.config\lazygit\config.local.yml'
    if (Test-Path -LiteralPath $lazygitLocal) {
        $Env:LG_CONFIG_FILE = "$lazygitConfig,$lazygitLocal"
    } else {
        $Env:LG_CONFIG_FILE = $lazygitConfig
    }
}

# Personal env hooks.
$Env:ZM_HOME = "$HOME/.zm"

# Local overlay: an untracked profile.local.ps1 next to $PROFILE, if present.
$localProfile = Join-Path (Split-Path $PROFILE) 'profile.local.ps1'
if (Test-Path $localProfile) {
    . $localProfile
}
