# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

The chezmoi source directory for personal dotfiles. There is no build, no test
suite, and no linter — the "program" is the set of chezmoi source-state files,
and the only way to run it is to render and apply it.

`README.md` documents the design (profile detection, symlink vs file mode, the
appended shell block, the git config split, the settings filter, the
notification path). Read it before making structural changes. This file and the
per-directory `README.md` files below cover what it does not — the traps, not
the rationale. Where a subject is covered in both, the rationale belongs in a
README and only there.

## Where the per-area notes live

Read the one that matches what you are about to touch:

| Area                                                        | Notes                                                     |
| ----------------------------------------------------------- | --------------------------------------------------------- |
| Shell — `dot_zsh/`, `dot_bash/`, `modify_dot_zshrc`, `modify_dot_bashrc` | [dot_zsh/README.md](dot_zsh/README.md)         |
| Claude Code — `settings.json` filter, notification hook     | [dot_claude/README.md](dot_claude/README.md)               |
| Git — identity, XDG split, platform overrides               | [dot_config/git/README.md](dot_config/git/README.md)       |
| VS Code — canonical config, macOS symlinks                  | [dot_config/vscode/README.md](dot_config/vscode/README.md) |

`.chezmoiscripts/` has no `README.md` on purpose: chezmoi refuses to load a
non-script file from that directory, and `.chezmoiignore` cannot suppress the
error. Notes about those scripts stay here.

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
real files instead of links, and the deployed copy goes stale until you apply.

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

Patterns are not implicitly recursive either: a bare `README.md` matches only
the one at the root, which is why the ignore list also carries `**/README.md`
for the per-directory notes.

**Order matters in `.chezmoi.toml.tmpl`.** The `container` test (`/.dockerenv`)
must stay before the WSL2 test, because a Dev Container on WSL2 satisfies both.

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

## Commit messages

English, imperative mood, one line, no prefix or scope
(`Add shell aliases (printpath and dps)`).
