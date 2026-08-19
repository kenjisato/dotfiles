# CLAUDE.md — dotfiles

Dotfiles for macOS, Linux, and WSL2 (Windows support is partial — PowerShell only).

**The goal is the shortest path from a freshly installed OS to a machine that is ready to work on.** `etc/install` provisions the tools; `etc/deploy` symlinks the config, per OS and per target. When a design question comes up, the tie-breaker is which option gets a new machine working sooner and with fewer surprises.

Three consequences do most of the work:

1. **Every instruction must be followable with only this repo and the machine in front of you.** A comment, doc line, or help string that sends the reader somewhere they might not have is where setup stops.
2. **The same tracked files have to work on every machine.** Nothing host-specific gets baked in, and secrets and identity never enter version control at all. Both go in the machine-local slots the deployed config already reaches.
3. **Defining how to extend and override these settings is part of the job.** Overriding is a supported operation, not an afterthought, so this repo owns the rules for doing it without collisions: which slots exist, what stacking order means, and why reusing one of our tracked filenames is the wrong way to do it. Documented in README under "Extending and overriding". Describe the mechanism, never a particular extension.

   The dependency runs **one way only**: something stacked on top may know about this repo, and this repo never knows about it. `etc/deploy` links exactly one tree — `--root` picks which — so composing several is the caller's job, and nothing here branches on whether an extension exists. Adding an env var, a recorded path, or a hook so that our scripts could go looking for one would invert that; don't.

## Setup

```bash
bash etc/install                   # brew bundle, zsh login shell, Rust, uv/cargo tools, Claude Code, Linux fonts
bash etc/install --profile server  # headless box: skip GUI casks (the profile is remembered per machine)
bash etc/deploy                    # detect OS, create symlinks (idempotent)
bash etc/deploy --dry-run          # preview
bash etc/undeploy                  # remove only symlinks pointing into this repo
bash etc/deploy --root <dir>        # deploy another tree with this layout (stacking = run again)
bash etc/overlay-init --create      # scaffold a tree to stack, from templates/overlay
bash etc/overlay-check <dir>        # audit one for collisions with our files
```

Windows: `pwsh -File etc\install.ps1`, then `pwsh -File etc\deploy.ps1`.

## Layout

```
home/        ~/.* dotfiles              shell/   zsh/, bash/, shared/ rc files
xdg-config/  ~/.config/<dir>            bin/     ~/bin scripts
pkg/         package + font manifests   etc/     install / deploy / undeploy / overlay-*
templates/   overlay skeleton, not deployed
```

`home/`, `xdg-config/`, and `bin/` each split into `common/` plus one directory per OS (`macos/`, `linux/`, `wsl/`, `windows/`); deploy links `common/` and the detected OS only, so putting a file in the wrong OS directory silently means it is never linked. `shell/` splits by shell instead (`zsh/`, `bash/`, `shared/`) and is linked on every Unix host. `pkg/`, `etc/`, and `templates/` are outside the walk entirely, which is what makes it safe to ship a skeleton overlay inside the repo.

## Don'ts

Every item below has actually been violated in this repo and cost real debugging. The reasoning behind each one is in `.claude/rules/`, which loads when you open the relevant files.

- **Never put identity or secrets in a tracked file.** `user.name`/`user.email` go in `~/.gitconfig`, never in `xdg-config/common/git/config`.
- **Never reference anything the reader might not have.** No repository name, owner, URL, or personal path — in docs, code comments, or help strings alike. Write the instruction out instead of pointing at a document only some people can open, and describe an extension slot rather than whatever happens to fill it here.
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
