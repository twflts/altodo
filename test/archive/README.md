# test/archive

開発中の調査に使った、アサーションを持たないスクリプトと、未実装のスタブである。`message` で状態を出力するだけで、失敗しないため、テストとしての価値がない。`scripts/run-tests.sh` は `test/*.el` だけを実行するため、このディレクトリは対象外である。

| ファイル | 内容 | 代わりのテスト |
|---|---|---|
| `debug-child-blocked-test.el`、`debug-seq-tasks-test.el`、`debug-seq-tasks-last-child-test.el`、`debug-parent-test.el` | `#seq-tasks` の状態の確認 | `phase5-8-test.el` |
| `debug-demo-test.el`、`debug-filter-test.el`、`debug-line7-test.el`、`debug-simple-test.el` | フィルタ・行判定の動作確認 | `filter-*-test.el`、`line-detection-remaining-test.el` |
| `heading-spacing-debug2.el` | 見出し前後の空行の確認 | `heading-spacing-test.el` |
| `sidebar-debug-test.el` | サイドバーのパターン読み込みの確認 | `sidebar-test.el` |
| `face-application-test.el` | face のテストの未実装のスタブ | `fontlock-*-test.el`、`codeblock-face-test.el` |
