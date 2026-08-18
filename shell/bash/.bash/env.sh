# Environment (PATH, locale, toolchain init) shared by BOTH
# ~/.bash_profile (login shells) and ~/.bashrc (everything else).
#
# Why this file exists: bash reads ~/.bash_profile only for *login* shells.
# Desktop terminal emulators (lxterminal, gnome-terminal, konsole, ...) spawn a
# NON-login interactive shell, which reads only ~/.bashrc — so anything defined
# solely in ~/.bash_profile is invisible in a terminal window. Keeping the
# environment here and sourcing it from both files makes the two paths agree.
#
# This file is sourced twice in an interactive login shell (profile, then rc),
# and again by every nested shell, so every mutation below must be idempotent.

# Locale: set only LANG. Do NOT export LC_ALL from a profile — it hard-overrides
# every category and prints "setlocale: cannot change locale" on any machine
# where the locale is not generated (typically a fresh WSL distro). Generate the
# locale at the OS level instead: sudo locale-gen en_US.UTF-8 && sudo update-locale
export LANG="en_US.UTF-8"

# Go: deliberately no GOPATH/GOBIN. Since Go 1.8 an unset GOPATH defaults to
# ~/go, and since modules (1.11, default from 1.16) it only names the module
# cache (~/go/pkg/mod) and the `go install` target (~/go/bin) — src/ is unused.
# Leaving it unset keeps us on the default every Go tool's README assumes, so
# only ~/go/bin needs to be on PATH (added at the tail below).

# Build the front of PATH in priority order, mirroring shell/zsh/.zshenv.
# Missing dirs and dirs already on PATH are skipped, which is what makes
# re-sourcing a no-op instead of a slowly growing PATH.
_dotfiles_head=""
_dotfiles_add_path() {
    [ -d "$1" ] || return 0
    case ":$_dotfiles_head:$PATH:" in
        *":$1:"*) return 0 ;;
    esac
    _dotfiles_head="${_dotfiles_head:+$_dotfiles_head:}$1"
}

_dotfiles_add_path /opt/homebrew/bin              # Homebrew (Apple Silicon)
_dotfiles_add_path /opt/homebrew/sbin
_dotfiles_add_path /usr/local/bin                 # Homebrew (Intel macOS)
_dotfiles_add_path /usr/local/sbin
_dotfiles_add_path /home/linuxbrew/.linuxbrew/bin # Linuxbrew
_dotfiles_add_path /home/linuxbrew/.linuxbrew/sbin
_dotfiles_add_path "$HOME/bin"                    # managed by etc/deploy
_dotfiles_add_path "$HOME/.local/bin"             # uv, pipx, claude, ...
_dotfiles_add_path "$HOME/.tmux/bin"
# TinyTeX installs under a versioned bin/<platform>/ subdirectory.
for _d in "$HOME"/Library/TinyTeX/bin/*/ "$HOME"/.TinyTeX/bin/*/; do
    _dotfiles_add_path "${_d%/}"
done
unset _d

PATH="${_dotfiles_head:+$_dotfiles_head:}$PATH"
# `go install` output goes at the tail — same as shell/zsh/.zshenv.
case ":$PATH:" in
    *":$HOME/go/bin:"*) ;;
    *) [ -d "$HOME/go/bin" ] && PATH="$PATH:$HOME/go/bin" ;;
esac
export PATH

unset _dotfiles_head
unset -f _dotfiles_add_path

# Rust. ~/.cargo/env prepends ~/.cargo/bin and skips itself if already applied.
[ -r "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Conda, when installed. The hook is a no-op if conda is not on PATH.
if command -v conda > /dev/null 2>&1; then
    __conda_setup="$(conda 'shell.bash' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    fi
    unset __conda_setup
fi
