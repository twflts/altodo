#!/bin/bash
# ドキュメントにバッククォートで書かれた altodo-*、sidebar-* の名前が、
# altodo.el に定義されているかを確認する。
# 使い方: scripts/check-doc-symbols.sh
# 終了コード: 0: 全て定義済み、1: 未定義の名前がある
# 除外: scripts/doc-symbols-ignore.txt（1 行 1 名称。# から行末はコメント）

readonly SOURCE_FILE="altodo.el"
readonly IGNORE_FILE="scripts/doc-symbols-ignore.txt"
readonly DOC_FILES=(README.md README_en.md doc/design.md doc/design_en.md
  doc/design-filter.md doc/design-filter_en.md)

err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

#######################################
# 名前が altodo.el の定義（def*、define-*、defalias）にあるかを調べる。
# Arguments:
#   $1: 名前
# Returns:
#   0: 定義あり、1: 定義なし。
#######################################
is_defined() {
  grep -qE "^\((def[a-z-]*|define-[a-z-]+|cl-def[a-z-]*) +'?$1($|[ )])" \
    "${SOURCE_FILE}"
}

main() {
  local missing=0 location symbol

  # 「ファイル:行:名前」を、名前の最初の出現だけ取り出す。
  while IFS=: read -r file line symbol; do
    symbol="${symbol#\`}"
    symbol="${symbol%%[(\` ]*}"
    case "${symbol}" in *.el|*.md|*.altodo|*:*) continue ;; esac
    is_defined "${symbol}" && continue
    grep -qxF "${symbol}" <(sed 's/#.*//; s/[[:space:]]*$//' "${IGNORE_FILE}") \
      && continue
    echo "missing: ${symbol} (${file}:${line})"
    missing=$((missing + 1))
  done < <(grep -noE '`(altodo|sidebar)[^` ()=]*' "${DOC_FILES[@]}" |
    awk -F: '!seen[$3]++')

  if [[ "${missing}" -gt 0 ]]; then
    err "${missing} undefined names in the documents"
    return 1
  fi
  echo "all names are defined"
}

main "$@"
