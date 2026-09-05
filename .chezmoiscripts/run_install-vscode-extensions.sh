#!/bin/sh
set -eu

# ホスト側の VS Code に必要な拡張を入れる。
#
# run_once_ ではなく毎回走る run_ にしてある。run_once_ は内容のハッシュで
# 実行済みを記録するので、VS Code をまだ入れていないマシンで一度スキップすると
# 「成功した」と記録され、後から VS Code を入れても二度と走らない。
# apply あたり 1〜2 秒のコストで自己修復するほうを選んだ。

extensions='
tangentyh.vscode-terminal-osc-notifier-enhanced
'

find_code() {
  if command -v code >/dev/null 2>&1; then
    command -v code
    return 0
  fi
  for candidate in \
    "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
    "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"; do
    if [ -x "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

if ! code_bin=$(find_code); then
  echo "code コマンドが見つからないので VS Code 拡張の導入をスキップします" >&2
  exit 0
fi

installed=$("$code_bin" --list-extensions 2>/dev/null || true)

for ext in $extensions; do
  case "$installed" in
    *"$ext"*) continue ;;
  esac
  # 失敗しても apply 全体は止めない。WSL からの導入は未検証で、
  # ホスト側 VS Code に届くかどうか確認できていない。
  "$code_bin" --install-extension "$ext" || echo "警告: $ext の導入に失敗しました" >&2
done
