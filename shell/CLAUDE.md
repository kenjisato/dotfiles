# Shell configuration

## zsh layering

1. **`.zshenv`** — always sourced. PATH, LANG, fpath.
2. **`.zprofile`** — login shells. Homebrew shellenv, detected across `/opt/homebrew` (Apple Silicon), `/usr/local` (Intel), `/home/linuxbrew/.linuxbrew` (Linux).
3. **`.zshrc`** — interactive shells. Sources `~/.zsh/[0-9]*.{zsh,sh}` in numeric order, then compinit and starship.

`shell/zsh/.zsh/` load order:

| File | Purpose |
|---|---|
| `00_aliases.zsh` | aliases |
| `10_completion.zsh` | extra completion paths |
| `20-fzf.zsh` | Ctrl+] jumps to a ghq repo via `ghq list -p` + fzf |
| `30_prompt.zsh` | fallback prompt, skipped when starship exists |
| `31_history.zsh` | history settings (1M entries) |
| `32_editors.zsh` | nvim as EDITOR/GIT_EDITOR/SVN_EDITOR; `vim` → `nvim` |
| `40_conda.zsh` | conda init, no-op if absent |
| `90_sci.zsh` | R/Python science environment |

## bash layering — the asymmetry that bites

1. **`.bash/env.sh`** — PATH, LANG, cargo, conda. Sourced by **both** `.bash_profile` and `.bashrc`, so every mutation must be idempotent (directories are added only when they exist and are not already on `PATH`); a login shell sources it twice.
2. **`.bash_profile`** — login shells. Sources `env.sh`, then `~/.bashrc`.
3. **`.bashrc`** — sources `env.sh` first, *above* the `[ -z "$PS1" ] && return` guard so a non-interactive `ssh host <command>` gets the same PATH, then interactive settings.

**Never put environment setup in `.bash_profile` alone.** bash reads `.bash_profile` only for *login* shells; desktop terminal emulators (lxterminal, gnome-terminal, konsole, …) spawn a **non-login** interactive shell that reads only `.bashrc`. Anything defined solely in `.bash_profile` is therefore missing in every terminal window on a Linux desktop — exactly how `~/.local/bin` fell off PATH there while working fine over SSH. No such asymmetry exists on the zsh side, where `.zshenv` is read unconditionally.

`shell/bash/.bash/{mac,linux,wsl}.sh` are platform stubs sourced from `.bashrc` based on `uname`.

## Shared and machine-local

`~/.shell/*.sh` is sourced by both shells at the end of their rc — currently `cdb.sh` (bookmark navigation, reading `~/.config/cdmarks.tsv` + `~/.config/cdmarks.local.tsv`) and `lazygit.sh` (exports `LG_CONFIG_FILE`, because `~/.config` is lazygit's config home on Linux only; see `.claude/rules/git-config.md`).

`~/.shell.local/*.sh` is sourced immediately after, guarded by `[ -d ~/.shell.local ]`. That directory is **untracked and per-machine** — put installer-managed init (juliaup, asdf, …) there so it never lands in the symlinked, tracked rc files. Several third-party installers append PATH lines to rc files by default; suppress that and use this directory instead, or they will dirty this repo's working tree through the symlink.

## Key paths

- `GOPATH`/`GOBIN` are intentionally **unset**. Go's own default (`~/go`, since 1.8) is used and only `~/go/bin` is added to PATH. Under modules GOPATH names just the module cache and the `go install` target, so overriding it only makes every Go tool's "add `~/go/bin` to your PATH" instruction wrong.
- ghq root: `~/ghq` (the default — no env var or git config needed).
- `VENVROOT=~/.envs`.
- `~/bin` is on PATH and populated by deploy.
- Locale sets **only** `LANG`. Never export `LC_ALL` from a profile: it hard-overrides every category and prints `setlocale: cannot change locale` on any machine where the locale is not generated. Generate the locale at the OS level instead.
