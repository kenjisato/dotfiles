if command -v ghq > /dev/null 2>&1 && command -v peco > /dev/null 2>&1; then
    peco-src () {
        local selected_dir=$(ghq list --full-path | peco --query "$LBUFFER")
        if [ -n "$selected_dir" ]; then
            BUFFER="cd ${selected_dir}"
            zle accept-line
        fi
        zle clear-screen
    }
    zle -N peco-src
    bindkey '^]' peco-src
fi
