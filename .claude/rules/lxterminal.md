---
paths:
  - "xdg-config/linux/lxterminal/*"
---

# lxterminal.conf writes back through the symlink

`xdg-config/linux/lxterminal/lxterminal.conf` is deployed as a symlink like everything else, but lxterminal is one of the few apps here that *writes* its own config. Verified on lxterminal 0.4.1:

- It does **not** touch the file on ordinary startup or exit — only the Preferences dialog saves.
- It serializes with `g_key_file_to_data` and writes with plain `open`/`write`, **not** a temp-file-plus-`rename`. So `open` follows the symlink: the link survives and the *tracked file in this repo* is what changes.

Consequences, neither fatal but both worth knowing:

- Clicking OK in Preferences leaves uncommitted changes in this repo. `git diff` shows exactly what the dialog changed, which makes the GUI a usable editor for the tracked config — commit it, or `git checkout` to discard.
- `g_key_file` is loaded without `KEEP_COMMENTS`, so a Preferences save **drops every comment** in the file. That is why the tracked conf carries no header comment: keeping it byte-identical to what lxterminal itself writes keeps those diffs minimal. Document this file here, not inside it.

On a Linux box that already has a real `~/.config/lxterminal/lxterminal.conf`, `etc/deploy` skips it with a notice rather than overwriting — move it aside and re-run deploy to adopt the tracked one. Only `OS=linux` receives this file; WSL resolves to `xdg-config/wsl/`.

Font size lives here too, so it is global rather than per-machine. lxterminal has no include mechanism, so if a second Linux box ever needs a different size, either accept the diff or move to the `overlay.json` + apply-script pattern used for Windows Terminal.
