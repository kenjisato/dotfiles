# Adapted from https://github.com/b4b4r07/dotfiles/blob/master/.bashrc

[ -z "$PS1" ] && return
[ -n "$VIMRUNTIME" ] && return

if type brew >/dev/null 2>&1; then
    BREW_PREFIX=$(brew --prefix)
    if [ -e $BREW_PREFIX/Library/Contributions/brew_bash_completion.sh ]; then
        source $BREW_PREFIX/Library/Contributions/brew_bash_completion.sh >/dev/null 2>&1
    fi
fi

PS1="\[\e[34m\]\u\[\e[1;32m\]@\[\e[0;33m\]\h\[\e[35m\]:"
PS1="$PS1\[\e[m\]\w\[\e[1;31m\]> \[\e[0m\]"

VENVROOT=~/.envs

if type pyenv > /dev/null 2>&1; then
  export PYENV_ROOT="$HOME/.pyenv"
  eval "$(pyenv init -)"
fi

if type starship > /dev/null 2>&1; then
  eval "$(starship init bash)"
fi

