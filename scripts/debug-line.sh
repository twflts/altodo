#!/bin/bash
# altodo ファイルの 1 行について、altodo が認識した内容を表示する。
# 使い方: scripts/debug-line.sh FILE LINE
# 環境変数: EMACS（既定 emacs）
# 終了コード: 0: 成功、2: 引数の誤り、それ以外: Emacs の終了コード
# 表示する内容は altodo-debug.el の altodo-debug-describe-line を参照する。

readonly EMACS_CMD="${EMACS:-emacs}"

err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

#######################################
# バッチモードの Emacs で、指定した行を診断する。
# Arguments:
#   $1: altodo ファイルのパス。存在するファイルであること。
#   $2: 行番号（1 以上の整数）。
# Outputs:
#   診断の結果を STDOUT に出力する。
# Returns:
#   0: 成功、2: 引数の誤り。
#######################################
main() {
  if [[ $# -ne 2 || ! -f "$1" || ! "$2" =~ ^[1-9][0-9]*$ ]]; then
    err "usage: scripts/debug-line.sh FILE LINE"
    return 2
  fi

  "${EMACS_CMD}" --batch -L . -l altodo-debug \
    -f altodo-debug-batch-line "$1" "$2" 2>&1 | grep -v '^Loading '
  return "${PIPESTATUS[0]}"
}

main "$@"
