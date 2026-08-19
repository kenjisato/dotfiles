---
paths:
  - "etc/*"
  - "etc/**/*"
  - "pkg/Brewfile"
---

# etc/install and etc/deploy

## etc/install has to take a fresh machine all the way to usable

Two rules follow, both learned the hard way:

- It puts the install targets (`~/.local/bin`, `~/.cargo/bin`) on **its own** `PATH` early. `uv`, rustup, and the Claude Code installer land there and later steps invoke or probe what they just installed. Being on `PATH` in a *deployed shell* is irrelevant — the installer runs before `etc/deploy`, usually under bash. Without it, `uv tool install` died with `uv: command not found` and `set -e` killed the installer before any of the git/gh configuration at the bottom ran; `command -v rustup` also always missed, so every run re-downloaded and re-synced the Rust toolchain. Deliberately not guarded on `[ -d ]`: on a fresh box the directories do not exist yet, and adding them up front is what makes a tool callable right after the step that creates it.
- The `uv`/`cargo` package loops are **non-fatal** (`|| echo warning`). The configuration steps at the end are what make a fresh box usable; no single optional dev tool is worth skipping them. Keep new package loops non-fatal, and put configuration after them or move it earlier.

## Host profile

`--profile server` skips GUI app casks (keeping CLI formulae, fonts, and `r-app` for headless rendering). It is persisted by default to a per-machine marker (`~/.config/dotfiles/host-profile`), so plain `bash etc/install` reruns keep it. That path is the documented interface for the host profile: an overlay installer that reads it resolves to the same profile without this repo knowing anything about it.

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
- The overlay path comes from `$DOTFILES_PRIVATE`, else from `~/.config/dotfiles/overlay` as recorded by `etc/overlay-init`. A path that is configured but missing **warns** — never silently skips, because a silent skip is indistinguishable from "the overlay has nothing for this host". The same `deploy_tree` function then runs against it *after* this repo, so an overlay file at the same destination path **replaces** ours rather than merging with it — which also means later improvements here never reach that machine. Document the `*.local` extension slots instead of inviting overlays to shadow tracked files. Nothing in this repo may name, assume, or depend on a particular overlay.

`etc/undeploy` walks `$HOME` and removes only symlinks whose target resolves into this repo (or the `$DOTFILES_PRIVATE` directory, when set); regular files are never touched.

## Overlay tooling

`etc/overlay-init` creates (`--create`, from `templates/overlay/`), adopts (`<dir>`), or clones (`--clone owner/repo|url`, via `ghq` when present) an overlay and records the path; `--forget` drops the record without deleting anything. `etc/overlay-check` audits one: collisions against our tracked destinations, files deploy would never link, and which extension slots are filled. It exits 1 on a collision so it can gate a commit.

`overlay-check` re-derives the destination map itself rather than calling deploy, so its `emit_map` **must be kept in step with `deploy_tree`**. If you add a directory to the walk in `etc/deploy`, add it there too or the checker will silently under-report. The `*.example` / `.gitkeep` / `.DS_Store` exclusions are duplicated for the same reason.

A destination can be a *directory* (`link_children` links `.shell.local` whole), so the checker treats anything beneath an emitted source as reachable — otherwise every file inside such a directory gets misreported as never linked.

## Windows

The Windows deploy is intentionally narrow: the PowerShell profile plus cross-platform dotfiles that have a Windows runtime (`.vimrc`, `.vim/`). `.tmux.conf` is excluded (no native tmux; WSL has its own filesystem), and apps without a clean Windows XDG story (gh, git, rstudio) are skipped. Because `etc/deploy.ps1` links only the git *hook* and not the git config file, `etc/install.ps1` still sets `core.hooksPath` via `git config --global` — the one place that duplication is correct.
