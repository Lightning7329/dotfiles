# Git configuration

Deliberately split in two: identity in `~/.gitconfig`, everything shared in
this directory (`~/.config/git/`, the XDG location Git reads on its own). The
repository [README](../../README.md) explains why — containers inherit the host
`~/.gitconfig`, so shared settings have to arrive through the other file.

## Identity never lives in this repository

`dot_gitconfig.tmpl` renders `.name` / `.email` from
`~/.config/chezmoi/chezmoi.toml`, which sits outside the repo. That is what
keeps this repository publishable — do not add identity here.

## Platform-specific settings are a separate file, not a conditional

Shared settings go in `config`, macOS-only ones in `darwin.conf`, which
`config` pulls in with an `[include]`. Git silently ignores includes whose
target is missing, so `.chezmoiignore` skipping `darwin.conf` on non-macOS is
the whole mechanism. That is how to add a platform-specific git setting — do
not add conditionals to `dot_gitconfig.tmpl`.
