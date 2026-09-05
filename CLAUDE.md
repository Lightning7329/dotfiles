# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

The chezmoi source directory for personal dotfiles. There is no build, no test
suite, and no linter — the "program" is the set of chezmoi source-state files,
and the only way to run it is to render and apply it.

`README.md` documents the design (profile detection, symlink vs file mode, the
appended shell block, the git config split). Read it before making structural
changes; the notes below cover what it does not.

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
key for `run_once_`/`run_onchange_` change-detection and for ordering. Don't
nest these under `dot_claude/` (or any other `dot_*` directory) alongside
entries that map to real deployed files; that breaks the assumption that
everything in there is really deployed. `.chezmoiscripts/` is where
target-less scripts go instead.

**Not every key in `~/.claude/settings.json` belongs to this repository.**
Claude Code rewrites the file itself during normal use (`/model`, `/fast`,
`/hooks`, plugin state, permission approvals, the statusline installer).
`dot_claude/modify_private_settings.json` merges in only the keys this repo
wants to own — currently just `hooks` — with `jq '. * $managed'`, and passes
everything else through untouched. Before adding a key to `managed`, check
whether Claude Code itself ever writes it; if so, leave it out, or the next
`chezmoi apply` will silently revert whatever the user changed interactively.

`jq`'s `*` merges recursively, so it can add and override but never *remove*.
Dropping an entry from `managed` leaves whatever an earlier `apply` already
wrote sitting in the target file forever. `hooks` is therefore assigned rather
than merged (`.hooks = ($managed.hooks // {})`), which is what makes deleting a
hook take effect; the `// {}` keeps a bare `null` out of the target when
`managed` has no `hooks` at all. Any other key that needs deletions has to be
assigned the same way.

## Commit messages

English, imperative mood, one line, no prefix or scope
(`Add shell aliases (printpath and dps)`).
