# Claude Code configuration

`dot_claude/` mirrors only what actually lands in `~/.claude/`. The repository
[README](../README.md) explains why `settings.json` is filtered instead of
managed wholesale, and why turn-completion notifications go out through the
terminal; the notes below are the traps.

## Not every key in `~/.claude/settings.json` belongs to this repository

Claude Code rewrites the file itself during normal use (`/model`, `/fast`,
`/hooks`, plugin state, permission approvals, the statusline installer). Before
adding a key to `managed` in `modify_private_settings.json`, check whether
Claude Code itself ever writes it; if so, leave it out, or the next
`chezmoi apply` will silently revert whatever the user changed interactively.

## `jq`'s `*` merge can add and override, but never remove

It merges recursively, so a key deleted from the source would live on in the
target forever. Any key whose deletions have to take effect must be assigned
the way `hooks` is (`.hooks = ($managed.hooks // {})`) instead of being left to
the merge; the `// {}` keeps a bare `null` out of the target when `managed` has
no `hooks` at all.

## Never pipe the file through `echo` inside that filter

`sh`'s `echo` interprets backslash escapes on dash *and* on the macOS
`/bin/sh`, so a `settings.json` holding a JSON `\\` or `\t` reaches `jq`
mangled and the filter dies with a parse error. Use `printf '%s\n'`.

## A `modify_` script that fails is nearly invisible

chezmoi prints one line of stderr, leaves the target untouched, and finishes
with an overall exit 0 — so the only symptom is that the hooks were never
deployed. That is also why the filter bails out early when `jq` is missing
rather than letting the pipeline break: `install.sh` installs only chezmoi, and
slim container images ship no `jq`.

## `bin/executable_bell.sh` goes stale until you apply

Symlink mode cannot express a mode bit, so chezmoi writes `executable_` entries
as real files rather than links. Editing the source here leaves
`~/.claude/bin/bell.sh` on the old copy until `chezmoi apply` runs. This is the
one file in the repository where that bites today.
