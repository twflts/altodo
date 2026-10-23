#!/bin/bash
# DSL パターンの解釈と、altodo ファイルで一致する行を表示する。
# 使い方: scripts/debug-pattern.sh FILE PATTERN
# 環境変数: EMACS（既定 emacs）
# 終了コード: 0: 成功、2: 引数の誤り、それ以外: Emacs の終了コード
# 表示する内容は altodo-debug.el の altodo-debug-explain-pattern を参照する。

readonly EMACS_CMD="${EMACS:-emacs}"

err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

#######################################
# バッチモードの Emacs で、DSL パターンを診断する。
# Arguments:
#   $1: altodo ファイルのパス。存在するファイルであること。
#   $2: DSL パターン（例: "and:open,due-date:overdue"）。
# Outputs:
#   診断の結果を STDOUT に出力する。
# Returns:
#   0: 成功、2: 引数の誤り。
#######################################
main() {
  if [[ $# -ne 2 || ! -f "$1" || -z "$2" ]]; then
    err "usage: scripts/debug-pattern.sh FILE PATTERN"
    return 2
  fi

  "${EMACS_CMD}" --batch -L . -l altodo-debug \
    -f altodo-debug-batch-pattern "$1" "$2" 2>&1 | grep -v '^Loading '
  return "${PIPESTATUS[0]}"
}

main "$@"
