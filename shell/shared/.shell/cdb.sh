# cdb - cd to a bookmarked directory.
# Sourced by both zsh and bash.
#
#   cdb                              fzf picker, cd to selection
#   cdb <name>                       cd directly to bookmark <name>
#   cdb /add <name> [desc] [--dir]   add bookmark to local file (defaults to cwd)
#   cdb /rm  [name]                  remove bookmark (fzf picker if no name)
#   cdb /list                        list all bookmarks
#
# Reads ~/.config/cdmarks.tsv (public) and ~/.config/cdmarks.local.tsv (private
# overlay). Local entries shadow public ones with the same name. /add writes to
# the local file so personal bookmarks don't dirty the public dotfiles repo.

_cdb_cat() {
    local public="${HOME}/.config/cdmarks.tsv"
    local private="${HOME}/.config/cdmarks.local.tsv"
    { [ -f "$private" ] && cat "$private"; [ -f "$public" ] && cat "$public"; } \
        | awk -F '\t' '!seen[$1]++'
}

cdb() {
    local public="${HOME}/.config/cdmarks.tsv"
    local private="${HOME}/.config/cdmarks.local.tsv"

    case "${1:-}" in
        /add)
            shift
            local name="${1:-}"
            if [ -z "$name" ]; then
                echo "usage: cdb /add <name> [description] [--dir path]" >&2
                return 1
            fi
            shift
            local dir="$PWD" desc=""
            while [ $# -gt 0 ]; do
                case "$1" in
                    --dir) dir="${2:?--dir requires a path}"; shift 2 ;;
                    *)     desc="$1"; shift ;;
                esac
            done
            dir="${dir/#$HOME/~}"
            printf '%s\t%s\t%s\n' "$name" "$dir" "$desc" >> "$private"
            echo "cdb: added '$name' -> $dir  (in $private)"
            ;;
        /rm)
            local name="${2:-}" tmp file removed=0
            if [ -z "$name" ]; then
                if ! command -v fzf > /dev/null 2>&1; then
                    echo "cdb: fzf not found" >&2; return 1
                fi
                local selected
                selected=$(_cdb_cat | awk -F '\t' '{ printf "%-12s | %s\t%s\n", $1, $3, $2 }' \
                    | fzf --with-nth=1 --delimiter='\t' --preview='echo {2}' --layout=reverse --preview-window=up:1:wrap) || return 1
                name=$(printf '%s\n' "$selected" | cut -f1 | cut -d '|' -f 1 | xargs)
            fi
            for file in "$private" "$public"; do
                [ -f "$file" ] || continue
                if awk -F '\t' -v k="$name" '$1 == k { found=1 } END { exit !found }' "$file"; then
                    tmp=$(mktemp)
                    awk -F '\t' -v k="$name" '$1 != k' "$file" > "$tmp" && mv "$tmp" "$file"
                    echo "cdb: removed '$name' from $file"
                    removed=1
                fi
            done
            [ $removed -eq 1 ] || { echo "cdb: bookmark not found: $name" >&2; return 1; }
            ;;
        /list)
            _cdb_cat | awk -F '\t' '{ printf "%-12s | %-40s | %s\n", $1, $3, $2 }'
            ;;
        *)
            local name="${1:-}" dir
            if [ -z "$name" ]; then
                if ! command -v fzf > /dev/null 2>&1; then
                    echo "cdb: fzf not found" >&2; return 1
                fi
                local selected
                selected=$(_cdb_cat | awk -F '\t' '{ printf "%-12s | %s\t%s\n", $1, $3, $2 }' \
                    | fzf --with-nth=1 --delimiter='\t' --preview='echo {2}' --layout=reverse --preview-window=up:1:wrap) || return 1
                name=$(printf '%s\n' "$selected" | cut -f1 | cut -d '|' -f 1 | xargs)
            fi
            dir=$(_cdb_cat | awk -F '\t' -v k="$name" '$1 == k { print $2; exit }')
            dir="${dir/#\~/$HOME}"
            if [ -z "$dir" ]; then
                echo "cdb: bookmark not found: $name" >&2
                return 1
            fi
            if [ ! -d "$dir" ]; then
                echo "cdb: directory not found: $dir" >&2
                return 1
            fi
            cd "$dir"
            ;;
    esac
}
