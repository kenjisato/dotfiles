---
paths:
  - "etc/*"
  - "etc/**/*"
  - "pkg/Brewfile"
---

# etc/install and etc/deploy

## etc/install must stay runnable with nothing but this repo

Two rules follow, both learned the hard way:

- It puts the install targets (`~/.local/bin`, `~/.cargo/bin`) on **its own** `PATH` early. `uv`, rustup, and the Claude Code installer land there and later steps invoke or probe what they just installed. Being on `PATH` in a *deployed shell* is irrelevant — the installer runs before `etc/deploy`, usually under bash. Without it, `uv tool install` died with `uv: command not found` and `set -e` killed the installer before any of the git/gh configuration at the bottom ran; `command -v rustup` also always missed, so every run re-downloaded and re-synced the Rust toolchain. Deliberately not guarded on `[ -d ]`: on a fresh box the directories do not exist yet, and adding them up front is what makes a tool callable right after the step that creates it.
- The `uv`/`cargo` package loops are **non-fatal** (`|| echo warning`). The configuration steps at the end are what make a fresh box usable; no single optional dev tool is worth skipping them. Keep new package loops non-fatal, and put configuration after them or move it earlier.

## Host profile

`--profile server` skips GUI app casks (keeping CLI formulae, fonts, and `r-app` for headless rendering). It is persisted by default to a per-machine marker (`~/.config/dotfiles/host-profile`), so plain `bash etc/install` reruns keep it. The marker is shared with `dotfiles-private`'s installer, so both always resolve to the same profile.

Clear it with `--profile desktop`; use `--profile server --no-save` for a one-off test. Precedence: `--profile` > `$DOTFILES_HOST_PROFILE` > marker > desktop. Homebrew scrubs non-`HOMEBREW_`-prefixed variables before evaluating the Brewfile, which is why the installer also exports `HOMEBREW_DOTFILES_HOST_PROFILE`.

## Login shell

The installer compares against the **passwd entry**, not `$SHELL`. `$SHELL` is inherited from the session that spawned the installer, so right after a `chsh` it still names the old shell — a `$SHELL`-based check re-ran `chsh` (and its password prompt) on every run until the next logout. It also adds zsh to `/etc/shells` when missing, which `chsh` requires and which Homebrew-installed zsh is not.

Changing the login shell needs a **full session logout**, not a new terminal window: emulators launch `$SHELL`, inherited from the already-running session.

## gh ordering (why identity seeding usually no-ops)

README runs `gh auth login` *after* the installer, so on a genuinely first run gh is installed but unauthenticated. Both gh-dependent steps — `gh auth setup-git` and seeding `user.name`/`user.email` from `gh api user` — are skipped by design, and the installer's closing message prints the exact commands instead. Do not "fix" this by making them unconditional; a re-run after logging in picks them up.

## Deploy semantics

`etc/deploy` detects the OS via `uname` (Darwin → `macos`, Linux → `linux`, Linux + `microsoft` in `/proc/version` → `wsl`) and links:

| Source | Destination |
|---|---|
| `home/{common,$OS}/*` | `~/*` |
| `shell/{zsh,bash,shared}/*` | `~/*` |
| `xdg-config/{common,$OS}/*` | `~/.config/*` (per file, preserving subdirs) |
| `bin/{common,$OS}/*` | `~/bin/*` |

- Pre-existing **non-symlink** files at the destination are skipped with a notice, never overwritten. That is the migration path for a hand-made config: move it aside, re-run deploy.
- `.DS_Store`, `.gitkeep`, and `*.example` files are ignored — so a `*.example` file is documentation only and is **never** deployed. Nothing else creates the real file for it.
- It creates `~/.gitconfig` when absent, **before** linking anything. See `git-config.md`; do not remove this.
- It refuses to run if `~/.config` is itself a symlink (the legacy whole-directory layout) and prints migration instructions.
- With `$DOTFILES_PRIVATE` set, the same `deploy_tree` function runs against the private repo *after* the public one, so a private file at the same destination path **replaces** the public one rather than merging with it. Prefer giving the private overlay its own filename (e.g. a `.local` include) over shadowing a public file.

`etc/undeploy` walks `$HOME` and removes only symlinks whose target resolves into either repo; regular files are never touched.

## Windows

The Windows deploy is intentionally narrow: the PowerShell profile plus cross-platform dotfiles that have a Windows runtime (`.vimrc`, `.vim/`). `.tmux.conf` is excluded (no native tmux; WSL has its own filesystem), and apps without a clean Windows XDG story (gh, git, rstudio) are skipped. Because `etc/deploy.ps1` links only the git *hook* and not the git config file, `etc/install.ps1` still sets `core.hooksPath` via `git config --global` — the one place that duplication is correct.
