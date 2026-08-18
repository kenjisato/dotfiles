# CLAUDE.md — dotfiles

Personal dotfiles for macOS, Linux, and WSL2 (Windows support is partial — PowerShell only). `etc/deploy` detects the host OS and creates **per-target symlinks**, linking only the relevant subset of files. `etc/install` provisions the tools those files assume.

Two goals shape almost every decision here:

1. **This repo stands alone.** `bash etc/install && bash etc/deploy` on a fresh machine must leave a system you can work on, with no other repository, no external document, and no manual step beyond what the installer prints. A comment or doc line that points at a file outside this tree is a defect, not a cross-reference.
2. **Nothing personal is tracked.** Every file here is published. Identity, secrets, and host-specific values belong in untracked files that the deployed config reaches through a documented extension slot.

Overlays are *supported but never assumed*. `$DOTFILES_PRIVATE` is an optional extension point; the contract for it is in README under "Extending with an overlay". Describe the mechanism only — no repository name, owner, URL, or local path for any particular overlay belongs anywhere in this tree.

## Setup

```bash
bash etc/install                   # brew bundle, zsh login shell, Rust, uv/cargo tools, Claude Code, Linux fonts
bash etc/install --profile server  # headless box: skip GUI casks (the profile is remembered per machine)
bash etc/deploy                    # detect OS, create symlinks (idempotent)
bash etc/deploy --dry-run          # preview
bash etc/undeploy                  # remove only symlinks pointing into either repo
```

Windows: `pwsh -File etc\install.ps1`, then `pwsh -File etc\deploy.ps1`.

## Layout

```
home/        ~/.* dotfiles              shell/   zsh/, bash/, shared/ rc files
xdg-config/  ~/.config/<dir>            bin/     ~/bin scripts
pkg/         package + font manifests   etc/     install / deploy / undeploy
```

`home/`, `xdg-config/`, and `bin/` each split into `common/` plus one directory per OS (`macos/`, `linux/`, `wsl/`, `windows/`); deploy links `common/` and the detected OS only, so putting a file in the wrong OS directory silently means it is never linked. `shell/` splits by shell instead (`zsh/`, `bash/`, `shared/`) and is linked on every Unix host.

## Don'ts

Every item below has actually been violated in this repo and cost real debugging. The reasoning behind each one is in `.claude/rules/`, which loads when you open the relevant files.

- **Never put identity or secrets in a tracked file.** Everything here is published. `user.name`/`user.email` go in `~/.gitconfig`, never in `xdg-config/common/git/config`.
- **Never name a specific overlay, or point at anything outside this tree.** No repository name, owner, URL, or local path — not in docs, not in a code comment, not in a help string. Document the `$DOTFILES_PRIVATE` contract and the `*.local` slots instead. A reference to a file only one person has is a broken reference for everyone else.
- **Never remove the `~/.gitconfig` creation step from `etc/deploy`.** Without it `git config --global` follows a symlink and writes a personal address into this repo's tracked git config.
- **Never put `commit.template` in the tracked git config.** If the template file is missing, `git commit` without `-m` aborts with exit 128 on every machine that lacks it.
- **Never put environment setup in `.bash_profile` alone.** Desktop terminal emulators spawn *non-login* shells that read only `.bashrc`. It belongs in `shell/bash/.bash/env.sh`, which both source.
- **Never assume `etc/install` can call a tool it just installed.** The installer runs before `etc/deploy` and usually under bash, so it must put the install target (`~/.local/bin`, `~/.cargo/bin`) on its *own* `PATH`.
- **Never make a package loop in `etc/install` fatal.** `set -e` plus one unavailable package used to skip every configuration step that followed. Warn and continue.
- **Never call `git` on a timer without `--no-optional-locks`.** `git status` takes `.git/index.lock`, so a status-bar or prompt caller breaks interactive `git add`/`git commit` intermittently.
- **Never hardcode a `gitleaks` subcommand.** An unknown subcommand exits `1` — the same code as "leaks found" — so a removed one blocks every commit with a misleading message.

## Where the detail lives

Nothing above is the whole story. Rationale, verified behaviours, and per-area rules load on demand:

| File | Loads when you touch |
|---|---|
| `shell/CLAUDE.md` | anything under `shell/` — zsh and bash layering, load order, key paths |
| `.claude/rules/install-deploy.md` | `etc/*` — installer invariants, host profiles, deploy/link semantics |
| `.claude/rules/git-config.md` | `xdg-config/common/git/*` — the two global config files and the gitleaks hook |
| `.claude/rules/git-in-timers.md` | `bin/*`, `.tmux.conf` — the `--no-optional-locks` rule |
| `.claude/rules/fonts.md` | font manifests and installers — one Nerd font per platform, three mechanisms |
| `.claude/rules/lxterminal.md` | `xdg-config/linux/lxterminal/*` — an app that writes back through its symlink |

`shell/` uses a nested `CLAUDE.md` rather than a path-scoped rule on purpose: it is full of dot-prefixed files *and* dot-prefixed directories (`.bash/`, `.zsh/`), and a directory-triggered file cannot be defeated by a glob that ignores leading dots. Everything else has ordinary filenames, so a `paths:` rule is fine.

Both mechanisms load lazily, so neither survives `/compact` the way this file does. That is why the hard rules are duplicated as one-liners in **Don'ts** above — keep them there, and keep the reasoning below.
