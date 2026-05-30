# CLAUDE.md — dotfiles (public)

Personal dotfiles for macOS, Linux, and WSL2 (Windows support is partial — PowerShell only). Deployment uses **per-target symlinks** driven by `etc/deploy`, which detects the host OS and links only the relevant subset of files.

A private overlay repo (`dotfiles-private`) can be layered on top via `$DOTFILES_PRIVATE`. When editing both repos together, use `dotfiles-private` as the entry point — its `CLAUDE.md` describes the two-repo workflow.

## Setup Commands

```bash
bash etc/install            # Homebrew + brew bundle, zsh, Rust, uv, uv tools, cargo tools
bash etc/deploy             # Detect OS and create symlinks
bash etc/deploy --dry-run   # Preview what would be linked
```

`etc/deploy` is idempotent. It refuses to run if `~/.config` is itself a symlink (the legacy whole-directory layout) and prints migration instructions.

## Repository Structure

```
dotfiles/
├── home/
│   ├── common/         # ~/.* files for any OS (.tmux.conf, .Rprofile, ...)
│   ├── macos/
│   ├── linux/
│   ├── wsl/
│   └── windows/
├── shell/
│   ├── zsh/            # ~/.zshenv, ~/.zprofile, ~/.zshrc, ~/.zsh/
│   ├── bash/           # ~/.bash_profile, ~/.bashrc, ~/.bash/
│   └── shared/         # ~/.shell/<file>.sh — sourced by both .zshrc and .bashrc
├── xdg-config/         # symlinked into ~/.config/<dir> per subdirectory
│   ├── common/         # cdmarks.tsv, gh/, git/, nvim/, rstudio/, uv/
│   ├── macos/          # karabiner/
│   ├── linux/          # mozc/
│   ├── wsl/
│   └── windows/        # NuGet/, powershell/, windows-terminal/ (overlay.json)
├── bin/
│   ├── common/
│   ├── macos/          # battery (use pmset — macOS-only)
│   ├── linux/
│   ├── wsl/
│   └── windows/
├── pkg/
│   ├── Brewfile                  # cross-platform; cask entries gated by `if OS.mac?`
│   ├── uv-tools.txt              # Python dev tools installed via `uv tool install`
│   ├── cargo-tools.txt           # Rust tools installed via `cargo install`
│   ├── winget-packages.txt       # Windows; installed on every host
│   ├── winget-packages.metal.txt # Windows; bare-metal only (skipped on Parallels)
│   └── windows-fonts.txt         # Windows; GitHub-released fonts (per-user HKCU install)
└── etc/
    ├── install                   # bash: brew bundle, zsh shell, Rust, uv, cargo tools, Claude Code
    ├── install.ps1               # winget + Claude Code + install-windows-fonts.ps1 + wt-apply-settings.ps1
    ├── install-windows-fonts.ps1 # reads pkg/windows-fonts.txt, installs TTFs to per-user HKCU
    ├── wt-apply-settings.ps1     # deep-merges overlay.json into Windows Terminal settings.json
    ├── deploy                    # bash: create symlinks (per-OS dispatch)
    ├── deploy.ps1                # PowerShell: create symlinks
    ├── undeploy                  # bash: remove symlinks pointing into the repo (incl. private overlay)
    └── undeploy.ps1              # PowerShell counterpart of undeploy
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
- `20-fzf.zsh` — Ctrl+] jumps to ghq-managed repos via `ghq list -p` + fzf
- `30_prompt.zsh` — Fallback prompt (skipped when starship is available)
- `31_history.zsh` — History settings (1M entries)
- `32_editors.zsh` — Sets nvim as EDITOR/GIT_EDITOR/SVN_EDITOR; aliases `vim` to `nvim`
- `40_conda.zsh` — Conda init (no-op if conda absent)
- `90_sci.zsh` — R/Python science environment

`~/.shell/*.sh` is sourced by both shells at the end of their rc:
- `cdb.sh` — bookmark navigation (reads `~/.config/cdmarks.tsv` + `~/.config/cdmarks.local.tsv`)

`~/.shell.local/*.sh` is sourced immediately after, guarded by `[ -d ~/.shell.local ]`. This directory is **untracked** and per-machine — drop installer-managed init here (juliaup, asdf, etc.) so it doesn't land in the symlinked, tracked rc files.

## Key Paths

- `GOPATH=$HOME/local`
- ghq root: `~/ghq` (default; no env var or git config needed)
- `VENVROOT=~/.envs`
- `~/bin` is on PATH (managed by deploy)

## Global git pre-commit (gitleaks)

`etc/install` and `etc/install.ps1` set `git config --global core.hooksPath ~/.config/git/hooks`, and `etc/deploy{,.ps1}` symlink `xdg-config/common/git/hooks/pre-commit` into that directory. The result: every `git commit` on this machine scans the staged diff with gitleaks before allowing the commit. Bypass with `git commit --no-verify`; gitleaks itself can be silenced per-pattern via a repo-local `.gitleaks.toml`. CI should also scan on push as a backstop — pre-commit is a guard against *accidents*, not a security boundary.

## Cross-Platform Notes

- Homebrew shellenv detection in `shell/zsh/.zprofile`: `/opt/homebrew` (Apple Silicon), `/usr/local` (Intel), `/home/linuxbrew/.linuxbrew` (Linux).
- `shell/bash/.bash/{mac,linux,wsl}.sh` are platform-specific stubs sourced from `.bashrc` based on `uname`.
- Windows: use `pwsh -File etc/deploy.ps1`. The Windows deploy is intentionally narrow — PowerShell profile + cross-platform dotfiles that have a Windows runtime (`.vimrc`, `.vim/`). `.tmux.conf` is excluded since native Windows has no tmux and WSL has its own filesystem.
