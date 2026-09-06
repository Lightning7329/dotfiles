# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

The chezmoi source directory for personal dotfiles. There is no build, no test
suite, and no linter — the "program" is the set of chezmoi source-state files,
and the only way to run it is to render and apply it.

`README.md` documents the design (profile detection, symlink vs file mode, the
appended shell block, the git config split, the settings filter, the
notification path). Read it before making structural changes; the notes below
cover what it does not — the traps, not the rationale. Where both files touch
the same subject, the rationale belongs there and only there.

## Verifying a change

```sh
chezmoi diff                         # preview what apply would change
chezmoi apply -v -n                  # dry run with verbose output
chezmoi apply                        # deploy
chezmoi execute-template < file.tmpl # render one template with real data
chezmoi execute-template '{{ .profile }}'
chezmoi data                         # the full template data (profile, mode, name, email)
chezmoi doctor                       # check the install / config
```

Templates only ever run against *this* machine's profile. To check the other
branches of a template, feed the value in explicitly rather than trusting it by
inspection:

```sh
chezmoi execute-template --init --promptString name=x,email=y < .chezmoi.toml.tmpl
```

(`promptStringOnce` reuses values already in `~/.config/chezmoi/chezmoi.toml`,
so `--promptString` only fills in what is missing.)

`.chezmoi.toml.tmpl` is only re-rendered by `chezmoi init`, not by `apply`.
After editing it, run `chezmoi init` to regenerate
`~/.config/chezmoi/chezmoi.toml`.

## Editing conventions

On this machine (`private` profile, `mode = "symlink"`) the deployed dotfiles
are symlinks back into this repository, and this directory *is* `sourceDir`.
Editing a file here changes the live config immediately — no `apply` needed.
Exceptions that do need `chezmoi apply`: anything ending in `.tmpl`, the
`modify_` scripts, `symlink_` entries, `.chezmoiignore`, and anything under
`.chezmoiscripts/`.

Also `executable_` and `private_` files. Symlink mode cannot express a mode
bit — permissions would follow the link target — so chezmoi writes those as
real files instead of links, and the deployed copy goes stale until you
apply. `dot_claude/bin/executable_bell.sh` is the one that bites today.

Never edit the deployed path (`~/.zshrc`, `~/.gitconfig`, …) for managed files;
edit the source here. New files that appear inside a managed directory are real
files rather than links — bring them in with `chezmoi add <path>`.

## Things that are easy to get wrong

**`.chezmoiignore` matches target paths, not source names.** Entries are
`.zsh/darwin.zsh` and `Library`, never `dot_zsh/darwin.zsh` or
`private_Library`. It is itself a template, evaluated per machine.

That stripping applies to `run_` too, which is what makes ignoring a script
non-obvious: `.chezmoiscripts/run_install-vscode-extensions.sh` has to be
written `.chezmoiscripts/install-vscode-extensions.sh` — directory kept,
attribute gone. `chezmoi managed` prints the path to match. A pattern that
misses simply does nothing, so confirm the script stops running rather than
trusting the spelling.

**Order matters in `.chezmoi.toml.tmpl`.** The `container` test (`/.dockerenv`)
must stay before the WSL2 test, because a Dev Container on WSL2 satisfies both.

**`modify_dot_zshrc` / `modify_dot_bashrc` are filters, not files.** They read
the existing file on stdin and write the replacement on stdout. The `sed` that
strips the previous `# >>> chezmoi managed >>>` block is what makes `apply`
idempotent — keep the strip and the emit in sync, and keep both marker strings
identical between the two scripts.

Inside those heredocs the shell body is quoted for the *outer* `sh`, so `$HOME`
and friends are written `\$HOME`. An unescaped `$` gets expanded at apply time
and bakes a literal value into the user's rc file.

**Shell config goes in `dot_zsh/` or `dot_bash/`, not in the rc file.** Files
are sourced in alphabetical order, so `common` loads before `darwin`/`linux`
and the OS-specific file is the one that overrides. Keep the zsh and bash alias
sets in step — they are deliberately parallel and currently duplicated by hand.

**Git identity never lives in this repository.** `dot_gitconfig.tmpl` renders
`.name` / `.email` from `~/.config/chezmoi/chezmoi.toml`. Shared git settings go
in `dot_config/git/config` (the XDG file), macOS-only ones in
`dot_config/git/darwin.conf`, which is pulled in by an `[include]` that Git
ignores when the file is absent. That is the mechanism for platform-specific git
settings — do not add conditionals to the template.

**VS Code config is canonical in `dot_config/vscode/`.** The
`private_Library/.../User/symlink_*.tmpl` files contain only a target path and
exist to point the macOS location at that canonical copy. Add real settings to
`dot_config/vscode/`.

**Attribute order stacks in a fixed sequence — `private_` goes after
`modify_`, not before.** The correct name is `modify_private_settings.json`.
Get the order wrong (`private_modify_settings.json`) and chezmoi silently
stops treating the file as a script: it reads as a literal filename instead,
`chezmoi diff` shows a bogus new file being created rather than a diff against
the real target, and the `private_` permissions (0600) are lost. Verify any
new multi-attribute file name with `chezmoi diff` before trusting it.

**A `run_` script under `.chezmoiscripts/` doesn't correspond to a target
file.** `chezmoi diff` renders it as though a file will be created at that
path, but nothing is actually written there — the path is only a bookkeeping
key for `run_once_`/`run_onchange_` change-detection and for ordering. Reading
that diff as a real deployment is the mistake; keep such scripts in
`.chezmoiscripts/` rather than under `dot_claude/` or any other `dot_*`
directory, where everything else really is deployed.

**Not every key in `~/.claude/settings.json` belongs to this repository.**
Claude Code rewrites the file itself during normal use (`/model`, `/fast`,
`/hooks`, plugin state, permission approvals, the statusline installer).
README covers what `dot_claude/modify_private_settings.json` owns and why
`hooks` is assigned rather than merged. Before adding a key to `managed`, check
whether Claude Code itself ever writes it; if so, leave it out, or the next
`chezmoi apply` will silently revert whatever the user changed interactively.

`jq`'s `*` merges recursively, so it can add and override but never *remove*.
Any key whose deletions have to take effect must be assigned the way `hooks` is
(`.hooks = ($managed.hooks // {})`) instead of being left to the merge; the
`// {}` keeps a bare `null` out of the target when `managed` has no `hooks` at
all.

**Never pipe the file through `echo` inside that filter.** `sh`'s `echo`
interprets backslash escapes on dash *and* on the macOS `/bin/sh`, so a
`settings.json` holding a JSON `\\` or `\t` reaches `jq` mangled and the filter
dies with a parse error. Use `printf '%s\n'`.

**A `modify_` script that fails is nearly invisible.** chezmoi prints one line
of stderr, leaves the target untouched, and finishes with an overall exit 0 —
so the only symptom is that the hooks were never deployed. That is also why the
filter bails out early when `jq` is missing rather than letting the pipeline
break: `install.sh` installs only chezmoi, and slim container images ship no
`jq`.

## Commit messages

English, imperative mood, one line, no prefix or scope
(`Add shell aliases (printpath and dps)`).
