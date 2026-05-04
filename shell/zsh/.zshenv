# Suppress compinit's "insecure directories" prompt globally. /opt/homebrew/share
# is group-writable by design (admin members can brew install/upgrade without
# sudo), and on multi-user machines that's the right tradeoff. Set this in
# .zshenv so it applies even to non-interactive zsh invocations spawned by
# tools like Claude Code's shell snapshot, where the prompt would otherwise
# block stdin. The zshrc still uses `compinit -C -i` for its own call.
export ZSH_DISABLE_COMPFIX=true

export LANGUAGE="en_US.UTF-8"
export LANG="${LANGUAGE}"
export LC_ALL="${LANGUAGE}"
export LC_CTYPE="${LANGUAGE}"

# Settings for golang
export GOPATH="$HOME/local"
export GOBIN="$GOPATH/bin"

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
    "$path[@]" \
    "$GOBIN" \
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
