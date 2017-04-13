for f in ~/.zsh/[0-9]*.(sh|zsh); do
    source "$f"
done


function peco-src () {
    local selected_dir=$(ghq list --full-path | peco --query "$LBUFFER")
    if [ -n "$selected_dir" ]; then
        BUFFER="cd ${selected_dir}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N peco-src
bindkey '^]' peco-src

function rstudio () {
    local selected_dir=$(ghq list --full-path | peco --query "$LBUFFER")
    if [ -n "$selected_dir" ]; then
        BUFFER="cd ${selected_dir} && open -a RStudio ."
        zle accept-line
    fi
    zle clear-screen
}
zle -N rstudio
