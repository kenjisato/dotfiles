# help: Ctrl+] - jump to a ghq-managed repository with fzf
if command -v ghq > /dev/null 2>&1 && command -v fzf > /dev/null 2>&1; then
    fzf-src () {
        local dir
        dir=$(ghq list -p | fzf --query "$LBUFFER")
        if [ -n "$dir" ]; then
            BUFFER="cd ${(q)dir}"
            zle accept-line
        fi
        zle clear-screen
    }
    zle -N fzf-src
    bindkey '^]' fzf-src
fi

# cdb (bash/zsh shared) lives under ~/.shell/ — sourced by .zshrc.
