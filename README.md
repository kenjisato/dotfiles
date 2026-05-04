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
basics, `gh auth login`, and `cargo install ghr`:

```bash
ghr clone kenjisato/dotfiles-private             # any clone location works
bash $(ghr path kenjisato/dotfiles-private)/etc/deploy
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
pwsh -File etc\install.ps1          # scoop + winget packages
pwsh -File etc\deploy.ps1 -DryRun   # preview symlinks
pwsh -File etc\deploy.ps1           # apply symlinks
```

`etc/install.ps1` bootstraps scoop, adds the `extras` and `nerd-fonts`
buckets, and installs everything declared under `pkg/scoop-packages*.txt` and
`pkg/winget-packages*.txt`. Manifests with the `.metal.txt` suffix are
skipped on Parallels VMs (detected via the `prl_tools_service` service);
override with `$Env:DOTFILES_HOST_PROFILE = 'metal'` to force.

Symlink creation requires either an elevated shell (Run as Administrator) or
**Developer Mode** enabled (Settings → For developers → Developer Mode = ON).

The Windows deploy is intentionally narrower than the bash side — it links the
PowerShell profile (to `$PROFILE`), `.vimrc`, `.tmux.conf`, and `.vim/`. Apps
without a clean Windows XDG story (gh, git, rstudio, …) are skipped.

## Upgrading

Tools installed by `etc/install` bypass the system package manager and need
their own update commands:

```bash
rustup update                # Rust toolchain
uv self update               # uv (Python package manager)
cargo install ghr --force    # ghr (rebuilds from source)
brew update && brew upgrade  # everything in pkg/Brewfile
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
| [pkg/scoop-buckets.txt](pkg/scoop-buckets.txt) | scoop bucket list (Windows). `<name>` or `<name> <url>` for third-party |
| [pkg/scoop-packages*.txt](pkg/) | scoop manifest (Windows). `.metal.txt` for bare-metal-only |
| [pkg/winget-packages*.txt](pkg/) | winget manifest (Windows). `.metal.txt` for bare-metal-only |
| [etc/](etc/) | Setup scripts |

## Key features

- **Shell**: zsh with [starship](https://starship.rs) prompt (requires Hack Nerd Font)
- **Repository management**: [ghr](https://github.com/siketyan/ghr) (replaces ghq) — `ghr clone <url>`, `ghr list`, `ghr path <name>`. Bash gets the full shell extension; zsh gets completion only (add a `cd` wrapper if needed).
- **Ctrl+]**: fzf picker over `ghr list` → `cd` to selection ([shell/zsh/.zsh/20-fzf.zsh](shell/zsh/.zsh/20-fzf.zsh))
- **`cdb`**: bookmark navigation (`cdb /list`, `cdb /add <name>`, `cdb <name>`)
- **Python**: [uv](https://docs.astral.sh/uv/) for package management
- **Writing**: typst, pandoc
- **Japanese input (Linux)**: Mozc keybindings in [xdg-config/macos/mozc/](xdg-config/macos/mozc/)

## Migrating from ghq to ghr

ghq is dropped from `Brewfile`; ghr is installed via `cargo install ghr` in
`etc/install` (works the same on macOS, Linux, WSL, and Windows — avoids the
non-standard Homebrew tap and scoop). Both tools use an identical
`<root>/<host>/<owner>/<repo>` layout, but the default root differs:

- ghq (old): `~/local/src` (set via `git config --global ghq.root`)
- ghr (new): `~/.ghr` (override with `GHR_ROOT`)

To carry existing clones across without re-cloning:

```bash
brew uninstall ghq                                      # if installed via Brewfile
bash ~/dotfiles/etc/install                             # cargo install ghr
mkdir -p ~/.ghr
mv ~/local/src/* ~/.ghr/                                # works because layouts match
git config --global --unset ghq.root                    # optional — ghq is gone
```

The `cdb` `src` bookmark already points to `~/.ghr` after this commit.

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
