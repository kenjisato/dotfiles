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
- It deploys **one** tree: this repo, or whatever `--root` names. Stacking is achieved by running it once per tree in the desired order — the later run wins, because `ln -snfv` replaces an existing symlink (a real file is still skipped). Verified across separate invocations, so the caller genuinely controls precedence.
- There is deliberately **no** `$DOTFILES_PRIVATE`, recorded path, or post-deploy hook. Any of those would make this script branch on whether an extension exists, inverting the one-way dependency. Composition belongs to whoever is stacking; `templates/overlay/etc/deploy` shows the shape.
- `--os macos|linux|wsl` overrides detection. Mainly for previewing another host's result with `--dry-run`, which is also how `etc/overlay-check` gets its destination map.

`etc/undeploy` walks `$HOME` and removes only symlinks whose target resolves into a tree it was **given**: this repo by default, `<dir>...` to replace that list, `--also <dir>` to add to it. Regular files are never touched. Anything that stacks a tree has to pass it here too, or it leaves its own links behind.

## Overlay tooling

`etc/overlay-init` only *obtains* a tree — `--create` from `templates/overlay/`, or `--clone owner/repo|url` (via `ghq` when present). It records nothing, because nothing here reads a recorded path. `etc/overlay-check <dir>` audits one: collisions against our destinations, files deploy would never link, and which extension slots are filled. It exits 1 on a collision so it can gate a commit.

`overlay-check` gets its destination map by parsing `etc/deploy --root <tree> --dry-run` output (`would link: <dst> -> <src>`) rather than reimplementing the layout, so it cannot drift from deploy. Keep that output format stable, or fix the `sed` in the checker with it.

A destination can be a *directory* (`link_children` links `.shell.local` whole), so the checker treats anything beneath an emitted source as reachable — otherwise every file inside such a directory gets misreported as never linked.

`--dry-run` must stay side-effect free; it used to `mkdir -p ~/.config ~/bin` unconditionally, which made the checker's preview runs write to disk.

## Windows

The Windows deploy is intentionally narrow: the PowerShell profile, `.psmux.conf`, `starship.toml`, `lazygit/config.yml`, and the three git files under `~/.config/git/` (`config`, `ignore`, `hooks/pre-commit`). `.tmux.conf` is excluded (no native tmux; WSL has its own filesystem), and apps without a clean Windows XDG story (gh, rstudio) are skipped. Nothing from `home/common/` is linked: it holds `.Rprofile`, `.rsyncignore` and `.tmux.conf`, none of which has an assumable Windows runtime. (`.vimrc` and `.vim/` were listed here and in the script until they turned out to have been dead lines since the neovim switch deleted the files — check `Test-Path` before believing a link list.)

It also links three extension slots — `xdg-config/common/git/config.local`, `xdg-config/common/lazygit/config.local.yml`, `xdg-config/windows/powershell/profile.local.ps1` — which are no-ops for this repo, since it tracks none of them, and only do something for a tree deployed with `-Root`. Without them the slots README documents were Unix-only in practice: the bash deploy walks `xdg-config/` per file and picks them up, while this script links a fixed list. Nothing writes to any of the three, which is what makes linking them into a repo safe, unlike `~/.gitconfig`.

`etc/undeploy.ps1` therefore scans `$PROFILE`'s directory as well as `$HOME` top-level and `$HOME\.config` recursively — `profile.local.ps1` lives beside the profile, outside both other walks.

git is linked because git-for-windows resolves `~/.config/git/config` like every other platform, so the whole tracked config applies — including `core.autocrlf = input`, which overrides Git for Windows' system-level `autocrlf true`. See `git-config.md` for what that costs and the per-machine escape hatch.

Two invariants come with that link. `etc/deploy.ps1` must create `~/.gitconfig` before linking anything (`Initialize-GitConfig`), for the same reason the bash deploy does. And `etc/install.ps1` sets `core.hooksPath` via `git config --global` **only when `~/.config/git/config` does not exist** — with the link in place and `~/.gitconfig` absent, that write would land in this repo's tracked file. The guard means the installer never depends on the deploy having run first.
