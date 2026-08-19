# Tell lazygit where its config is, on every OS.
#
# lazygit reads ~/.config/lazygit/config.yml only where that is its native
# config home; on macOS it reads ~/Library/Application Support/lazygit, which
# etc/deploy does not link. Naming the deployed file explicitly keeps one
# tracked config in play everywhere.
#
# The value is a comma-separated list that lazygit merges left to right, later
# entries winning — that is how an untracked per-machine file joins in. Every
# listed file must exist: a missing one aborts lazygit before the UI opens
# ("stat ...: no such file or directory"), so both are guarded.
if [ -f "$HOME/.config/lazygit/config.yml" ]; then
    LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml"
    if [ -f "$HOME/.config/lazygit/config.local.yml" ]; then
        LG_CONFIG_FILE="$LG_CONFIG_FILE,$HOME/.config/lazygit/config.local.yml"
    fi
    export LG_CONFIG_FILE
fi
