# compinit's "insecure directories" prompt is avoided by keeping the Homebrew
# completion dirs non-group-writable — etc/install strips the group-write bit
# from "$(brew --prefix)/share" so no fpath entry is flagged. (ZSH_DISABLE_COMPFIX
# used to live here, but it is an oh-my-zsh-only variable and a no-op under plain
# zsh, so it never actually suppressed anything.) The zshrc call also passes -i.

# Locale: set only LANG. Do NOT export LC_ALL from a profile — it hard-overrides
# every category and prints "setlocale: cannot change locale" on any machine
# where the locale is not generated (typically a fresh WSL distro). Generate the
# locale at the OS level instead — see dotfiles-private docs/howto/wsl-locale.md.
export LANG="en_US.UTF-8"

# Go: deliberately no GOPATH/GOBIN. Since Go 1.8 an unset GOPATH defaults to
# ~/go, and since modules (1.11, default from 1.16) it only names the module
# cache (~/go/pkg/mod) and the `go install` target (~/go/bin) — src/ is unused.
# Leaving it unset keeps us on the default every Go tool's README assumes, so
# only ~/go/bin needs to be on PATH (added at the tail below).

typeset -gx -U path
path=( \
    /opt/homebrew/bin(N-/) \
    /opt/homebrew/sbin(N-/) \
    /usr/local/bin(N-/) \
    /usr/local/sbin(N-/) \
    /home/linuxbrew/.linuxbrew/bin(N-/) \
    /home/linuxbrew/.linuxbrew/sbin(N-/) \
    ~/bin(N-/) \
    ~/.local/bin(N-/) \
    ~/.zplug/bin(N-/) \
    ~/.tmux/bin(N-/) \
    ~/Library/TinyTeX/bin/*(N-/) \
    ~/.TinyTeX/bin/*(N-/) \
    "$path[@]" \
    ~/go/bin(N-/) \
    )

typeset -gx -U fpath
fpath=( \
    ~/.zsh/Completion(N-/) \
    ~/.zsh/functions(N-/) \
    ~/.zsh/plugins/zsh-completions(N-/) \
    ${XDG_CONFIG_HOME:-$HOME/.config}/zsh/completions(N-/) \
    /opt/homebrew/share/zsh/site-functions(N-/) \
    /usr/local/share/zsh/site-functions(N-/) \
    /home/linuxbrew/.linuxbrew/share/zsh/site-functions(N-/) \
    /opt/homebrew/share/zsh-completions(N-/) \
    /usr/local/share/zsh-completions(N-/) \
    /home/linuxbrew/.linuxbrew/share/zsh-completions(N-/) \
    $fpath \
    )

# [[ -f ~/.zprofile ]] && source ~/.zprofile

[[ -f ~/.secret ]] && source ~/.secret
[[ -f ~/.cargo/env ]] && source ~/.cargo/env
