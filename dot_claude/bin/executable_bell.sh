#!/bin/sh
# Claude Code の Stop hook。応答が終わった瞬間に OSC 777 を端末へ流し、
# VS Code 拡張 (tangentyh.vscode-terminal-osc-notifier-enhanced) に
# デスクトップ通知へ変換させる。
#
# なぜ必要か: Claude Code の通知イベントには「応答が終わった瞬間」に
# 対応するものが無い。完了系は idle_prompt (アイドルタイマー) だけで、
# 30〜60 秒遅れて届く。CLAUDE_CODE_DISABLE_NOTIFICATION_PRESENCE_CHECK で
# 在席判定を切っても即時にはならないことを確認済み。
#
# なぜ端末デバイスを名指しで開くのか: Claude Code はフックを制御端末から
# 切り離して起動するため /dev/tty は開けず ("Device not configured")、
# フックの stdout は Claude Code に捕捉されて端末には届かない。祖先の
# Claude Code 本体が掴んでいる端末を自力で探して直接書くしかない。
#
# デバッグ: `touch ~/.claude/bell.log` すると以降の実行が追記される。
# ファイルを消せば記録は止まる。存在しないときは何も書かない。
set -u

log=$HOME/.claude/bell.log

# `[ -f ] && cmd` は条件が偽のとき 1 を返す。note がスクリプト末尾の文になる
# 経路があるので、明示的に 0 を返さないとフック全体が失敗扱いになり、
# Claude Code が毎ターン "Stop hook error" を表示する。
note() {
  [ -f "$log" ] && printf '%s %s\n' "$(date '+%H:%M:%S')" "$1" >>"$log"
  return 0
}

# 端末を持つ祖先を探す。フックの親が何になるかは環境によって変わる:
# macOS では sh -c が exec 最適化でスクリプトに置き換わるため親が直接 claude
# だが、Dev Container の sh (dash) は最適化せず間に 1 段挟まる。その中間の sh は
# 制御端末から切り離されていて端末を持たないので、親だけ見ると空振りする。
#
# この関数はコマンド置換 (サブシェル) で呼ぶので、中で代入した変数は呼び出し元に
# 返らない。失敗時のチェーンは呼び出し元に渡さず、ここで note に書き出す。
resolve_tty() {
  p=$PPID
  trace=''
  # 遡る上限。カウンタを手で回す代わりに固定リストを畳む (seq は POSIX 外)。
  for _ in 1 2 3 4 5 6 7 8; do
    case "$p" in
      '' | 0 | 1) break ;;
    esac
    # trace は失敗時のログにしか使わないので、記録が無効なら組み立てない
    [ -f "$log" ] && trace="$trace $p:$(ps -o comm= -p "$p" 2>/dev/null)"
    # Linux: ファイルディスクリプタの向き先を /proc から読む
    for fd in 0 1 2; do
      t=$(readlink "/proc/$p/fd/$fd" 2>/dev/null) || continue
      case "$t" in
        /dev/pts/* | /dev/tty*) echo "$t"; return 0 ;;
      esac
    done
    # macOS ほか: ps から端末名を引く (Linux でも pts/0 の形で返る)
    t=$(ps -o tty= -p "$p" 2>/dev/null | tr -d '[:space:]')
    case "$t" in
      '' | '?' | '??' | '-') ;;
      *) echo "/dev/$t"; return 0 ;;
    esac
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d '[:space:]')
  done
  note "resolve_tty FAILED chain:${trace:-<none>}"
  return 1
}

if ! dev=$(resolve_tty); then
  exit 0
fi

if printf '\033]777;notify;Claude Code;%s\a' "${1:-Finished} — $(basename "$PWD")" >"$dev" 2>/dev/null; then
  note "OK dev=$dev"
else
  note "WRITE FAILED dev=$dev"
fi

# 通知の成否でターンを失敗させない
exit 0
