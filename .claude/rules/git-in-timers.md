---
paths:
  - "bin/*"
  - "bin/**/*"
  - "home/common/.tmux.conf"
  - "shell/zsh/.zsh/30_prompt.zsh"
---

# Anything that calls git on a timer needs --no-optional-locks

Code that shells out to `git` **periodically for display purposes** — tmux `pane-border-format` or status bar, shell prompts, editor gutters — must pass `--no-optional-locks`.

`git status` looks read-only, but it refreshes the index stat cache and takes `.git/index.lock` to do it. A periodic caller therefore makes interactive `git add` / `git commit` in that repo fail intermittently with `Unable to create '.git/index.lock': File exists`. The flag suppresses that write; the output is unchanged.

Currently applies to `bin/common/tmux-pane-border`, re-evaluated every `status-interval` (15s) per bordered pane.

Read-only plumbing (`rev-parse`, `symbolic-ref`) does not take the lock, but adding the flag there costs nothing, so add it by default rather than auditing which subcommand is safe.
