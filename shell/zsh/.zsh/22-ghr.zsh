# ghr — repository manager.
#
# Completion: ghr ships its completion as a bash script that detects
# ZSH_VERSION and uses bashcompinit, so the same eval works in both shells.
#
# `ghr cd`: ghr's bash extension uses bash-only ${@:2} syntax, so we
# hand-roll a small wrapper instead. ghr's native binary prints
# "Shell extension is not configured correctly" when `cd` is called
# without a shell-side wrapper.
if command -v ghr > /dev/null 2>&1; then
    eval "$(ghr shell bash --completion)"

    ghr() {
        if [ "$1" = "cd" ] && [ "$#" -ge 2 ]; then
            shift
            local dir
            dir=$(command ghr path "$@") || return
            cd "$dir"
        else
            command ghr "$@"
        fi
    }
fi
