# Editor
export EDITOR=nvim
export CVSEDITOR="${EDITOR}"
export SVN_EDITOR="${EDITOR}"
export GIT_EDITOR="${EDITOR}"

alias vim=nvim
# macOS の /usr/bin/view (vim) は tmux 内でシンタックスハイライトが効かないので
# 読み取り専用も nvim に寄せる。`nvim -R` は vim の `view` と同じ意味。
alias view='nvim -R'

