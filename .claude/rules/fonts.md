---
paths:
  - "pkg/*fonts*"
  - "etc/install-*-fonts*"
  - "xdg-config/windows/windows-terminal/*"
---

# Fonts

Three platforms, three mechanisms, one intent — a Nerd-patched font with Japanese coverage so the starship prompt and Japanese text both render:

| OS | How |
|---|---|
| macOS | `pkg/Brewfile` casks (`font-hack-nerd-font`, `font-hackgen-nerd`, …), kept on the server profile too since headless Quarto/Typst/LaTeX rendering needs them |
| Windows | `etc/install-windows-fonts.ps1` reads `pkg/windows-fonts.txt`, installs per-user into HKCU |
| Linux | `etc/install-linux-fonts` reads `pkg/linux-fonts.txt`, installs per-user into `~/.local/share/fonts` |

Debian/Ubuntu ship **no** Nerd-patched font in apt, which is why Linux needs the GitHub-release path rather than a package name.

## Manifest format

Both manifests use `owner/repo:asset-name-glob:font-name-glob`, deliberately identical so the two stay comparable. The Windows-only `@tag` form (for repos that publish no releases, pulling the latest tag's archive instead) is **unimplemented on Linux** — the script warns and skips rather than pretending to work. Teach it the tags API before adding such a font to `pkg/linux-fonts.txt`.

## install-linux-fonts specifics

- Parses the GitHub API with `grep`/`sed`, not a JSON library, so it needs nothing beyond `curl` and `unzip`; `python3` is not guaranteed on a minimal box.
- Unpacks the whole archive and filters with `find` rather than passing the glob to `unzip`, which would exit non-zero on no match and would not descend into the archive's subdirectories.
- Idempotency is per-repo: `~/.local/share/fonts/<repo>/.release` records the installed release tag, and a run whose latest tag matches is a no-op. Delete the stamp to force a re-download.
- Missing `curl`/`unzip` is a skip, not a failure — `etc/install` calls this non-fatally on Linux only, and fonts must never cost the configuration steps that follow.

## Installing is not using

A terminal emulator with an explicit font setting still has to name the font, though fontconfig will fall back to it for glyphs the configured font lacks. `xdg-config/linux/lxterminal/lxterminal.conf` names `HackGen Console NF`; Windows Terminal gets it from `xdg-config/windows/windows-terminal/overlay.json`, deep-merged by `etc/wt-apply-settings.ps1` so host-specific profile entries survive.

Verify a claim about coverage rather than trusting the font name — `fc-list -f '%{file}\n' :charset=e0b0` shows which files actually carry a given codepoint (`E0B0`/`E0A0` powerline, `F09B` devicons, `3042` kana).
