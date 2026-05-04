# dotfiles

Cross-platform dotfiles for macOS, Linux (Ubuntu), and WSL2. Deployment is symlink-based with per-OS dispatch.

## Quick start

```bash
git clone https://github.com/kenjisato/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash etc/install            # Homebrew + zsh default shell + Rust + uv
bash etc/deploy --dry-run   # Preview symlinks
bash etc/deploy             # Apply
```

`etc/deploy` detects the OS (`macos` / `linux` / `wsl`) and only links the relevant files.

### Optional: private overlay

User-specific files (personal bookmarks, identity-bearing config) live in a
separate private repo at `kenjisato/dotfiles-private`. After installing the
basics and `gh auth login`:

```bash
ghq get kenjisato/dotfiles-private                # → ~/ghq/github.com/kenjisato/dotfiles-private
bash $(ghq list -p | grep dotfiles-private)/etc/deploy
```

`dotfiles-private/etc/deploy` is a thin shim — it sets `$DOTFILES_PRIVATE` to
its own location and execs `~/dotfiles/etc/deploy`. The public deploy then
overlays private files on top of public ones (same destination path → private
wins). Override the public repo location with `$DOTFILES` if it isn't at
`~/dotfiles`.

### macOS

```bash
xcode-select --install
# (then the steps above)
brew bundle --file=pkg/Brewfile
```

### Ubuntu / WSL2

```bash
sudo apt update && sudo apt install -y curl git zsh build-essential
# (then the quick-start steps)
brew bundle --file=pkg/Brewfile   # uses Linuxbrew; cask entries auto-skipped
```

### Windows (PowerShell)

```powershell
git clone https://github.com/kenjisato/dotfiles.git $HOME\dotfiles
cd $HOME\dotfiles
pwsh -File etc\install.ps1 -DryRun  # preview package install
pwsh -File etc\install.ps1          # winget packages
pwsh -File etc\deploy.ps1 -DryRun   # preview symlinks
pwsh -File etc\deploy.ps1           # apply symlinks
```

`etc/install.ps1` reads `pkg/winget-packages*.txt` and runs `winget install`
for each entry. Manifests with the `.metal.txt` suffix are skipped on
Parallels VMs (detected via WMI Manufacturer = Parallels); override with
`$Env:DOTFILES_HOST_PROFILE = 'metal'` to force. After winget, it also
installs Claude Code via the official native installer (claude.ai/install.ps1).

Symlink creation requires either an elevated shell (Run as Administrator) or
**Developer Mode** enabled (Settings → For developers → Developer Mode = ON).

The Windows deploy is intentionally narrower than the bash side — it links the
PowerShell profile (to `$PROFILE`), `.vimrc`, `.tmux.conf`, and `.vim/`. Apps
without a clean Windows XDG story (gh, git, rstudio, …) are skipped.

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
| [etc/](etc/) | Setup scripts |

## Key features

- **Shell**: zsh with [starship](https://starship.rs) prompt (requires Hack Nerd Font)
- **Repository management**: [ghq](https://github.com/x-motemen/ghq) — `ghq get <url>`, `ghq list`, `ghq list -p` (full paths). Default root `~/ghq`; layout `<host>/<owner>/<repo>`.
- **Ctrl+]**: fzf picker over `ghq list -p` → `cd` to selection ([shell/zsh/.zsh/20-fzf.zsh](shell/zsh/.zsh/20-fzf.zsh))
- **`cdb`**: bookmark navigation (`cdb /list`, `cdb /add <name>`, `cdb <name>`)
- **Python**: [uv](https://docs.astral.sh/uv/) for package management
- **Writing**: typst, pandoc
- **Japanese input (Linux)**: Mozc keybindings in [xdg-config/macos/mozc/](xdg-config/macos/mozc/)

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
