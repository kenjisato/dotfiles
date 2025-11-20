if command -v starship > /dev/null 2>&1; then
  return
fi

autoload -Uz colors && colors
autoload -Uz vcs_info

setopt prompt_subst
zstyle ':vcs_info:git:*' check-for-changes true #formats 設定項目で %c,%u が使用可
zstyle ':vcs_info:git:*' stagedstr "%F{green}!" #commit されていないファイルがある
zstyle ':vcs_info:git:*' unstagedstr "%F{magenta}+" #add されていないファイルがある
zstyle ':vcs_info:*' formats "%F{cyan}%c%u(%b)%f" #通常
zstyle ':vcs_info:*' actionformats '[%b|%a]' #rebase 途中,merge コンフリクト等 formats 外の表示

precmd () { vcs_info }

PROMPT='%{$fg[cyan]%}[%n@%m]%{$reset_color%}'
PROMPT=$PROMPT'${vcs_info_msg_0_} %{${fg[cyan]}%}%}%%%{${reset_color}%} '

RPROMPT='%{${fg[cyan]}%}[%(5~,%-2~/.../%2~,%~)]%{${reset_color}%}'
