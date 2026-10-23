#!/bin/bash
# altodo.el のバイトコンパイル、checkdoc、package-lint の指摘数を数え、
# ベースラインより増えていないことを確認する。
# 使い方: scripts/lint.sh [--update-baseline]
# 環境変数: EMACS（既定 emacs）
# 終了コード: 0: 増加なし、1: 増加あり
# ベースライン: scripts/lint-baseline.txt（「種類 件数」の行）

readonly BASELINE_FILE="scripts/lint-baseline.txt"
readonly EMACS_CMD="${EMACS:-emacs}"

err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

#######################################
# 3 種類の指摘数を「種類 件数」の形式で出力する。
# バイトコンパイルは、作業ディレクトリを汚さないよう一時ディレクトリで行う。
#######################################
count_findings() {
  local tmp_dir file byte=0 doc=0 lint=0 n
  tmp_dir="$(mktemp -d)" || return 1
  cp altodo.el altodo-calendar.el altodo-debug.el "${tmp_dir}/" || return 1

  # altodo-debug.el は altodo.el を require するため、-L に一時ディレクトリを渡す。
  for file in altodo-calendar.el altodo.el altodo-debug.el; do
    n="$("${EMACS_CMD}" --batch -L "${tmp_dir}" \
      -f batch-byte-compile "${tmp_dir}/${file}" 2>&1 | grep -c 'Warning')"
    byte=$((byte + n))
    n="$("${EMACS_CMD}" --batch -L . --eval \
      "(checkdoc-file \"${file}\")" 2>&1 | grep -c "^${file}:")"
    doc=$((doc + n))
    n="$("${EMACS_CMD}" --batch -L . --eval \
      '(require (quote package-lint))' -f package-lint-batch-and-exit \
      "${file}" 2>&1 | grep -c "^${file}:")"
    lint=$((lint + n))
  done
  echo "byte-compile ${byte}"
  echo "checkdoc ${doc}"
  echo "package-lint ${lint}"
  rm -rf "${tmp_dir:?}"
}

main() {
  local current kind count base failed=0

  current="$(count_findings)" || return 1
  if [[ "${1:-}" == "--update-baseline" ]]; then
    echo "${current}" >"${BASELINE_FILE}" || return 1
    echo "baseline updated"
    echo "${current}"
    return 0
  fi

  while read -r kind count; do
    base="$(awk -v k="${kind}" '$1 == k {print $2}' "${BASELINE_FILE}")"
    echo "${kind}: ${count} (baseline: ${base:-none})"
    if [[ -z "${base}" || "${count}" -gt "${base}" ]]; then
      failed=1
    fi
  done <<<"${current}"

  if [[ "${failed}" -eq 1 ]]; then
    err "lint findings increased"
    return 1
  fi
  echo "no increase"
}

main "$@"
