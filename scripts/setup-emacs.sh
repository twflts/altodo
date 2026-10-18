#!/bin/bash
# test/ の ERT と lint を実行するために、Emacs、markdown-mode、package-lint を導入する。
# 対象: Ubuntu 24.04（Emacs 29.3、markdown-mode 2.6）。
# root または sudo が使えるユーザで実行する。

err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

#######################################
# apt で Emacs と markdown-mode を導入し、読み込みを確認する。
# Outputs:
#   Emacs と markdown-mode のバージョンを STDOUT に出力する。
# Returns:
#   0: 成功、1: 導入または確認に失敗。
#######################################
main() {
  local -a sudo_cmd=()

  if [[ "$(id -u)" -ne 0 ]]; then
    sudo_cmd=(sudo)
  fi

  "${sudo_cmd[@]}" apt-get update || {
    err "apt-get update failed"
    return 1
  }
  "${sudo_cmd[@]}" apt-get install -y --no-install-recommends \
    emacs-nox elpa-markdown-mode elpa-package-lint || {
    err "apt-get install failed"
    return 1
  }

  emacs --version | head -1
  # altodo.el が require する markdown-mode を、batch モードで読み込めるか確認する。
  emacs --batch --eval \
    '(progn (require (quote markdown-mode))
            (message "markdown-mode %s" markdown-mode-version))' || {
    err "markdown-mode could not be loaded"
    return 1
  }
}

main "$@"
