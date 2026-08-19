# Overlay skeleton

A starting point for the files you do not want in the base dotfiles repo:
identity, credentials, machine-specific paths, private package lists. Copy this
directory somewhere of your own, `git init` it if you want it versioned, and
point the base repo at it.

```bash
bash etc/deploy              # links the base tree, then this one on top
bash etc/deploy --dry-run    # preview both
DOTFILES=~/src/dotfiles bash etc/deploy   # if the base repo isn't at ~/dotfiles
```

The shim in `etc/deploy` sets `$DOTFILES_PRIVATE` to this directory and hands
off to the base repo's deploy, so you never have to export anything. The base
repo's `etc/overlay-init` can also record this path so a plain `bash etc/deploy`
there picks it up, and `etc/overlay-check` verifies the rules below.

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

Run `bash <base>/etc/overlay-check` to be told about collisions instead of
discovering them later.

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
for. Adding your own `pkg/` manifests and an `etc/install` of your own is a
normal next step — nothing in the base repo reads them, so the shape is yours to
choose.
