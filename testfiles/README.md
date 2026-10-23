# testfiles

altodo.el を手動で確認するためのサンプルファイルである。Emacs で開き、色（face）、キー操作、サイドバーのフィルタを目で確認する。自動テストは `test/testfiles-test.el` が、これらのファイルが壊れていないこと（エラーなく処理できること、各ファイルが示すべき記法を含むこと）を確認する。


## 準備

1. altodo.el を読み込む。例: `emacs -L . -l altodo.el testfiles/test-comments.altodo`
2. サイドバーを使うときは、設定ファイルを有効にする。`.altodo-locals.el_`（末尾の `_` で無効にしてある）を、同じディレクトリに `.altodo-locals.el` としてコピーする
    - `cp testfiles/.altodo-locals.el_ testfiles/.altodo-locals.el`
    - 確認が終わったら `.altodo-locals.el` を削除する
    - 設定ファイルの `search-lambda` と `:command` は、既定では実行しない（件数は `?` と表示する）。試すときは、`(setq altodo-locals-code-policy 'confirm)`（ファイルの内容を承認すると実行する）または `'allow`（常に実行する）を設定する。信頼できるディレクトリでだけ有効にする
3. `M-x altodo-sidebar-show` でサイドバーを表示する
4. 今日を基準にした日付のファイルと、大きなファイルは `scripts/gen-testfiles.sh` で `testfiles/generated/` に生成する（`--lines N` で行数を指定）。`generated/` と、done ファイル（`*_done.altodo`）は Git の対象外である


## 機能別のファイル

| ファイル                           | 確認すること                                                                                                             |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `test-task-states.altodo`          | 5 つの状態（`[ ]`、`[x]`、`[@]`、`[w]`、`[~]`）の色。`C-c C-x`（トグル）、`C-c C-t o/x/@/w/~`                            |
| `test-flags.altodo`                | スター（`+`）と優先度（`!`〜`!!!`）の色。`///` 行のフラグ。フラグの後のスペースがない例は通常のテキスト                  |
| `test-tags.altodo`                 | タグ、`#key:value`、`#key:"値"` の色                                                                                     |
| `test-dates.altodo`                | 開始日・期日の色。日付は固定なので、開いた日によって色が変わる                                                           |
| `test-date-format-slash.altodo`    | `altodo-date-format` を `"%Y/%m/%d"` にしたときの日付（ファイル内に手順がある）                                          |
| `test-special-tags.altodo`         | `#id`、`#dep`（依存先が未完了のとき赤）、`#group-start`、`#group-due`、`#done`、`#seq-tasks`、`@person`                  |
| `test-comments.altodo`             | `///` と複数行コメント。複数行コメントになる行（OK）とならない行（NG）。自動テストが OK/NG の行を検証する                |
| `test-markdown-integration.altodo` | Markdown との共存。コードブロック内のタスク風の行、インライン コード、空行の直後のインデント付きタスク                   |
| `test-unicode.altodo`              | 日本語、中国語、韓国語、アラビア語、ロシア語、ギリシャ語、絵文字                                                         |
| `test-edge-cases.altodo`           | 空のタスク、非常に長い行、深いネスト、連続する空行                                                                       |
| `seq-tasks-demo.altodo`   | `#seq-tasks` の例（前の兄弟が完了するまで次が実行できない）                                                              |
| `test-face-rules.altodo`           | サイドバーの `:face-rules`・`:count-face-rules`（件数に応じた色）。件数は固定（完了 5、オープン 10、優先度 2、スター 3） |


## 実際のプロジェクトに近いファイル

| ファイル                         | 内容                                                                                              |
| -------------------------------- | ------------------------------------------------------------------------------------------------- |
| `comprehensive.altodo`           | 全機能を含む Java プロジェクト（英語）                                                            |
| `comprehensive-jp.altodo`        | 同上（日本語）。`C-c C-t d` で done ファイルを試せる                                              |
| `test-realistic-backend.altodo`  | Spring Boot の REST API 開発                                                                      |
| `test-realistic-frontend.altodo` | フロントエンド開発                                                                                |
| `test-sample-project.altodo`     | 1,286 行の大きな例。サイドバーのフィルタ（`.altodo-locals.el_` のパターン）と動的フィルタの確認用 |


## 設定ファイル `.altodo-locals.el_`

サイドバーのサンプルである。パターンの種類（`search-simple`、`search-lambda`、`dynamic`、`group-header`、`separator`、`command`）と、次の DSL を含む。

- 状態、フラグ、タグ、`tag-value`、`person`、親タスク（`parent-task-regexp`、`root-task-regexp`）
- 日付（`due-date:`、`start-date:`）、`level`、`text`、`regexp`、`has-multiline-comment`、`multiline-comment-contains`、`not:`
- 表示コンテキスト（`:display-context`）、複数行コメントの非表示（`:multiline-comment nil`）
- `:face-rules`、`:count-face-rules`
- `search-lambda`（期限切れ、今日が期日）

自動テストは、全パターンがエラーなくコンパイルできること、使っている face が存在することを確認する。


## 確認の手順の例

1. 色: 各ファイルを開き、表の「確認すること」と見比べる
2. 複数行コメント: `test-comments.altodo` の NG の行が、通常の文の色であること
3. サイドバー: `test-sample-project.altodo` で、各フィルタを選び、行が絞り込まれること。`s` で複数選択し、`C-c C-a`（AND）と `C-c C-o`（OR）を切り替える
4. 性能: `scripts/gen-testfiles.sh --lines 20000` で生成した `generated/test-large.altodo` で、フィルタの応答を確認する。先頭のタスクに 150 行の複数行コメントがある
5. 完了タスクの移動: `comprehensive-jp.altodo` で `C-c C-t d`。子孫ごと移動する（子孫に未完了のタスクがあるときは移動しない）。`C-c C-t D` は行だけを移動する
