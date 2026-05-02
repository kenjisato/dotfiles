# help: dothelp - browse available dotfile commands with fzf
dothelp() {
    local input
    input=$(awk '
        /^# help: / {
            if (summary != "") {
                sub(/\\n$/, "", details)
                print summary "\t" (details == "" ? "(no details)" : details)
            }
            summary = substr($0, index($0, "# help: ") + 8)
            details = ""
        }
        /^# help\+: / {
            line = substr($0, index($0, "# help+: ") + 9)
            details = details line "\\n"
        }
        END {
            if (summary != "") {
                sub(/\\n$/, "", details)
                print summary "\t" (details == "" ? "(no details)" : details)
            }
        }
    ' "${HOME}/.zsh/"*.zsh)

    [ -z "$input" ] && { echo "dothelp: no help entries found" >&2; return 1; }

    printf '%s\n' "$input" | fzf \
        --with-nth=1 \
        --delimiter='\t' \
        --preview='printf "%b\n" {2}' \
        --layout=reverse \
        --preview-window=up:40%:wrap
}
