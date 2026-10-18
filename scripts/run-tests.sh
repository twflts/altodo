#!/bin/bash
# test/*.el を 1 ファイルずつ ERT で実行し、ベースラインと比較する。
# 使い方: scripts/run-tests.sh [--update-baseline] [テストファイル...]
# 環境変数: EMACS（既定 emacs）、TEST_TIMEOUT（既定 120 秒）
# 終了コード: 0: 新しい失敗なし、1: 新しい失敗あり
# ベースライン: scripts/test-baseline.txt（失敗するテストの一覧）

readonly BASELINE_FILE="scripts/test-baseline.txt"
readonly EMACS_CMD="${EMACS:-emacs}"
readonly TIMEOUT_SEC="${TEST_TIMEOUT:-120}"

err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

#######################################
# 1 つのテストファイルを実行し、失敗を「ファイル名:テスト名」で出力する。
# Arguments:
#   $1: テストファイルのパス
# Outputs:
#   失敗したテスト、読み込み失敗（LOAD-ERROR）、時間切れ（TIMEOUT）。
#######################################
run_one() {
  local file="$1"
  local name output status failed

  name="$(basename "${file}" .el)"
  output="$(timeout "${TIMEOUT_SEC}" "${EMACS_CMD}" --batch -L . -l ert \
    -l "${file}" -f ert-run-tests-batch-and-exit 2>&1)"
  status=$?
  if [[ "${status}" -eq 0 ]]; then
    return 0
  fi
  if [[ "${status}" -eq 124 ]]; then
    echo "${name}:TIMEOUT"
    return 0
  fi
  # FAILED は想定外の失敗、PASSED は想定外の成功（失敗を期待したテストが成功）。
  failed="$(grep -E '^ +(FAILED|PASSED) +[0-9]+/[0-9]+ ' <<<"${output}" |
    awk '{print $3}')"
  if [[ -z "${failed}" ]]; then
    echo "${name}:LOAD-ERROR"
  else
    sed "s/^/${name}:/" <<<"${failed}"
  fi
}

main() {
  local update_baseline=0
  local -a files=()
  local current new_failures fixed baseline
  local -a names=()

  if [[ "${1:-}" == "--update-baseline" ]]; then
    update_baseline=1
    shift
  fi
  files=("$@")
  if [[ "${#files[@]}" -eq 0 ]]; then
    mapfile -t files < <(ls test/*.el | grep -v altodo-test-helper.el)
  fi

  for f in "${files[@]}"; do names+=("$(basename "${f}" .el)"); done
  current="$(for f in "${files[@]}"; do run_one "${f}"; done | sort -u)"
  if [[ "${update_baseline}" -eq 1 ]]; then
    echo "${current}" >"${BASELINE_FILE}" || return 1
    echo "baseline updated: $(grep -c . "${BASELINE_FILE}") failures"
    return 0
  fi

  # 一部のファイルだけ実行したときは、そのファイルの分だけをベースラインと比較する。
  baseline="$(grep -E "^($(IFS='|'; echo "${names[*]}")):" \
    "${BASELINE_FILE}" | sort -u)"
  new_failures="$(comm -13 <(echo "${baseline}") <(echo "${current}"))"
  fixed="$(comm -23 <(echo "${baseline}") <(echo "${current}"))"
  echo "failures: $(grep -c . <<<"${current}")" \
    "(baseline: $(grep -c . <<<"${baseline}"))"
  if [[ -n "${current}" && "${#files[@]}" -le 5 ]]; then
    sed 's/^/  fail: /' <<<"${current}"
  fi
  if [[ -n "${fixed}" ]]; then
    echo "fixed since baseline:"
    sed 's/^/  /' <<<"${fixed}"
  fi
  if [[ -n "${new_failures}" ]]; then
    echo "NEW failures:"
    sed 's/^/  /' <<<"${new_failures}"
    return 1
  fi
  echo "no new failures"
}

main "$@"
