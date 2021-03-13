
# Python ------------------------------------------------------

## Populate Python virtual environments here.

export VENVROOT=~/.envs


# R -----------------------------------------------------------

## Never save R workspace.

alias rns='R --no-save'

## pyenv
export PYENV_ROOT=${HOME}/.pyenv
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi


# pandoc -----------------------------------------------------------

PATH=/Applications/RStudio.app/Contents/MacOS/pandoc:$PATH
