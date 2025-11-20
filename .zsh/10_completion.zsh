for dir in /opt/homebrew/share/zsh-completions /usr/local/share/zsh-completions; do
    [[ -d "$dir" ]] || continue
    fpath=("$dir" $fpath)
done
