export PATH=/usr/local/bin:$PATH
export LANGUAGE="en_US.UTF-8"
export LANG="${LANGUAGE}"
export LC_ALL="${LANGUAGE}"
export LC_CTYPE="${LANGUAGE}"

export PATH=~/bin:"$PATH"

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
