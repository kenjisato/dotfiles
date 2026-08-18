---
paths:
  - "xdg-config/common/git/*"
  - "xdg-config/common/git/**/*"
---

# Global git config — two files, and which one wins

Git reads **both** global config files, in this order: `~/.config/git/config`, then `~/.gitconfig`. The XDG file is *not* ignored when `~/.gitconfig` exists — a natural assumption, and wrong. For a single-valued key the file read **last wins**, so anything in `~/.gitconfig` overrides the deployed config; multi-valued keys (`credential.helper`, …) accumulate from both. `git config --global` **writes** to `~/.gitconfig` whenever that file exists, and `gh auth setup-git` creates it.

The split follows from that:

| Where | What | Tracked? |
|---|---|---|
| `xdg-config/common/git/config` → `~/.config/git/config` | Portable, non-personal settings + `core.hooksPath` + `[include] path = config.local` | Yes — **never put identity, secrets, or host-specific values here** |
| `~/.gitconfig` | `user.name` / `user.email`, `gh` credential helpers | No |
| `~/.config/git/config.local` | Per-machine overrides; the documented slot an overlay can deploy into | No |

Identity lives in `~/.gitconfig` deliberately: that is both the file `git config --global` edits and the file that wins, so there is no silent-override trap. `etc/install` seeds it from `gh api user` when `user.email` is unset — but see `install-deploy.md` for why that usually no-ops on a first run. Without an identity, the first `git commit` on a fresh box fails with "Author identity unknown".

**`etc/deploy` creates `~/.gitconfig` if absent, before it links anything — do not remove that step.** Since `git config --global` falls back to `~/.config/git/config` when `~/.gitconfig` does not exist, and git *follows the symlink and rewrites the target*, a plain `git config --global user.email …` on a box without `~/.gitconfig` writes a personal address straight into a tracked file. Verified, not theoretical. Creating the file removes the fallback permanently and makes the "identity lives in `~/.gitconfig`" rule self-enforcing. An existing file is never modified.

A relative `[include] path` resolves against the directory of the *symlink* (`~/.config/git/`), not the symlink's target inside the repo, so `config.local` can never accidentally resolve to a tracked file. A missing include is silently ignored, so the slot is safe to leave unsatisfied.

`commit.template` must **not** go in the tracked config: if the template file is absent, `git commit` without `-m` aborts with `fatal: could not read '<path>'` (exit 128). Put it in `config.local`.

`core.filemode` in a global config is close to inert — `git init` writes its own value into every repo's `.git/config`, which takes precedence.

# Global pre-commit hook (gitleaks)

`core.hooksPath = ~/.config/git/hooks` ships in the tracked config above, and `etc/deploy` symlinks `xdg-config/common/git/hooks/pre-commit` into that directory — so **the hook needs `etc/deploy` to have run**, not just `etc/install`. Windows is the exception: `etc/deploy.ps1` links only the hook, so `etc/install.ps1` still sets `core.hooksPath` via `git config --global`.

Every `git commit` then scans the staged diff with gitleaks first. Bypass with `git commit --no-verify`; silence a pattern with a repo-local `.gitleaks.toml`. CI should also scan on push — pre-commit guards against *accidents*, it is not a security boundary.

The hook picks its subcommand at runtime because gitleaks 8.19 superseded `protect` with `git`, and 8.30 already hides `protect` from `--help`. This matters more than it looks: an unknown subcommand exits **1**, the same code as "leaks found", so hardcoding a removed subcommand would block every commit with a misleading secret-found message instead of failing visibly. The hook is fail-open on any other exit code — a missing gitleaks warns and allows the commit.
