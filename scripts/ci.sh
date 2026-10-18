#!/bin/bash
# ローカルの CI。lint、テスト、ドキュメントの名前の確認を実行する。
# 使い方: scripts/ci.sh
# 環境変数: EMACS（既定 emacs）。別バージョンで実行する例: EMACS=emacs-30 scripts/ci.sh
# 終了コード: 0: 全て成功、1: いずれかが失敗

err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

main() {
  local failed=0

  echo "== Emacs: $("${EMACS:-emacs}" --version | head -1)"
  echo "== lint"
  scripts/lint.sh || failed=1
  echo "== test"
  scripts/run-tests.sh || failed=1
  echo "== docs"
  scripts/check-doc-symbols.sh || failed=1
  python3 scripts/gen-test-map.py --check || failed=1

  if [[ "${failed}" -eq 1 ]]; then
    err "CI failed"
    return 1
  fi
  echo "CI passed"
}

main "$@"
