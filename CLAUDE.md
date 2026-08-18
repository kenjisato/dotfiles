# CLAUDE.md — dotfiles (public)

Personal dotfiles for macOS, Linux, and WSL2 (Windows support is partial — PowerShell only). Deployment uses **per-target symlinks** driven by `etc/deploy`, which detects the host OS and links only the relevant subset of files.

A private overlay repo (`dotfiles-private`) can be layered on top via `$DOTFILES_PRIVATE`. When editing both repos together, use `dotfiles-private` as the entry point — its `CLAUDE.md` describes the two-repo workflow.

## Setup Commands

```bash
bash etc/install            # Homebrew + brew bundle, zsh, Rust, uv, uv tools, cargo tools
bash etc/install --profile server  # headless box: skip GUI app casks (keep fonts + r-app)
bash etc/deploy             # Detect OS and create symlinks
bash etc/deploy --dry-run   # Preview what would be linked
```

**Host profile is remembered.** `--profile server` is persisted by default to a
per-machine marker (`~/.config/dotfiles/host-profile`), so plain `bash etc/install`
reruns keep the server profile — no need to re-pass the flag. The marker is shared
with `dotfiles-private`'s installer, so both always resolve to the same profile.
Clear it with `--profile desktop` (back to the default); use `--profile server --no-save`
for a one-off test that must not stick. Precedence: `--profile` > `$DOTFILES_HOST_PROFILE`
> marker > desktop. `etc/install` also runs `gh auth setup-git` when `gh` is
authenticated, so HTTPS `git push` doesn't prompt for a password, and seeds
`user.name`/`user.email` from the gh account when git has no identity yet — see
[Global git config](#global-git-config-two-files-and-which-one-wins).

`etc/deploy` is idempotent. It refuses to run if `~/.config` is itself a symlink (the legacy whole-directory layout) and prints migration instructions.

**`etc/install` must stay runnable end-to-end with nothing but this repo.** Two rules follow from that, both learned the hard way:

- It puts `~/.local/bin` on **its own** `PATH` early. `uv` and the Claude Code installer land there, and later steps invoke what they just installed. Being on `PATH` in a *deployed shell* is irrelevant — the installer runs before `etc/deploy`, usually under bash. Without it `uv tool install` failed with `uv: command not found` and `set -e` killed the installer before any of the git/gh configuration at the bottom ran.
- The `uv`/`cargo` package loops are **non-fatal** (`|| echo warning`). The configuration steps at the end are what make a fresh box usable; no single optional dev tool is worth skipping them. Keep new package loops non-fatal and put configuration after them, or move it earlier.

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
│   ├── Brewfile                  # cross-platform; casks gated by `if OS.mac?`, GUI apps further gated by server profile (HOMEBREW_DOTFILES_HOST_PROFILE)
│   ├── uv-tools.txt              # Python dev tools installed via `uv tool install`
│   ├── cargo-tools.txt           # Rust tools installed via `cargo install`
│   ├── winget-packages.txt       # Windows; installed on every host
│   ├── winget-packages.metal.txt # Windows; bare-metal only (skipped on Parallels)
│   ├── windows-fonts.txt         # Windows; GitHub-released fonts (per-user HKCU install)
│   └── linux-fonts.txt           # Linux; GitHub-released fonts (per-user ~/.local/share/fonts)
└── etc/
    ├── install                   # bash: brew bundle, zsh shell, Rust, uv, cargo tools, Claude Code, Linux fonts
    ├── install.ps1               # winget + Claude Code + install-windows-fonts.ps1 + wt-apply-settings.ps1
    ├── install-windows-fonts.ps1 # reads pkg/windows-fonts.txt, installs TTFs to per-user HKCU
    ├── install-linux-fonts       # reads pkg/linux-fonts.txt, installs TTFs to ~/.local/share/fonts
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

1. **`shell/zsh/.zshenv`** — Always sourced. Sets PATH, LANG, fpath.
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

The bash config mirrors that split, but with one rule that is easy to get wrong:

1. **`shell/bash/.bash/env.sh`** — PATH, LANG, cargo, conda. Sourced by **both** `.bash_profile` and `.bashrc`, and written to be idempotent (dirs are added only when they exist and are not already on PATH), because a login shell sources it twice.
2. **`shell/bash/.bash_profile`** — Login shells. Sources `env.sh`, then `~/.bashrc`.
3. **`shell/bash/.bashrc`** — Sources `env.sh` first (above the `[ -z "$PS1" ] && return` guard, so a non-interactive `ssh host <command>` gets the same PATH), then interactive settings.

**Never put environment setup in `.bash_profile` alone.** bash reads `.bash_profile` only for *login* shells; desktop terminal emulators (lxterminal, gnome-terminal, konsole, …) spawn a **non-login** interactive shell that reads only `.bashrc`. Anything defined solely in `.bash_profile` is therefore missing in every terminal window on a Linux desktop — which is exactly how `~/.local/bin` fell off PATH there while working fine over SSH. This asymmetry does not exist on the zsh side, where `.zshenv` is read unconditionally.

`~/.shell/*.sh` is sourced by both shells at the end of their rc:
- `cdb.sh` — bookmark navigation (reads `~/.config/cdmarks.tsv` + `~/.config/cdmarks.local.tsv`)

`~/.shell.local/*.sh` is sourced immediately after, guarded by `[ -d ~/.shell.local ]`. This directory is **untracked** and per-machine — drop installer-managed init here (juliaup, asdf, etc.) so it doesn't land in the symlinked, tracked rc files.

## Key Paths

- `GOPATH`/`GOBIN` are intentionally **unset** — Go's own default (`~/go` since 1.8) is used, and only `~/go/bin` is added to PATH. Under modules, GOPATH names just the module cache and the `go install` target, so overriding it only makes every Go tool's "add `~/go/bin` to your PATH" instructions wrong
- ghq root: `~/ghq` (default; no env var or git config needed)
- `VENVROOT=~/.envs`
- `~/bin` is on PATH (managed by deploy)

## Global git config (two files, and which one wins)

Git reads **both** global config files, in this order: `~/.config/git/config`, then `~/.gitconfig`. The XDG file is *not* ignored when `~/.gitconfig` exists — a natural assumption, and wrong. For a single-valued key the file read **last wins**, so anything in `~/.gitconfig` overrides the deployed config; multi-valued keys (`credential.helper`, …) accumulate from both. `git config --global` **writes** to `~/.gitconfig` whenever that file exists, and `gh auth setup-git` creates it.

The split follows from that:

| Where | What | Tracked? |
|---|---|---|
| `xdg-config/common/git/config` → `~/.config/git/config` | Portable, non-personal settings + `core.hooksPath` + `[include] path = config.local` | Yes — **never put identity or secrets here, this repo is public** |
| `~/.gitconfig` | `user.name` / `user.email`, `gh` credential helpers | No |
| `~/.config/git/config.local` | Per-machine overrides; the slot a private overlay can deploy | No |

Identity lives in `~/.gitconfig` deliberately: that is both the file `git config --global` edits and the file that wins, so there is no silent-override trap. `etc/install` seeds it from `gh api user` when `user.email` is unset — but note the ordering, since README runs `gh auth login` *after* the installer: on a genuinely first run gh is installed and unauthenticated, the seeding is skipped, and the installer's closing message tells you to re-run it or set the identity by hand. Without this, the first `git commit` on a fresh box fails with "Author identity unknown".

A relative `[include] path` resolves against the directory of the *symlink* (`~/.config/git/`), not the symlink's target inside the repo, so `config.local` can never accidentally resolve to a tracked file. A missing include is silently ignored.

**`etc/deploy` creates `~/.gitconfig` if absent, before it links anything** — do not remove that step. Since `git config --global` falls back to `~/.config/git/config` when `~/.gitconfig` does not exist, and git *follows the symlink and rewrites the target*, a plain `git config --global user.email …` on a box without `~/.gitconfig` writes a personal address straight into a tracked file of this public repo. Verified, not theoretical. Creating the file removes the fallback permanently and makes the "identity lives in `~/.gitconfig`" rule self-enforcing. An existing file is never modified.

`commit.template` must **not** go in the tracked config: if the template file is absent, `git commit` without `-m` aborts with `fatal: could not read '<path>'` (exit 128). Put it in `config.local`.

## Global git pre-commit (gitleaks)

`core.hooksPath = ~/.config/git/hooks` ships in the tracked `xdg-config/common/git/config` above, and `etc/deploy` symlinks `xdg-config/common/git/hooks/pre-commit` into that directory — so **the hook needs `etc/deploy` to have run**, not just `etc/install`. Windows is the exception: `etc/deploy.ps1` links only the hook, not the config file, so `etc/install.ps1` still sets `core.hooksPath` via `git config --global`.

The result: every `git commit` on this machine scans the staged diff with gitleaks before allowing the commit. Bypass with `git commit --no-verify`; gitleaks itself can be silenced per-pattern via a repo-local `.gitleaks.toml`. CI should also scan on push as a backstop — pre-commit is a guard against *accidents*, not a security boundary.

The hook picks its subcommand at runtime: gitleaks 8.19 superseded `protect` with `git`, and `protect` is already hidden from `--help` in 8.30. This matters because an unknown subcommand exits **1**, the same code as "leaks found" — so hardcoding a removed subcommand would block every commit with a misleading secret-found message rather than failing visibly.

## Display scripts that call git

Anything that shells out to `git` on a **timer** for display purposes (tmux `pane-border-format` / status bar, prompts, editor gutters) must pass `--no-optional-locks`. `git status` looks read-only but refreshes the index stat cache, taking `.git/index.lock` to do it — so a periodic caller makes interactive `git add`/`git commit` in that repo fail intermittently with `Unable to create '.git/index.lock': File exists`. The flag suppresses that write; output is unchanged. Currently applies to `bin/common/tmux-pane-border`, re-evaluated every `status-interval` (15s) per bordered pane. Read-only plumbing (`rev-parse`, `symbolic-ref`) doesn't take the lock, but adding the flag by default costs nothing.

## Fonts

Three platforms, three mechanisms, one intent — a Nerd-patched font with Japanese coverage so the starship prompt and Japanese text both render:

| OS | How |
|---|---|
| macOS | `pkg/Brewfile` casks (`font-hack-nerd-font`, `font-hackgen-nerd`, …), kept on the server profile too since headless Quarto/Typst/LaTeX rendering needs them |
| Windows | `etc/install-windows-fonts.ps1` reads `pkg/windows-fonts.txt`, installs per-user to HKCU |
| Linux | `etc/install-linux-fonts` reads `pkg/linux-fonts.txt`, installs per-user to `~/.local/share/fonts` |

Debian/Ubuntu ship **no** Nerd-patched font in apt, which is why Linux needs the GitHub-release path rather than a package name. `pkg/linux-fonts.txt` uses the same `owner/repo:asset-glob:font-glob` format as the Windows manifest so the two stay comparable — except that the Windows-only `@tag` form (repos publishing no releases) is unimplemented on Linux and warns rather than silently skipping.

Idempotency is per-repo: `~/.local/share/fonts/<repo>/.release` records the installed release tag, and a run whose latest tag matches is a no-op. Delete the stamp to force a re-download. `etc/install` calls the script on Linux only, non-fatal like the package loops.

Installing the font is not the same as *using* it — a terminal emulator with an explicit font setting (lxterminal's `fontname`, Windows Terminal's profile) still has to name it, though fontconfig will fall back to it for glyphs the configured font lacks.

## Cross-Platform Notes

- Homebrew shellenv detection in `shell/zsh/.zprofile`: `/opt/homebrew` (Apple Silicon), `/usr/local` (Intel), `/home/linuxbrew/.linuxbrew` (Linux).
- `shell/bash/.bash/{mac,linux,wsl}.sh` are platform-specific stubs sourced from `.bashrc` based on `uname`.
- Windows: use `pwsh -File etc/deploy.ps1`. The Windows deploy is intentionally narrow — PowerShell profile + cross-platform dotfiles that have a Windows runtime (`.vimrc`, `.vim/`). `.tmux.conf` is excluded since native Windows has no tmux and WSL has its own filesystem.
