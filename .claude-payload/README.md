# Claude Code configuration

The contents of `~/.claude/` are not chezmoi targets. They are deployed by
[`.chezmoiscripts/run_setup-claude-config.sh.tmpl`](../.chezmoiscripts/run_setup-claude-config.sh.tmpl),
and this directory is the material it draws from — the leading dot is what
keeps chezmoi from picking it up as source state. The script holds only the
*how*; the *what* lives here:

| File                    | Becomes                                  |
| ----------------------- | ---------------------------------------- |
| `bell.sh`               | `~/.claude/bin/bell.sh`, mode 755         |
| `settings.managed.json` | merged into `~/.claude/settings.json`     |

The repository [README](../README.md) explains why `settings.json` is filtered
instead of managed wholesale, and why turn-completion notifications go out
through the terminal; the notes below are the traps.

## Letting chezmoi manage the directory destroys a symlink

This is why the layout looks the way it does. With a `dot_claude/` in the
source, chezmoi treats `~/.claude` as a target that must be a directory: if it
finds a symlink there, it deletes it and creates a real directory in its place.
Unlike overwriting a file, this raises no prompt — nothing says so unless you
read `chezmoi diff`.

```
diff --git a/.claude b/.claude
deleted file mode 120755   ← the symlink is removed
new file mode 40755        ← a real directory takes its place
```

In an environment that symlinks `~/.claude` to a host directory — a Dev
Container, typically — that severs the configuration from its real location.
The link target survives untouched, which is exactly what makes it look like
the settings vanished. `chezmoi apply` has no option to follow a symlinked
destination (`--follow` belongs to `add`), so the only fix is to have no
directory target at all. A shell redirect follows the symlink, so writing the
files from a script passes straight through.

**A source directory whose entries are all covered by `.chezmoiignore` still
gets created as a target directory.** So "keep `dot_claude/` for the README
alone" is not an option — the directory itself has to go.

## Neither file is expanded as a template

The script reads both with `include` and feeds them to quoted heredocs.
`include` reads a file literally, relative to the source directory; unlike
`includeTemplate` it does not render it. So a `{{` in either file breaks
nothing, and `$HOME`, backslashes and quotes are written out as-is — which is
what lets `settings.managed.json` carry `"$HOME/.claude/bin/bell.sh"` verbatim
for Claude Code to expand at hook time.

The flip side is that neither file gets a syntax check from chezmoi. A typo in
`settings.managed.json` surfaces as a `jq` parse error at apply time, which
fails the script and stops `chezmoi apply` — early, since `.chezmoiscripts`
sorts near the front of the target order. That is the intended feedback loop;
`~/.claude/settings.json` is left untouched when it happens.

## Not every key in `~/.claude/settings.json` belongs to this repository

Claude Code rewrites the file itself during normal use (`/model`, `/fast`,
`/hooks`, plugin state, permission approvals, the statusline installer). Before
adding a key to `settings.managed.json`, check whether Claude Code ever writes
it; if so, leave it out, or the next `chezmoi apply` will silently revert
whatever the user changed interactively.

## The mode of `settings.json` is not managed

`bell.sh` gets an explicit `chmod 755`, because a hook body has to be
executable and a fresh file would come out 644. `settings.json` gets no `chmod`
at all — it is written with a plain redirect, which keeps the mode of an
existing file and leaves a new one to `umask`.

That is the default Claude Code itself produces. It writes `settings.json` at
the ambient umask (0644 on a stock macOS account) and reserves 0600 for the
files that actually hold private data — `history.jsonl`, `~/.claude.json` and
its backups, `projects/`, `sessions/`, `ide/`. This repository used to force
0600 here, inherited from the `private_` attribute on the old
`modify_private_settings.json`, not from a decision.

The case for 0600 is that `env` and `apiKeyHelper` are documented keys where a
credential could land. If one ever does, tighten it deliberately then — and
note that a mode alone would not be enough, since the source file lives in a
public repository.

## Which `Notification` matchers are listed, and why

JSON has no comments, so the reasoning for the matcher list lives here. It
enumerates only the events that mean *Claude is waiting on a human*:

| Matched                    |                                            |
| -------------------------- | ------------------------------------------ |
| `permission_prompt`        | waiting for an approval                    |
| `agent_needs_input`        | a subagent is asking                       |
| `elicitation_dialog`       | waiting on a dialog                        |
| `elicitation_url_dialog`   | waiting on a URL dialog                    |

Deliberately excluded: `idle_prompt` and `agent_completed`, because `Stop` has
already rung for the completed response and this would be a second bell for the
same event; `auth_success`, `elicitation_complete`, `elicitation_response` and
`quota_auto_resume_*`, because they report rather than ask for anything.

## `jq`'s `*` merge can add and override, but never remove

It merges recursively, so a key deleted from `settings.managed.json` would live
on in the target forever. Any key whose deletions have to take effect must be
assigned the way `hooks` is (`.hooks = ($managed.hooks // {})`) instead of
being left to the merge; the `// {}` keeps a bare `null` out of the target when
`settings.managed.json` has no `hooks` at all. Today `hooks` is the only key in
that file, so the merge itself is idling — the structure is there for when a
second key arrives.

## Never pipe JSON through `echo`

`sh`'s `echo` interprets backslash escapes on dash *and* on the macOS
`/bin/sh`, so a `settings.json` holding a JSON `\\` or `\t` reaches `jq`
mangled and the filter dies with a parse error. The script now hands the path
to `jq` directly, which removes that route entirely — but keep using
`printf '%s\n'` on the way out.

## Both files go stale until you apply

Even on a machine in symlink mode, these are copied at deploy time (`bell.sh`
through the heredoc, `settings.json` as the result of the `jq` merge). Unlike
the rest of the dotfiles, editing the source here does not take effect until
`chezmoi apply` runs.
