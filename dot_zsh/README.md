# Shell configuration

Covers `dot_zsh/`, `dot_bash/`, and the `modify_dot_zshrc` / `modify_dot_bashrc`
filters at the repository root. The repository [README](../README.md) explains
why the managed block is appended to the rc file rather than replacing it; the
notes below are the traps.

## Config goes in `dot_zsh/` or `dot_bash/`, not in the rc file

The rc files carry nothing but the loader block. Every real setting belongs in
`dot_zsh/*.zsh` or `dot_bash/*.bash`.

Files are sourced in alphabetical order, so `common` loads before
`darwin`/`linux` and the OS-specific file is the one that overrides.

Keep the zsh and bash alias sets in step — they are deliberately parallel and
currently duplicated by hand.

## `modify_dot_zshrc` / `modify_dot_bashrc` are filters, not files

They read the existing file on stdin and write the replacement on stdout. The
`sed` that strips the previous `# >>> chezmoi managed >>>` block is what makes
`apply` idempotent — keep the strip and the emit in sync, and keep both marker
strings identical between the two scripts.

Inside those heredocs the shell body is quoted for the *outer* `sh`, so `$HOME`
and friends are written `\$HOME`. An unescaped `$` gets expanded at apply time
and bakes a literal value into the user's rc file.

Being scripts, they need `chezmoi apply` to take effect even in symlink mode —
unlike the `.zsh` / `.bash` files here, which are live symlinks.
