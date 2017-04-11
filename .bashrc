# Adapted from https://github.com/b4b4r07/dotfiles/blob/master/.bashrc

[ -z "$PS1" ] && return
[ -n "$VIMRUNTIME" ] && return

if [ -z "$DOTPATH" ]; then
    echo "cannot start $SHELL, \$DOTPATH not set" 1>&2
    return 1
fi

export PATH=~/bin:"$PATH"


if type brew >/dev/null 2>&1; then
    BREW_PREFIX=$(brew --prefix)
    if [ -e $BREW_PREFIX/Library/Contributions/brew_bash_completion.sh ]; then
        source $BREW_PREFIX/Library/Contributions/brew_bash_completion.sh >/dev/null 2>&1
    fi
fi

