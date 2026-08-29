#!/bin/sh
set -eu

export PATH="$HOME/.local/bin:$PATH"

# install chezmoi if not exists
if ! command -v chezmoi >/dev/null 2>&1; then
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
fi

exec chezmoi init --apply --source="$(cd "$(dirname "$0")" && pwd)"
