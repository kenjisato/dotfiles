# help: Ctrl+] - jump to a ghr-managed repository with fzf
if command -v ghr > /dev/null 2>&1 && command -v fzf > /dev/null 2>&1; then
    fzf-src () {
        local selected dir
        selected=$(ghr list | fzf --query "$LBUFFER")
        if [ -n "$selected" ]; then
            dir=$(ghr path "$selected")
            BUFFER="cd ${(q)dir}"
            zle accept-line
        fi
        zle clear-screen
    }
    zle -N fzf-src
    bindkey '^]' fzf-src
fi

# cdb (bash/zsh shared) lives under ~/.shell/ — sourced by .zshrc.
