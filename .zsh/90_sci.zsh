
# Python ------------------------------------------------------

## Populate Python virtual environments here.
export VENVROOT=~/.envs

## pyenv
export PYENV_ROOT=/usr/local/var/pyenv
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

## Workaround for brew doctor showing many conflicting -config files.
alias brew="PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin brew"

# pandoc -----------------------------------------------------------

PATH=/Applications/RStudio.app/Contents/MacOS/pandoc:$PATH
