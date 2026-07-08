export PATH=/usr/local/bin:$PATH
# Locale: set only LANG. Do NOT export LC_ALL from a profile — it hard-overrides
# every category and prints "setlocale: cannot change locale" on any machine
# where the locale is not generated (typically a fresh WSL distro). Generate the
# locale at the OS level instead — see dotfiles-private docs/howto/wsl-locale.md.
export LANG="en_US.UTF-8"

export PATH=~/bin:~/.local/bin:"$PATH"

export GOPATH=$HOME/.go

# Conda initialization
if command -v conda > /dev/null 2>&1; then
  __conda_setup="$(conda 'shell.bash' 'hook' 2> /dev/null)"
  if [ $? -eq 0 ]; then
      eval "$__conda_setup"
  fi
  unset __conda_setup
fi

. "$HOME/.cargo/env"
