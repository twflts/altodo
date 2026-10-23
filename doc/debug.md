# 調査用のコマンド

altodo の動作の原因を調べるコマンドは、別のファイル `altodo-debug.el` にある。altodo 本体は、このファイルを読み込まない。設定も変更しない。

使うには、`altodo.el` と同じ場所に置き、`(require 'altodo-debug)` する。結果は、バッファ `*altodo-debug*` に表示する。バッチモードでは標準出力に出力する。


## 行の診断

`M-x altodo-debug-describe-line`（接頭引数で行番号を指定）は、行について altodo が認識した内容を表示する。

- 行の種類（タスク、コメント、複数行コメント、見出し、コードブロック内）、インデント、見出しの階層
- タスクの状態、フラグ、タグ、人、期日と開始日（今日との差）、`#done`、`#id`
- `#dep` の解決結果（blocked、ready、circular）、`#seq-tasks` の状態
- 先頭の文字と末尾の文字の face
- フィルタで非表示になっているか
- DSL の単純パターン（`done`、`open`、`task` など）ごとの結果

確認が失敗したときは、エラーの内容を値として表示する。「この行がなぜ blocked と表示されるのか」「なぜ絞り込みに入らないのか」を、設定の変更なしで調べられる。


## パターンの診断

`M-x altodo-debug-explain-pattern` は、DSL パターンの解釈と、一致する行を表示する。

- 正規化した構造（`simple`、`arg`、`logic`）と、検証の結果
- コンパイルの失敗の理由（サイドバーは、コンパイルできないパターンを何も一致しないものとして扱い、理由を表示しない）
- 一致した行数、先頭 20 件の行番号、所要時間


## 追跡と測定

- `M-x altodo-debug-trace`: altodo の関数を選び、呼び出しを `*trace-output*` に出力する（`trace-function-background`）。引数、戻り値、呼び出しの深さが分かる。`M-x altodo-debug-untrace-all` で解除する。
- `M-x altodo-debug-profile`: `fontify`（バッファ全体の色付け）、`sidebar`（サイドバーの描画）、`filter`（DSL パターンの適用）のいずれかを CPU プロファイラで測定し、報告を表示する。
- ステップ実行は `edebug-defun`、エラー時のバックトレースは `toggle-debug-on-error` を使う。


## 不具合の報告用の情報

`M-x altodo-debug-report` は、Emacs、markdown-mode、altodo.el の情報、バッファの行数、`.altodo-locals.el` の状態、サイドバーの状態、既定値と異なる `altodo-` の設定を表示する。不具合の報告に貼り付ける。


## バッチでの実行

標準出力に結果を出力する。再現手順の共有と、自動化に使う。

```
scripts/debug-line.sh FILE LINE
scripts/debug-pattern.sh FILE PATTERN
```

終了コードは、成功が 0、引数の誤りが 2 である。性能は、`scripts/bench-filter.sh`（絞り込み）と `scripts/bench-fontlock.sh`（色付け）で測る。
