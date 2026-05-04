setopt extended_glob

# Run compinit *before* sourcing user snippets so they can rely on compdef
# being defined. (Otherwise tools that autoload bash compinit could trip the
# insecure-dirs prompt without the -i flag.)
if [[ -o interactive ]]; then
  autoload -Uz compinit
  zcomp_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
  mkdir -p "${zcomp_cache}"
  # -i: silently skip insecure fpath entries instead of prompting. Needed
  # because /opt/homebrew/share is intentionally group-writable so brew can
  # install/upgrade without sudo, which compinit otherwise flags.
  compinit -C -i -d "${zcomp_cache}/zcompdump"
fi

for f in ~/.zsh/[0-9]*.(sh|zsh); do
    source "$f"
done

if command -v starship > /dev/null 2>&1; then
  export VIRTUAL_ENV_DISABLE_PROMPT=1
  eval "$(starship init zsh)"
fi

# Shared bash/zsh snippets (e.g. cdb)
for f in ~/.shell/*.sh; do
    [ -r "$f" ] && source "$f"
done
unset f
