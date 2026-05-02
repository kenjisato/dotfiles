# CLAUDE.md — dotfiles (public)

Personal dotfiles for macOS, Linux, and WSL2 (Windows support is partial — PowerShell only). Deployment uses **per-target symlinks** driven by `etc/deploy`, which detects the host OS and links only the relevant subset of files.

A private overlay repo (`dotfiles-private`) can be layered on top via `$DOTFILES_PRIVATE`. When editing both repos together, use `dotfiles-private` as the entry point — its `CLAUDE.md` describes the two-repo workflow.

## Setup Commands

```bash
bash etc/install            # Install Homebrew, set zsh as default, install Rust + uv
bash etc/deploy             # Detect OS and create symlinks
bash etc/deploy --dry-run   # Preview what would be linked
brew bundle --file=pkg/Brewfile   # Homebrew packages (macOS / Linuxbrew)
```

`etc/deploy` is idempotent. It refuses to run if `~/.config` is itself a symlink (the legacy whole-directory layout) and prints migration instructions.

## Repository Structure

```
dotfiles/
├── home/
│   ├── common/         # ~/.* files for any OS (.vimrc, .tmux.conf, .Rprofile, ...)
│   ├── macos/
│   ├── linux/
│   ├── wsl/
│   └── windows/
├── shell/
│   ├── zsh/            # ~/.zshenv, ~/.zprofile, ~/.zshrc, ~/.zsh/
│   ├── bash/           # ~/.bash_profile, ~/.bashrc, ~/.bash/
│   └── shared/         # ~/.shell/<file>.sh — sourced by both .zshrc and .bashrc
├── xdg-config/         # symlinked into ~/.config/<dir> per subdirectory
│   ├── common/         # cdmarks.tsv, gh/, git/, rstudio/, uv/
│   ├── macos/          # karabiner/
│   ├── linux/          # mozc/
│   ├── wsl/
│   └── windows/        # NuGet/, powershell/
├── bin/
│   ├── common/
│   ├── macos/          # battery, wifi (use pmset/airport — macOS-only)
│   ├── linux/
│   ├── wsl/
│   └── windows/
├── pkg/
│   └── Brewfile        # cross-platform; cask entries gated by `if OS.mac?`
└── etc/
    ├── install
    └── deploy
```

## Deploy Behavior

`etc/deploy` detects the OS via `uname` (Darwin → `macos`, Linux → `linux`, Linux + `microsoft` in `/proc/version` → `wsl`) and links:

| Source | Destination |
|---|---|
| `home/{common,$OS}/*` | `~/*` |
| `shell/{zsh,bash,shared}/*` | `~/*` |
| `xdg-config/{common,$OS}/*` | `~/.config/*` (per file, preserving subdirs) |
| `bin/{common,$OS}/*` | `~/bin/*` |

Pre-existing non-symlink files at the destination are skipped with a notice. `.DS_Store`, `.gitkeep`, and `*.example` files are ignored.

When `$DOTFILES_PRIVATE` is set, the same `deploy_tree` function runs against the private repo after the public one, so private files at the same destination path override public ones.

## Shell Configuration Architecture

The zsh config is layered:

1. **`shell/zsh/.zshenv`** — Always sourced. Sets PATH, LANG, GOPATH, fpath.
2. **`shell/zsh/.zprofile`** — Login shells. Initializes Homebrew (Apple Silicon, Intel, or Linuxbrew).
3. **`shell/zsh/.zshrc`** — Interactive shells. Sources `~/.zsh/[0-9]*.{zsh,sh}` in numeric order; initializes compinit and starship.

**`shell/zsh/.zsh/` load order:**
- `00_aliases.zsh` — Aliases
- `10_completion.zsh` — Extra completion paths
- `20-fzf.zsh` — Ctrl+] jumps to ghq projects; provides `cdb` bookmark navigation
- `30_prompt.zsh` — Fallback prompt (skipped when starship is available)
- `31_history.zsh` — History settings (1M entries)
- `32_editors.zsh` — Sets vim as EDITOR/GIT_EDITOR/SVN_EDITOR
- `40_conda.zsh` — Conda init (no-op if conda absent)
- `90_sci.zsh` — R/Python science environment

`~/.shell/*.sh` is sourced by both shells at the end of their rc:
- `cdb.sh` — bookmark navigation (reads `~/.config/cdmarks.tsv` + `~/.config/cdmarks.local.tsv`)

## Key Paths

- `GOPATH=$HOME/local`
- `ghq.root=~/local/src`
- `VENVROOT=~/.envs`
- `~/bin` is on PATH (managed by deploy)

## Cross-Platform Notes

- Homebrew shellenv detection in `shell/zsh/.zprofile`: `/opt/homebrew` (Apple Silicon), `/usr/local` (Intel), `/home/linuxbrew/.linuxbrew` (Linux).
- `shell/bash/.bash/{mac,linux,wsl}.sh` are platform-specific stubs sourced from `.bashrc` based on `uname`.
- Windows: use `pwsh -File etc/deploy.ps1`. The Windows deploy is intentionally narrow — PowerShell profile + a few cross-platform dotfiles (`.vimrc`, `.tmux.conf`, `.vim/`).
