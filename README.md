# dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

A single repository that provisions three different environments — a personal
macOS machine, a work WSL2 install, and ephemeral VS Code Dev Containers —
without maintaining three copies of anything.

## Design

**One entry point, declarative differences.** There is a single `install.sh`.
Which files get deployed is decided by [`.chezmoiignore`](.chezmoiignore), and
per-machine values are filled in by templates. No branching install scripts.

**Profiles are detected, not configured.** `.chezmoi.toml.tmpl` inspects the
machine at `chezmoi init` time and picks a profile:

| Profile     | Detected by                                     | `mode`    |
| ----------- | ----------------------------------------------- | --------- |
| `container` | `/.dockerenv` exists                            | `file`    |
| `work`      | Linux whose kernel release contains `microsoft` | `symlink` |
| `private`   | anything else (macOS)                           | `symlink` |

`container` is checked first on purpose: a Dev Container running on WSL2 also
looks like WSL2, so the more specific test has to win.

**Edits flow back upstream.** On macOS and WSL2, chezmoi runs in `symlink`
mode, so `~/.zsh/common.zsh` and friends are symlinks into this repository.
Editing a config file — by hand or through the VS Code settings UI — shows up
directly in `git diff`. Containers use `file` mode instead, since nothing is
edited there and dangling symlinks into a scratch clone are a liability.

**Shell config is appended, not overwritten.** Dev Container base images ship
their own `.bashrc` and `.zshrc` (`PATH` setup, oh-my-zsh, …). Overwriting them
breaks the container. `modify_dot_bashrc` and `modify_dot_zshrc` are scripts:
they receive the current file on stdin and re-emit it with a single managed
block appended.

```sh
# >>> chezmoi managed >>>
for f in "$HOME"/.zsh/*.zsh(N); do
    source "$f"
done
# <<< chezmoi managed <<<
```

The block is delimited by markers and stripped before being re-added, so
`chezmoi apply` is idempotent. All real configuration lives in `~/.zsh/*.zsh`
and `~/.bash/*.bash`, which are loaded in alphabetical order — `common` first,
then the OS-specific file that overrides it.

**Claude Code owns most of its own settings.** `~/.claude/settings.json` is
rewritten by Claude Code itself during normal use — model/effort-level
switches, permission approvals, plugin state, the statusline installer.
Managing the whole file would fight that. `.chezmoiscripts/run_setup-claude-config.sh.tmpl`
is a filter, like the shell rc scripts above: it takes over exactly one key,
`hooks`, and passes every other key through untouched.

`hooks` is *replaced* rather than merged, which is a deliberate trade. Merging
can add and override but never remove, so a hook deleted from the source would
live on in the target forever; replacing makes deletions take effect. The price
is that hooks added interactively through `/hooks` do not survive the next
`chezmoi apply`.

**Turn-completion notifications go out through the terminal.** Claude Code has
no notification event for "the response just finished" — the only completion
signal is an idle timer that fires tens of seconds late. So `Stop` and
`Notification` hooks run `.claude-payload/bell.sh`, which writes an OSC 777
escape sequence to the terminal device Claude Code is attached to, and a VS
Code extension turns that into a desktop notification.

The extension is `ui`-kind, so it runs on the host — which is what lets a
sequence emitted inside a Dev Container reach the host's notification centre.
`.chezmoiscripts/run_install-vscode-extensions.sh` installs it, and only under
the `private` profile: in a container or on WSL2 the `code` CLI drives the
remote extension host, where a `ui` extension does not belong.

**External binaries are installed by a script, not vendored.** The statusline
binary ([cc-statusline](https://github.com/Lightning7329/cc-statusline)) is a
compiled, platform-specific release asset, so it's downloaded rather than
committed. `.chezmoiscripts/run_onchange_install-cc-statusline.sh.tmpl` runs
its installer via `curl`; the `gitHubLatestRelease` template function embeds
the latest tag name in a comment, so a new upstream release changes the
rendered script and `run_onchange_` picks it up automatically on the next
`chezmoi apply`.

Neither of those two produces a deployed file, which is why they live in
`.chezmoiscripts/`.

**`~/.claude/` is deployed by a script rather than managed as a target.** A
directory in the source state forces the destination to be a real directory:
where `~/.claude` is a symlink — a Dev Container pointing at a host directory,
say — chezmoi deletes the link and creates a directory in its place, silently,
and the configuration is cut off from where it actually lives. There is no
"follow the destination symlink" option to turn on, so the directory target is
gone instead. `.chezmoiscripts/run_setup-claude-config.sh.tmpl` writes
`bin/bell.sh` and merges `settings.json` through ordinary shell redirects,
which follow the symlink. That script holds only the deployment logic; what it
deploys — `bell.sh` and the `settings.json` keys this repo owns — sits in
`.claude-payload/` as ordinary files, whose leading dot keeps chezmoi from
treating them as source state. The `include` template function pulls them into
the rendered script verbatim.

The cost is that `chezmoi diff` and `chezmoi status` say nothing about those
two files. The script simply rewrites them on every `chezmoi apply`, so running
apply is the only way to see where they stand.

## Installation

### macOS / WSL2

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply Lightning7329
```

You will be prompted once for a Git user name and email. They are written to
`~/.config/chezmoi/chezmoi.toml`, **outside** this repository, and rendered into
`~/.gitconfig` — which is why this repo can stay public.

### Dev Containers

Add the following to your **local** VS Code user settings (`settings.json`).
These are personal settings; they do not affect anyone else working on the same
project.

```json
{
  "dotfiles.repository": "Lightning7329/dotfiles",
  "dotfiles.targetPath": "~/dotfiles",
  "dotfiles.installCommand": "install.sh"
}
```

VS Code clones this repository into every new container and runs `install.sh`,
which bootstraps chezmoi into `~/.local/bin` and applies the `container`
profile.

`install.sh` passes `--source` to `chezmoi init`, and `.chezmoi.toml.tmpl`
records that path back into the generated config as `sourceDir`. `--source` is a
per-invocation flag, so without this every later `chezmoi` command in the
container would fall back to the default `~/.local/share/chezmoi` and find an
empty directory there.

## Layout

| Source                                                       | Target                            | Notes                                                 |
| ------------------------------------------------------------ | --------------------------------- | ----------------------------------------------------- |
| `dot_zsh/`, `modify_dot_zshrc`                               | `~/.zsh/`, `~/.zshrc`             | loader stub + `common`/OS files                       |
| `dot_bash/`, `modify_dot_bashrc`                             | `~/.bash/`, `~/.bashrc`           | same structure as zsh                                 |
| `dot_zprofile`                                               | `~/.zprofile`                     | macOS only (`brew shellenv`)                          |
| `dot_gitconfig.tmpl`                                         | `~/.gitconfig`                    | identity, from local prompt values                    |
| `dot_config/git/config`                                      | `~/.config/git/config`            | aliases and shared options                            |
| `dot_config/git/darwin.conf`                                 | `~/.config/git/darwin.conf`       | Sourcetree diff/merge, macOS only                     |
| `dot_config/vscode/`                                         | `~/.config/vscode/`               | canonical VS Code config                              |
| `private_Library/…/User/symlink_*`                           | `~/Library/…/Code/User/*`         | macOS paths → canonical config                        |
| `dot_vimrc`, `dot_gitignore_global`                          | `~/.vimrc`, `~/.gitignore_global` | shared everywhere                                     |
| `.chezmoiscripts/run_setup-claude-config.sh.tmpl`            | `~/.claude/{settings.json,bin/bell.sh}` | script-deployed, so a symlinked `~/.claude` survives |
| `.claude-payload/bell.sh`                                    | via the script above              | hook body; emits OSC 777 for desktop notifications     |
| `.claude-payload/settings.managed.json`                      | via the script above              | the keys this repo owns in `settings.json` — `hooks`   |
| `.chezmoiscripts/run_onchange_install-cc-statusline.sh.tmpl` | *(script only, no target)*        | installs/updates the statusline binary                 |
| `.chezmoiscripts/run_install-vscode-extensions.sh`           | *(script only, no target)*        | installs host VS Code extensions, `private` only       |

Git config is deliberately split in two. Everything shared lives in
`~/.config/git/config`, the XDG location Git reads on its own, and `~/.gitconfig`
carries nothing but identity. That split is what makes containers work: VS Code
copies the host `~/.gitconfig` into the container at creation time, so
`.chezmoiignore` skips ours there and the inherited identity and credential
helper survive — while the shared aliases still arrive through the XDG file.

`~/.config/git/config` pulls platform-specific settings in through an
`[include]` directive. Git silently ignores includes whose target is missing, so
a file that `.chezmoiignore` skips simply has no effect — no conditionals
required.

VS Code stores its user config under a different path on every OS, but all of
them live under `$HOME`. A single canonical copy lives in `~/.config/vscode/`,
and the OS-specific location is a `symlink_` entry pointing at it. Only the
macOS path is wired up today; WSL2 reads its settings from the Windows host,
and containers only get machine-scoped settings.

## Daily use

| Command                    | What it does                                 |
| -------------------------- | -------------------------------------------- |
| `chezmoi edit <file>`      | edit the source, not the deployed file       |
| `chezmoi diff`             | preview what `apply` would change            |
| `chezmoi apply`            | deploy                                       |
| `chezmoi cd`               | open a shell in this repository              |
| `chezmoi update`           | `git pull` then apply                        |
| `chezmoi unmanaged <dir>`  | list files that are not tracked yet          |
| `chezmoi execute-template` | evaluate a template expression interactively |

Two things worth remembering in `symlink` mode: `chezmoi diff` shows link
targets rather than file contents, so use `chezmoi cd && git diff` to review
edits; and new files created inside a managed directory (VS Code snippets, for
instance) are real files, not links — pick them up with `chezmoi add`.

## Not in this repository

Git identity, credentials, and anything else machine-local. Identity is
prompted for at `chezmoi init` and stored in `~/.config/chezmoi/chezmoi.toml`.
