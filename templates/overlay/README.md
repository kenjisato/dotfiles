# Overlay skeleton

A starting point for the files you do not want in the base dotfiles repo:
identity, credentials, machine-specific paths, private package lists. Copy this
directory somewhere of your own, `git init` it if you want it versioned, and work
from here.

```bash
bash etc/install             # the base installer, then your own packages
bash etc/deploy              # links the base tree, then this one on top
bash etc/deploy --dry-run    # preview both
bash etc/undeploy            # removes the symlinks from both trees
DOTFILES=~/src/dotfiles bash etc/deploy   # if the base repo isn't at ~/dotfiles
```

**This directory is the entry point.** The base repo deploys exactly one tree and
never looks for another, so the shims in `etc/` are what compose the two: each
calls the base script, then runs it again with `--root` pointed here. Order is
the mechanism — the second link replaces the first wherever they collide.

That also means the base repo can sit still while you work. Nothing there needs
editing, or even knows this exists.

## How the layout maps

Deploy walks exactly these paths, in both trees, and ignores everything else —
so `etc/`, `pkg/`, and `README.md` here are never linked anywhere:

| Here | Becomes |
|---|---|
| `home/{common,macos,linux,wsl,windows}/*` | `~/*` |
| `shell/{zsh,bash,shared}/*` | `~/*` |
| `xdg-config/{common,macos,linux,wsl,windows}/**` | `~/.config/**` (per file, subdirs preserved) |
| `bin/{common,macos,linux,wsl,windows}/*` | `~/bin/*` |

`common/` is always linked; the OS directory is chosen by `uname` (Darwin →
`macos`, Linux → `linux`, Linux with *microsoft* in `/proc/version` → `wsl`). A
file in the wrong OS directory is silently never linked, which is the most common
mistake here.

`*.example` files are skipped by deploy — that is why the samples below carry
that suffix. Drop it to activate one.

## Rules

**Use a filename the base repo does not track.** This overlay is linked *after*
the base tree, so sharing a destination path means your file replaces theirs
outright — and later fixes upstream silently stop reaching this machine. The
base repo leaves these slots open precisely so you never have to:

| Slot | Put it here |
|---|---|
| `~/.config/git/config.local` | `xdg-config/common/git/config.local` |
| `~/.shell.local/*.sh` | `shell/shared/.shell.local/*.sh` |
| `~/.config/cdmarks.local.tsv` | `xdg-config/common/cdmarks.local.tsv` |
| `profile.local.ps1` beside `$PROFILE` | `xdg-config/windows/powershell/profile.local.ps1` |

Run `bash <base>/etc/overlay-check .` from here to be told about collisions
instead of discovering them later. It exits non-zero when it finds one, so it
works as a pre-commit hook in this repo.

**Keep git identity in `~/.gitconfig`, not here.** git reads `~/.gitconfig`
after `~/.config/git/config` and its includes, so a `user.email` in this overlay
would be overridden by whatever is in `~/.gitconfig` — and `git config --global`
writes there too. One file, no surprises.

**Read `~/.config/dotfiles/host-profile` if you need the host profile.** That is
the documented interface, so a `--profile server` chosen in the base installer
applies to anything you add here.

## Sample files

| File | What it shows |
|---|---|
| `xdg-config/common/git/config.local.example` | per-machine git settings, including why `commit.template` belongs here |
| `xdg-config/common/cdmarks.local.tsv.example` | extra `cdb` bookmarks |
| `shell/shared/.shell.local/10-local.sh.example` | shell snippets sourced by both zsh and bash |

`.gitkeep` files hold the empty directories; delete any branch you have no use
for. `etc/install` already reads the host profile the base installer resolved
(`~/.config/dotfiles/host-profile`) so both halves agree — add your `pkg/`
manifests and install steps under the marker it prints. Nothing in the base repo
reads them, so the shape is yours to choose.

If `etc/deploy` ever links something by hand — a directory that mixes config
with runtime state, say — remove it in `etc/undeploy` too, or deploy will create
links that undeploy leaves behind.
