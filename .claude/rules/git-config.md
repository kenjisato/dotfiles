---
paths:
  - "xdg-config/common/git/*"
  - "xdg-config/common/git/**/*"
  - "xdg-config/common/lazygit/*"
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

# Diff toolchain — delta, difftastic, lazygit

Three tools, three jobs, and they are not alternatives:

| Tool | What it is | How it is wired |
|---|---|---|
| delta (`delta`, package `git-delta`) | Pager: takes git's own line-based diff and recolours it | `core.pager` + `interactive.diffFilter` — always on |
| difftastic (`difft`) | Diff *engine*: parses both sides with tree-sitter, reports what changed in the code | `git dft` / `dlog` / `dshow` aliases + the `difftastic` difftool — per command |
| lazygit | TUI for staging, committing, rebasing | own config, renders diffs through the two above |

Why delta is global and difftastic is not: delta's output is still a patch, so nothing downstream changes. difftastic's is a *display* — set `diff.external = difft` globally and `git add -p`, `git diff > x.patch`, and every script parsing a diff get something git cannot apply. The aliases keep the choice at the call site. (Upstream also notes git ≤ 2.43.1 can crash on an external diff when file permissions changed.)

Verified behaviours, all on git 2.47:

- **`core.pager` and `interactive.diffFilter` pointing at a missing command are silent no-ops.** git starts the pager, the exec fails, and git writes the output itself — no message, exit 0. So `pager = delta` is safe in the tracked config even on a box where `brew bundle` never ran; this is *not* the `commit.template` trap.
- **`merge.conflictstyle` rejects an unknown value fatally, while merging.** `git merge` on a conflicting file dies with `error: unknown style '<x>'` / exit 128 and writes no conflict markers. `zdiff3` is only understood from git 2.35, so the tracked config carries `diff3` and zdiff3 belongs in `config.local`.
- **difftastic's output survives delta.** With `diff.external=difft` and `core.pager=delta`, delta passes the structural display through untouched, colours included — so the aliases need no pager override. Same for `pager.difftool = true`. An interactive difftool does need `-c pager.difftool=false`.
- **`difftool.difftastic.cmd` passes `$MERGED` first** (git's external-diff argument order), which is what makes the heading show the real path instead of a temp file. The hash and mode arguments are placeholders filling the remaining positions.

# lazygit's config file

`xdg-config/common/lazygit/config.yml` deploys to `~/.config/lazygit/config.yml`, which lazygit finds on Linux and WSL only: on macOS its config home is `~/Library/Application Support/lazygit`, outside anything `etc/deploy` links. `~/.shell/lazygit.sh` therefore exports `LG_CONFIG_FILE`, and that variable is a comma-separated list merged left to right — so it appends `~/.config/lazygit/config.local.yml` as the per-machine slot. **Every file listed must exist**: a missing one aborts lazygit before the UI opens (`stat …: no such file or directory`), hence the guards in the snippet.

**lazygit rewrites its own config file when the schema moved on** — "must be migrated… Config file saved successfully" — and with `LG_CONFIG_FILE` pointing into the deployed symlink, that write lands in this repo as an unexplained working-tree change. Same failure mode as lxterminal's Preferences dialog. Keep the tracked file on the current schema: `git.paging` became `git.pagers` became `git.diffRenderers`, whose entries are `{type: stdinFilter|extDiff|rawGit, name, colorArg, command}`. Unknown *keys* are tolerated, so only a renamed one triggers a rewrite. `|` cycles the renderers in the panel (delta → difftastic → plain git), `\` reverses.
