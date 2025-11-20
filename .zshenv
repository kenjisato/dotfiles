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
    /opt/homebrew/share/zsh/site-functions(N-/) \
    /usr/local/share/zsh/site-functions(N-/) \
    /opt/homebrew/share/zsh-completions(N-/) \
    /usr/local/share/zsh-completions(N-/) \
    $fpath \
    )

# [[ -f ~/.zprofile ]] && source ~/.zprofile

[[ -f ~/.secret ]] && source ~/.secret
[[ -f ~/.cargo/env ]] && source ~/.cargo/env
