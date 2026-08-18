# dotfiles

Cross-platform dotfiles for macOS, Linux (Ubuntu), WSL2, and Windows.
Deployment is symlink-based with per-OS dispatch.

## Setup from a fresh OS

Each section below is self-contained — copy-paste into a freshly installed
shell to go from "nothing installed" to "fully deployed".

### macOS

```bash
# 1. Xcode Command Line Tools — provides git, make, cc, ld
xcode-select --install

# 2. Clone & run
git clone https://github.com/kenjisato/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash etc/install   # Homebrew + brew bundle + zsh shell + Rust + uv + cargo tools + Claude Code
bash etc/deploy
```

`etc/install` sets zsh as the login shell, but opening a new terminal window is
**not** enough to pick it up: terminal emulators launch `$SHELL`, which every
process inherited from the session that was already running when `chsh` ran. Log
out of the entire desktop or SSH session (or reboot), then check with
`echo $SHELL`.

### Ubuntu / WSL2

```bash
# 1. apt prerequisites
sudo apt update && sudo apt install -y curl git zsh build-essential locales

# The shell config sets LANG=en_US.UTF-8 (shell/bash/.bash/env.sh,
# shell/zsh/.zshenv). Minimal WSL/container images don't ship that locale, so
# generate it or every shell prints "setlocale: cannot change locale".
sudo locale-gen en_US.UTF-8 && sudo update-locale

# 2. Clone & run
git clone https://github.com/kenjisato/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash etc/install   # Linuxbrew + brew bundle (cask entries auto-skipped) + Rust + uv + Claude Code
bash etc/deploy
```

### Windows (PowerShell)

Prerequisites:

- Windows 10 1809+ or Windows 11 (winget is built-in; per-user font registration works)
- **Developer Mode ON** so `etc/deploy.ps1` can create symlinks without an
  elevated shell. Either:
  - GUI: Settings → System → For developers → Developer Mode = ON, or
  - elevated PowerShell:
    ```powershell
    New-ItemProperty `
        -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
        -Name 'AllowDevelopmentWithoutDevLicense' `
        -Value 1 -PropertyType DWORD -Force
    ```

```powershell
# 1. Bootstrap from the built-in Windows PowerShell 5.1 — install git and pwsh 7.
#    `etc/install.ps1` and friends use ConvertFrom-Json -AsHashtable, which
#    requires PowerShell 7+.
winget install --exact --id Git.Git
winget install --exact --id Microsoft.PowerShell

# 2. Close this window and open a NEW PowerShell session so PATH picks up
#    git and pwsh, then continue:
git clone https://github.com/kenjisato/dotfiles.git $HOME\dotfiles
cd $HOME\dotfiles
pwsh -File etc\install.ps1   # winget packages + Claude Code + fonts + Windows Terminal overlay
pwsh -File etc\deploy.ps1
```

`etc/install.ps1` reads `pkg/winget-packages*.txt` and runs `winget install`
for each entry. Manifests with the `.metal.txt` suffix are skipped on
Parallels VMs (detected via WMI Manufacturer = Parallels); override with
`$Env:DOTFILES_HOST_PROFILE = 'metal'` to force. After winget, it also:

- installs Claude Code via the official native installer (claude.ai/install.ps1)
- installs fonts declared in `pkg/windows-fonts.txt` per-user (no admin
  required) via `etc/install-windows-fonts.ps1` — used to bring Nerd Font
  glyphs onto Windows for Starship icons (winget has no Nerd Font manifest)
- merges `xdg-config/windows/windows-terminal/overlay.json` into the user's
  Windows Terminal `settings.json` via `etc/wt-apply-settings.ps1` (only
  the keys we declare are written; host-specific profile entries are
  preserved; the original is backed up first)

The Windows deploy is intentionally narrower than the bash side — it links the
PowerShell profile (to `$PROFILE`), `.vimrc`, and `.vim/`. Apps without a
clean Windows XDG story (gh, git, rstudio, …) are skipped. `.tmux.conf` is
also skipped: native Windows has no tmux, and WSL has its own filesystem.

## git identity

This repo is public, so it carries no `user.name`/`user.email` — the deployed
`~/.config/git/config` has only portable settings. On a fresh machine the first
`git commit` therefore fails with `Author identity unknown` until you set one.

`etc/install` seeds it from your gh account, but only if you are already logged
in; on a first run `gh auth login` has not happened yet (it comes below), so the
installer skips the step and says so at the end. Either re-run it afterwards, or
set the identity by hand:

```bash
gh auth login && bash etc/install    # a re-run seeds it from your account
# or
git config --global user.name  'Your Name'
git config --global user.email 'you@example.com'
```

Identity goes in `~/.gitconfig`, not `~/.config/git/config`. Git reads both and
`~/.gitconfig` wins for single-valued keys, so keeping identity there means the
file that wins is also the file `git config --global` edits. Per-machine
overrides that are not identity can go in `~/.config/git/config.local`, which the
deployed config includes automatically when present.

## Optional: private overlay

User-specific files (personal bookmarks, identity-bearing config, private
package manifests) live in a separate private repo at
`kenjisato/dotfiles-private`. After the main setup completes (`gh` and
`ghq` are now installed), authenticate and clone it as an overlay:

### macOS / Linux / WSL2

```bash
gh auth login
ghq get kenjisato/dotfiles-private
PRIVATE=$(ghq list -p | grep dotfiles-private)
bash "$PRIVATE/etc/install"
bash "$PRIVATE/etc/deploy"
```

### Windows (PowerShell)

```powershell
gh auth login
ghq get kenjisato/dotfiles-private
$private = ghq list -p | Select-String dotfiles-private
cd $private
pwsh -File etc\install.ps1
pwsh -File etc\deploy.ps1
```

`dotfiles-private/etc/deploy` is a thin shim — it sets `$DOTFILES_PRIVATE`
to its own location and execs the public `etc/deploy`. The public deploy
then overlays private files on top of public ones (same destination path
→ private wins). Override the public repo location with `$DOTFILES` if
it isn't at `~/dotfiles` (or `$HOME\dotfiles` on Windows).

## Previewing and undoing

`etc/deploy` is idempotent and supports `--dry-run` (`-DryRun` for the
PowerShell variant) to preview symlinks without applying them.

`etc/undeploy` (and `etc/undeploy.ps1`) walks `$HOME` and removes only
symlinks whose target resolves into either repo — regular files are
never touched. Useful when retiring a host or when an old target was
removed from `etc/deploy` and left an orphan symlink behind.

## Upgrading

Tools installed by `etc/install` bypass the system package manager and need
their own update commands:

```bash
rustup update                # Rust toolchain (if cargo-tools.txt has entries)
uv self update               # uv (Python package manager)
brew update && brew upgrade  # everything in pkg/Brewfile, ghq included
claude update                # Claude Code (native installer)
```

Updates aren't automated on purpose — run them when you want a refresh.
[`cargo-update`](https://github.com/nabijaczleweli/cargo-update) (`cargo
install cargo-update`) makes the cargo ones nicer (`cargo install-update -a`),
but it's opt-in.

### On a machine set up before `git/config` was tracked

`xdg-config/common/git/config` used to be `config.example`, copied to
`~/.config/git/config` by hand. `etc/deploy` skips a destination that is a real
file rather than a symlink, so on those machines it prints a notice and leaves
your copy alone — nothing breaks, and `core.hooksPath` is still in `~/.gitconfig`
from the older installer. To pick up the tracked version instead, move any
identity lines into `~/.gitconfig`, anything else machine-specific into
`~/.config/git/config.local`, then delete the hand-made file and re-run
`bash etc/deploy`.

## Layout

| Path | Purpose |
|---|---|
| [home/](home/) | `~/.*` files split by OS (`common/`, `macos/`, `linux/`, `wsl/`, `windows/`) |
| [shell/](shell/) | `zsh/` and `bash/` config, both linked into `~` regardless of current shell |
| [xdg-config/](xdg-config/) | Per-app dirs symlinked into `~/.config/<app>` (NOT the whole `.config`) |
| [bin/](bin/) | Scripts symlinked into `~/bin`, split by OS |
| [pkg/Brewfile](pkg/Brewfile) | Homebrew manifest |
| [pkg/winget-packages*.txt](pkg/) | winget manifest (Windows). `.metal.txt` for bare-metal-only |
| [pkg/uv-tools.txt](pkg/uv-tools.txt) | Python dev tools installed via `uv tool install` |
| [pkg/cargo-tools.txt](pkg/cargo-tools.txt) | Rust tools installed via `cargo install` |
| [pkg/windows-fonts.txt](pkg/windows-fonts.txt) | Windows fonts (GitHub release ZIPs) installed per-user via HKCU |
| [pkg/linux-fonts.txt](pkg/linux-fonts.txt) | Linux fonts (GitHub release ZIPs) installed per-user into `~/.local/share/fonts` |
| [etc/](etc/) | Setup scripts |

## Key features

- **Global git pre-commit secret scan**: `etc/install` sets `core.hooksPath = ~/.config/git/hooks` and `etc/deploy` symlinks `xdg-config/common/git/hooks/pre-commit` into it. Every commit on every repo runs [gitleaks](https://github.com/gitleaks/gitleaks) against staged changes and blocks if a secret-shaped string is found. Bypass with `git commit --no-verify` only when you have a reason; CI should re-scan on push as a backstop. False positives go in `.gitleaks.toml` per-repo
- **Shell**: zsh with [starship](https://starship.rs) prompt (Nerd Font required for icons; installed automatically on macOS via Brewfile, on Windows via `pkg/windows-fonts.txt`, and on Linux via `pkg/linux-fonts.txt`)
- **Repository management**: [ghq](https://github.com/x-motemen/ghq) — `ghq get <url>`, `ghq list`, `ghq list -p` (full paths). Default root `~/ghq`; layout `<host>/<owner>/<repo>`.
- **Ctrl+]**: fzf picker over `ghq list -p` → `cd` to selection ([shell/zsh/.zsh/20-fzf.zsh](shell/zsh/.zsh/20-fzf.zsh)); same binding in PowerShell ([xdg-config/windows/powershell/Microsoft.PowerShell_profile.ps1](xdg-config/windows/powershell/Microsoft.PowerShell_profile.ps1))
- **`cdb`**: bookmark navigation (`cdb /list`, `cdb /add <name>`, `cdb <name>`)
- **Python**: [uv](https://docs.astral.sh/uv/) for package management
- **Writing**: typst, pandoc
- **Japanese input (Linux)**: Mozc keybindings in [xdg-config/linux/mozc/](xdg-config/linux/mozc/)
- **Terminal (Linux)**: lxterminal colours/keybindings and the Nerd Font setting in [xdg-config/linux/lxterminal/](xdg-config/linux/lxterminal/). lxterminal writes this file back through the symlink when you use its Preferences dialog, so a GUI tweak shows up as an uncommitted change here

## Migrating from the old layout

If you previously ran a deploy that symlinked `~/.config` or `~/bin` as whole
directories pointing into the repo, `etc/deploy` will refuse to run and print
migration steps. In short:

```bash
# ~/.config — preserve live app state (gh tokens, podman state, ...)
cp -R "$HOME/.config/" ~/.config-backup/
rm "$HOME/.config"
mkdir "$HOME/.config"
cp -R ~/.config-backup/* "$HOME/.config/"
rm -rf ~/dotfiles/.config       # stale data inside the repo

# ~/bin — nothing to preserve (it just held symlinks)
rm "$HOME/bin"
mkdir "$HOME/bin"

bash ~/dotfiles/etc/deploy
```
