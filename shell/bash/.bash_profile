# Login shells only. Terminal emulators on a Linux desktop spawn a NON-login
# shell, which reads ~/.bashrc and never this file — so keep the environment in
# ~/.bash/env.sh (sourced by both) rather than here, or it will be missing in
# every terminal window.
[ -r "$HOME/.bash/env.sh" ] && . "$HOME/.bash/env.sh"

# bash reads ~/.bashrc for non-login shells only, so a login shell has to pull
# in the interactive config explicitly. ~/.bashrc re-sources env.sh, which is
# idempotent.
[ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc"
