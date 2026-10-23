#!/bin/bash
# altodo-mode のバッファ全体を色付けする時間を、行数ごとに測定する。
# 使い方: scripts/bench-fontlock.sh [--sizes "2000 4000"] [--max SECONDS]
# 環境変数: EMACS（既定 emacs）
# 終了コード: 0: 測定完了、1: --max を超えたケースがある、2: 引数の誤り
# 時間が行数に比例して増えることを確認する。測定の内容は
# scripts/bench-fontlock.el を参照する。CI には含めない。

readonly EMACS_CMD="${EMACS:-emacs}"

err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

#######################################
# 引数を環境変数に変換して、測定用の Emacs Lisp を実行する。
# Arguments:
#   --sizes "N ..." / --max SECONDS（いずれも省略可）
# Outputs:
#   行数ごとの秒数を STDOUT に出力する。
# Returns:
#   0: 完了、1: 閾値超過、2: 引数の誤り。
#######################################
main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sizes) export BENCH_SIZES="${2:?--sizes needs a value}"; shift 2 ;;
      --max) export BENCH_MAX="${2:?--max needs a value}"; shift 2 ;;
      *) err "unknown option: $1"; return 2 ;;
    esac
  done

  "${EMACS_CMD}" --batch -L . -l scripts/bench-fontlock.el \
    --eval '(altodo-bench-fontlock-run)' 2>&1 | grep -E '^BENCH' |
    sed 's/^BENCH //'
  return "${PIPESTATUS[0]}"
}

main "$@"
