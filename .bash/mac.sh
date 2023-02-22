if !(type brew >/dev/null 2>&1); then
    return
fi

if [ "$(uname -m)" = "arm64" ]; then 
    BREW_PREFIX=/opt/homebrew
    eval $(/opt/homebrew/bin/brew shellenv)
else
    BREW_PREFIX=/usr/local
    eval $(/usr/local/bin/brew shellenv)
fi

if [ -e $BREW_PREFIX/Library/Contributions/brew_bash_completion.sh ]; then
    source $BREW_PREFIX/Library/Contributions/brew_bash_completion.sh >/dev/null 2>&1
fi


