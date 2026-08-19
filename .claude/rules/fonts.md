---
paths:
  - "pkg/*fonts*"
  - "etc/install-*-fonts*"
  - "xdg-config/windows/windows-terminal/*"
  - "xdg-config/common/starship.toml"
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

## Nerd fonts carry no emoji — which is why starship has a tracked config

Nerd patching adds Powerline and devicon glyphs in the **private-use area**. It adds no emoji, and a Nerd-patched font is the only font this repo installs, so anything in the emoji blocks has no coverage at all on a box that lacks a separate emoji font. Starship's *default* module symbols are emoji, so the default prompt is partly unrenderable on exactly the machines this repo sets up.

Measured on a Debian host with HackGen NF installed and no emoji font (`fc-list :charset=<cp>`):

| Code point | In the prompt | Covered by |
|---|---|---|
| U+1F4E6 (package default) | `📦 v0.1.0` | **nothing** — tofu |
| U+1F40D (python default) | `🐍 v3.9.6` | **nothing** — tofu |
| U+1F310 (hostname ssh_symbol) | `🌐 <host>` | FreeSerif / FreeSans, by luck |
| U+2A01 | a version module | DejaVu, by luck |
| U+E0A0 / U+F418 / U+E235 / U+F03D7 | branch, python, package | HackGen Console NF |

So `xdg-config/common/starship.toml` exists to pin every symbol into the private-use area rather than to add a second font family. It is generated — `starship preset nerd-font-symbols -o xdg-config/common/starship.toml`, then re-add the header — and all 126 symbols in that preset were verified present in HackGen NF v2.10.0, which ships the Nerd Fonts v3 code points. Both `etc/deploy` and `etc/deploy.ps1` link it, because starship reads `~/.config/starship.toml` on Windows too.

The alternative, installing an emoji font (`fonts-noto-color-emoji` on Debian), was rejected: it would put the prompt's appearance back under two font families and add a mechanism outside the three above.

**Over SSH the two halves live on different machines.** The font is on the box drawing the terminal; the starship config is on the box generating the prompt. So a prompt that still shows tofu after this file was deployed locally is usually a remote host running starship's defaults — it needs its own `bash etc/deploy`, not another font. `printf 'nerd python: \ue235\nemoji python: \U0001f40d\n'` in the offending window separates the two: glyph plus box means the font is fine and the config is not.
