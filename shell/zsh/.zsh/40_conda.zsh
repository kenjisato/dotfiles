# Conda initialization (kept here to avoid auto-editing .zshrc)
if command -v conda > /dev/null 2>&1; then
  __conda_setup="$(conda 'shell.zsh' 'hook' 2> /dev/null)"
  if [ $? -eq 0 ]; then
      eval "$__conda_setup"
  fi
  unset __conda_setup
fi
