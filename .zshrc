setopt extended_glob

for f in ~/.zsh/[0-9]*.(sh|zsh); do
    source "$f"
done

if [[ -o interactive ]]; then
  autoload -Uz compinit
  zcomp_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
  mkdir -p "${zcomp_cache}"
  compinit -C -d "${zcomp_cache}/zcompdump"
fi

if command -v starship > /dev/null 2>&1; then
  export VIRTUAL_ENV_DISABLE_PROMPT=1
  eval "$(starship init zsh)"
fi
