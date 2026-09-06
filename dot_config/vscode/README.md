# VS Code configuration

This directory is canonical. Settings, keybindings, MCP config, and snippets
live here (`~/.config/vscode/`); add real settings to this directory.

VS Code stores its user config under a different path on every OS. The
`private_Library/…/Code/User/symlink_*.tmpl` files contain only a target path
and exist to point the macOS location at this copy — there is nothing to edit
in them. Only macOS is wired up today: WSL2 reads its settings from the Windows
host, and containers get machine-scoped settings only.

New files that appear here through the VS Code UI (snippets, for instance) are
real files rather than symlinks back into the repository — bring them in with
`chezmoi add`.
