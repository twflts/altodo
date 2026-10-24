# テスト一覧

`scripts/gen-test-map.py` が生成する。手で編集しない（`scripts/ci.sh` が最新かを確認する）。

## 使い方

- 全体: 115 ファイル、1151 テスト
- 実行: `scripts/run-tests.sh [test/NAME.el]`。ベースラインとの差分だけを報告する
- 関数に対応するテストを探す: `grep -l 'altodo--関数名' test/*.el`
- 共通の道具: `test/altodo-test-helper.el`（`altodo-test-with-buffer`、`-with-temp-dir`、`-with-locals`、`-with-today`、`altodo-test-file`）
- 新しいテストは、ヘルパーを使い、日付は `altodo-test-with-today` で固定し、サンプルは一時ディレクトリに作る。`(should t)` のようなアサーションを書かない
- 仕様に基づくケース表: `multiline-comment-spec-test.el`。サンプルファイルの検証: `testfiles-test.el`
- 「既知の不具合」は `:expected-result :failed` のテスト（修正すると想定外の成功として報告される）

## サイドバー

| ファイル | 件数 | 内容 | 主な対象 | 備考 |
|---|---|---|---|---|
| `filter-sidebar-doc-impl-test` | 17 | Filter and sidebar behavior of the design document | `altodo--get-display-context-option`、`altodo--compile-simple-pattern`、`altodo-sidebar--get-buffer` |  |
| `review-fixes-test` | 18 | Tests for the fixes of the code review | `altodo-sidebar-indent`、`altodo--add-done-tag`、`altodo-sidebar--render` |  |
| `sidebar-apply-filter-at-point-test` | 3 | Tests for altodo-sidebar--apply-filter-at-point | `altodo-sidebar--apply-filter-at-point`、`altodo-sidebar--apply-filter` |  |
| `sidebar-blank-line-test` | 3 | Test for sidebar blank line issue | `altodo-sidebar--render` |  |
| `sidebar-buffer-advanced-test` | 10 | Advanced tests for the sidebar buffers | `altodo-sidebar--get-or-create-buffer`、`altodo-sidebar--buffer-alist`、`altodo-sidebar--get-buffer` |  |
| `sidebar-buffer-bugfix-test` | 5 | Tests for the sidebar buffer bug fixes | `altodo-sidebar--selected-filters`、`altodo-sidebar--get-or-create-buffer`、`altodo-sidebar--selection-mode` |  |
| `sidebar-buffer-dolist-test` | 1 | Tests that every entry is rendered | `altodo-sidebar--render`、`altodo-sidebar-show`、`altodo-sidebar--get-buffer` |  |
| `sidebar-buffer-real-file-test` | 3 | Tests with a real file | `altodo-sidebar-show`、`altodo-sidebar--get-buffer`、`altodo-sidebar--source-buffer` |  |
| `sidebar-buffer-refresh-test` | 6 | Tests for refreshing from the sidebar and the source | `altodo-sidebar--get-face`、`altodo-sidebar--get-or-create-buffer`、`altodo-sidebar--selection-mode` |  |
| `sidebar-buffer-test` | 5 | Tests Multiple Buffer Support | `altodo-sidebar--get-or-create-buffer`、`altodo-sidebar--get-buffer`、`altodo-sidebar--buffer-alist` |  |
| `sidebar-calendar-test` | 34 | Tests for the calendar and agenda of the sidebar | `altodo-sidebar--render`、`altodo-sidebar--calendar-month`、`altodo--day-filter-entry` |  |
| `sidebar-dynamic-count-test` | 13 | Tests dynamic count calculation | `altodo--get-entry-count`、`altodo--compile-filter-predicate`、`altodo--combine-predicates` |  |
| `sidebar-face-layer-test` | 16 | Complex Layer interaction tests | `altodo-sidebar--get-face`、`altodo-sidebar--selected-filters`、`altodo-sidebar--selection-mode` |  |
| `sidebar-face-render-layers-test` | 35 | Faces of the drawn sidebar | `altodo-sidebar--render`、`altodo-sidebar--selection-mode`、`altodo-sidebar-make-config` |  |
| `sidebar-face-rules-basic-test` | 3 | Tests for face-rules | `altodo-sidebar--get-face`、`altodo-sidebar-make-config`、`altodo--format-sidebar-title` |  |
| `sidebar-face-rules-comprehensive-test` | 1 | Comprehensive test of face-rules | `altodo-sidebar--get-face`、`altodo--get-entry-count`、`altodo-sidebar-make-config` |  |
| `sidebar-face-rules-render-test` | 1 | Sidebar rendering test | `altodo-sidebar-make-config`、`altodo-sidebar--render` |  |
| `sidebar-face-rules-test` | 24 | Tests face-rules | `altodo--evaluate-face-rules`、`altodo-sidebar--get-face`、`altodo--format-sidebar-title` |  |
| `sidebar-face-test` | 18 | Tests for sidebar face functions | `altodo-sidebar--default-face`、`altodo-sidebar--resolve-face`、`altodo-sidebar--get-face` |  |
| `sidebar-help-test` | 2 | Tests for the help of the altodo sidebar | `altodo-sidebar-help`、`altodo-sidebar-mode-map`、`altodo-sidebar--apply-filter-at-point` |  |
| `sidebar-selection-commands-test` | 6 | Tests for the sidebar selection commands | `altodo-sidebar--combine-mode`、`altodo-sidebar-toggle-selection`、`altodo-sidebar-mouse-toggle-selection` |  |
| `sidebar-test` | 10 | Test for altodo sidebar | `altodo--get-filter-patterns`、`altodo-sidebar-make-config`、`altodo--load-locals-file` |  |
| `sidebar-title-expansion-test` | 27 | Tests for sidebar title expansion | `altodo--format-sidebar-title`、`altodo--line-done-p`、`altodo--line-has-priority-p` |  |

## font-lock・face

| ファイル | 件数 | 内容 | 主な対象 | 備考 |
|---|---|---|---|---|
| `codeblock-face-test` | 25 | Tests for code block face handling | `altodo--restore-code-block-faces` |  |
| `done-cancelled-face-test` | 3 | Tests for the strikethrough faces of done and cancelled tasks |  |  |
| `fontlock-facespec-test` | 3 | Tests for font-lock facespec | `altodo--get-state-face`、`altodo-state-done`、`altodo-state-open` |  |
| `fontlock-integration-test` | 5 | Integration tests for font-lock | `altodo-font-lock-keywords` |  |
| `fontlock-layer-test` | 4 | Tests for font-lock layer-based face application |  |  |
| `fontlock-matcher-test` | 5 | Tests for font-lock matcher functions | `altodo--start-date-matcher`、`altodo--due-date-matcher`、`altodo--tag-matcher` |  |
| `fontlock-priority-test` | 5 | Tests for font-lock priority (override flags) | `altodo-font-lock-keywords` |  |
| `fontlock-subexp-test` | 3 | Tests for font-lock subexp-highlighter | `altodo-font-lock-keywords` |  |
| `state-text-face-test` | 2 | Tests for the text faces of task states | `altodo--has-seq-tasks-tag` |  |

## 複数行コメント

| ファイル | 件数 | 内容 | 主な対象 | 備考 |
|---|---|---|---|---|
| `display-context-all-comments-test` | 1 | Test :display-context all shows comments | `altodo--compute-display-lines` |  |
| `filter-multiline-comment-overlay-test` | 3 | Test multiline comment overlay handling | `altodo--filter-lines`、`altodo--filter-find-overlay`、`altodo--filter-show-multiline-comments` |  |
| `line-detection-remaining-test` | 3 | Tests for remaining line detection functions | `altodo--comment-p`、`altodo--empty-task-line-p`、`altodo--line-state-p` |  |
| `misc-test` | 2 | Tests for altodo miscellaneous functions | `altodo--outline-level`、`altodo--multiline-comment-p` |  |
| `multiline-comment-filter-test` | 11 | Tests for multiline comment filter functionality | `altodo--line-has-multiline-comment-p`、`altodo--multiline-comment-contains-regexp-p`、`altodo--get-multiline-comment-range` |  |
| `multiline-comment-spec-test` | 17 | Multi-line comment rules of the specification | `altodo--multiline-comment-p` | 既知の不具合 1 |
| `multiline-comment-test` | 4 | Tests for multiline comment functions | `altodo--get-multiline-comment-lines`、`altodo--indent-multiline-comments`、`altodo--get-multiline-comment-region` |  |
| `other-test` | 4 | Tests for other functions | `altodo--multiline-comment-indent-ok-p`、`altodo--call-parent-command`、`altodo--outline-level` |  |
| `testfiles-test` | 12 | Tests for the sample files in testfiles/ | `altodo--multiline-comment-p`、`altodo--task-p`、`altodo--comment-p` |  |

## インデント・TAB

| ファイル | 件数 | 内容 | 主な対象 | 備考 |
|---|---|---|---|---|
| `docs-code-review-test` | 20 | Fixes of the documentation and code review | `altodo-add-task`、`altodo-enter`、`altodo-indent-increase` |  |
| `indent-behavior-test` | 11 | Tests for TAB and the indentation helpers | `altodo-indent-line`、`altodo--normalize-indent`、`altodo--set-line-indent` |  |
| `indent-function-test` | 5 | Tests for indent functions | `altodo--normalize-irregular-indent`、`altodo--smart-indent`、`altodo--cycle-indent` |  |
| `indent-test` | 8 | Tests for altodo indent functions | `altodo--normalize-indent`、`altodo--get-line-indent`、`altodo--previous-line-empty-p` |  |
| `input-test` | 1 | Tests for input functions | `altodo-enter` |  |

## 日付

| ファイル | 件数 | 内容 | 主な対象 | 備考 |
|---|---|---|---|---|
| `abnormal-cases-test` | 16 | Tests for the abnormal cases of the design review | `altodo--due-date-matches-p`、`altodo--find-line-with-tag`、`altodo--parse-date` |  |
| `calendar-date-test` | 16 | Tests for the date input commands | `altodo-select-due-calendar`、`altodo-input-due-date`、`altodo-calendar-pick-date` |  |
| `date-arrow-test` | 24 | Tests for date arrow face handling |  |  |
| `date-dst-test` | 6 | Tests for dates in a time zone with summer time | `altodo--parse-date`、`altodo--days-diff`、`altodo--today-start` |  |
| `date-format-test` | 12 | Tests for altodo-date-format handling | `altodo-date-format`、`altodo--parse-due-date-condition`、`altodo--parse-date` |  |
| `date-range-test` | 4 | Tests for this-week and this-month conditions | `altodo-week-start-day`、`altodo--days-to-week-end`、`altodo--due-date-matches-p` |  |
| `dsl-date-compile-test` | 4 | Tests for compiling date patterns | `altodo--parse-due-date-condition`、`altodo--compile-simple-pattern` |  |
| `due-date-filter-test` | 30 | Tests for due date filter | `altodo--parse-due-date-condition`、`altodo--line-due-date-value`、`altodo--due-date-matches-p` |  |
| `helper-date-test` | 5 | Tests for date helper functions | `altodo--today-start`、`altodo--parse-date`、`altodo--days-diff` |  |
| `start-date-filter-test` | 30 | Tests for start date filter | `altodo--start-date-matches-p`、`altodo--parse-start-date-condition`、`altodo--line-start-date-value` |  |
| `utility-remaining-test` | 4 | Tests for remaining utility functions | `altodo--format-to-regex`、`altodo--date-regex-info`、`altodo--date-regex-match` |  |

## 完了タスクの移動

| ファイル | 件数 | 内容 | 主な対象 | 備考 |
|---|---|---|---|---|
| `done-file-abnormal-test` | 7 | Tests for abnormal cases of moving done tasks | `altodo-move-done-tasks-at-point`、`altodo-auto-save-after-move`、`altodo--auto-move-all-buffers` |  |
| `done-file-test` | 14 | Tests for moving done tasks to the done file | `altodo-move-done-tasks-at-point`、`altodo-move-all-done-tasks`、`altodo--auto-move-timer` |  |
| `move-after-days-test` | 9 | Tests for moving done tasks after some days | `altodo--done-tag-days-ago`、`altodo-move-after-days`、`altodo--line-done-tag-value` |  |
| `move-subtree-test` | 16 | Tests for moving done tasks with their subtasks | `altodo-move-unit`、`altodo-move-done-tasks-at-point`、`altodo-move-all-done-tasks` |  |
| `move-task-test` | 5 | Tests for altodo move task functions | `altodo--is-done-or-cancelled-task`、`altodo--extract-task-line` |  |
| `task-search-test` | 5 | Tests for task search and operation functions | `altodo--add-done-tag`、`altodo--find-previous-task-line`、`altodo--remove-done-tag` |  |

## ID・依存・seq-tasks

| ファイル | 件数 | 内容 | 主な対象 | 備考 |
|---|---|---|---|---|
| `goto-dep-test` | 7 | Tests for goto-dependency command | `altodo-goto-dependency`、`altodo--find-line-with-tag` |  |
| `helper-dependency-test` | 2 | Tests for dependency helper functions | `altodo--check-all-deps-completed`、`altodo--check-circular-dependency` |  |
| `helper-id-test` | 4 | Tests for ID helper functions | `altodo--generate-id`、`altodo--find-task-by-id`、`altodo--get-task-id` |  |
| `id-generation-test` | 6 | Tests for ID generation functions | `altodo--integer-to-base62`、`altodo--generate-tiny-id-sortable`、`altodo--generate-id` |  |
| `id-test` | 2 | Tests for ID generation functions | `altodo--find-task-by-id`、`altodo--generate-id` |  |
| `seq-tasks-tag-test` | 5 | Tests for the #seq-tasks tag detection | `altodo--is-seq-tasks-child-blocked-p`、`altodo--has-seq-tasks-tag`、`altodo-set-task-done` |  |
| `seq-tasks-test` | 11 | Tests for seq-tasks | `altodo--has-seq-tasks-tag`、`altodo--is-seq-tasks-child-blocked-p` |  |
| `user-command-advanced-test` | 2 | Tests for advanced user commands | `altodo-insert-id`、`altodo-add-subtask` |  |

## 見出し・表示コンテキスト

| ファイル | 件数 | 内容 | 主な対象 | 備考 |
|---|---|---|---|---|
| `blank-line-collapse-test` | 3 | Test collapsing consecutive blank lines | `altodo--compute-display-lines` |  |
| `display-context-option-test` | 8 | Tests for :display-context option | `altodo--filter-find-overlay`、`altodo--get-display-context-option`、`altodo--filter-lines` |  |
| `display-context-test` | 4 | Tests for :display-context option | `altodo--compute-display-lines`、`altodo--compute-all-heading-ranges` |  |
| `heading-filter-test` | 7 | Tests for heading filter functionality | `altodo--line-in-heading-range-with-filter-p`、`altodo--heading-level`、`altodo--compile-simple-pattern` |  |
| `heading-jump-test` | 24 | Tests for the heading jump of the sidebar | `altodo--collect-headings`、`altodo-sidebar--jump-to-heading`、`altodo-default-filter-patterns` |  |
| `heading-newline-test` | 3 | Test heading newline with 'all' display context | `altodo--compute-display-lines` |  |
| `heading-range-compute-test` | 12 | 見出し範囲の一括計算のテスト | `altodo--heading-level`、`altodo--compute-all-heading-ranges`、`altodo--compute-display-lines` |  |
| `heading-spacing-display-lines-test` | 1 | Visual test showing display lines | `altodo--compute-display-lines` |  |
| `heading-spacing-first-heading-test` | 1 | Debug first heading spacing | `altodo--compute-display-lines` |  |
| `heading-spacing-test` | 3 | Test first heading gets newline after only | `altodo--compute-display-lines` |  |
| `normal-text-test` | 0 | normal-text-test |  |  |
| `setext-test` | 2 | Test Setext heading level detection | `altodo--heading-level` |  |

## フィルタ・DSL

| ファイル | 件数 | 内容 | 主な対象 | 備考 |
|---|---|---|---|---|
| `combine-predicates-test` | 12 | Tests multiple filter selection | `altodo-sidebar--combine-mode`、`altodo-sidebar--selected-filters`、`altodo--combine-predicates` |  |
| `dsl-compiler-test` | 33 | Tests for DSL compiler | `altodo--compile-simple-pattern`、`altodo--validate-pattern`、`altodo--normalize-pattern` |  |
| `dsl-multi-patterns-test` | 13 | Tests for the line type and multi-value DSL patterns | `altodo--compile-simple-pattern`、`altodo--get-entry-count` |  |
| `dsl-review-test` | 16 | DSL behavior of the design document | `altodo--compile-simple-pattern`、`altodo--count-matching-lines`、`altodo--normalize-pattern` |  |
| `dynamic-collect-test` | 31 | Tests for dynamic filter functionality | `altodo--expand-dynamic-filter`、`altodo--collect-dynamic-values-with-exclude`、`altodo--format-placeholder` |  |
| `dynamic-filter-test` | 16 | Tests for dynamic filter tag/person extraction | `altodo--line-extract-all-tags`、`altodo--line-extract-all-persons`、`altodo--collect-dynamic-values-with-exclude` |  |
| `filter-function-test` | 10 | Tests for altodo filter functions | `altodo--line-has-tag-p`、`altodo--line-done-p`、`altodo--line-progress-p` |  |
| `filter-helper-test` | 2 | Unit tests for filter helper functions | `altodo--filter-create-overlay`、`altodo--filter-find-overlay`、`altodo--filter-overlays` |  |
| `filter-integration-test` | 5 | Integration tests for filter functions | `altodo--filter-overlays`、`altodo--filter-lines`、`altodo--filter-find-overlay` |  |
| `filter-large-buffer-test` | 4 | Tests for filtering large buffers | `altodo--filter-lines`、`altodo--line-done-p`、`altodo--goto-line` |  |
| `filter-predicate-test` | 6 | Tests for filter predicate functions | `altodo--line-has-tag-p`、`altodo--line-has-priority-p`、`altodo--line-has-star-p` |  |
| `filter-real-test` | 1 | Real-world test with filter-test.altodo | `altodo--filter-overlays`、`altodo--filter-lines`、`altodo-filter-clear` |  |
| `filter-user-command-test` | 13 | Tests for filter user commands | `altodo--filter-mode`、`altodo--filter-overlays`、`altodo-filter-show-done-only` |  |
| `load-locals-file-test` | 7 | Tests for altodo--load-locals-file | `altodo--load-locals-file`、`altodo--get-filter-patterns` |  |
| `matcher-advanced-test` | 4 | Tests for advanced matcher functions | `altodo--arrow-matcher`、`altodo--tag-with-value-matcher`、`altodo--dep-tag-matcher` |  |
| `multi-select-filter-test` | 12 | Complex multiple filter tests | `altodo--compile-simple-pattern`、`altodo--combine-predicates`、`altodo--filter-lines` |  |
| `parent-task-regexp-test` | 33 | Tests for parent task regexp filter | `altodo--line-parent-task-matches-regexp-p`、`altodo--compile-simple-pattern`、`altodo--filter-lines` |  |
| `person-tag-matcher-test` | 17 | Tests for person tag matcher | `altodo--person-tag-matcher`、`altodo--is-valid-person-tag-position` |  |
| `person-url-test` | 7 | Tests for @ inside a word and the dynamic :limit | `altodo--limit-dynamic-values`、`altodo--line-has-person-p`、`altodo-filter-show-person` |  |
| `review-decisions-test` | 23 | Tests for the decisions of the code review | `altodo--count-matching-lines`、`altodo-filter-by-pattern`、`altodo--generate-uuidv7` |  |
| `tag-value-filter-test` | 53 | Tests tag-value filter | `altodo--line-has-tag-value-numeric-p`、`altodo--line-has-tag-value-p`、`altodo--string-to-valid-number` |  |

## その他（コマンド・ユーティリティ・デバッグ）

| ファイル | 件数 | 内容 | 主な対象 | 備考 |
|---|---|---|---|---|
| `altodo-calendar-test` | 27 | Tests for the library altodo-calendar | `altodo-calendar-japanese-holiday`、`altodo-calendar-insert`、`altodo-calendar-emacs-holiday` |  |
| `altodo-debug-test` | 14 | Tests for the investigation commands | `altodo-debug-explain-pattern`、`altodo-debug--line-facts`、`altodo--normalize-state` |  |
| `command-behavior-test` | 22 | Tests for the editing commands | `altodo-set-task-done`、`altodo-toggle-task-state`、`altodo-set-priority-2` |  |
| `command-test` | 7 | Tests for altodo user commands | `altodo-toggle-task-state`、`altodo-set-task-done`、`altodo-set-task-open` |  |
| `flag-combination-test` | 6 | Tests for star and priority flags used together | `altodo--format-flags`、`altodo-toggle-star-flag`、`altodo--parse-flags` |  |
| `helper-flag-test` | 1 | Tests for flag helper functions | `altodo--has-star-flag-p` |  |
| `helper-state-test` | 3 | Tests for state helper functions | `altodo-state-open`、`altodo--normalize-state`、`altodo--task-is-completed` |  |
| `locals-code-policy-test` | 12 | Tests for the code policy of .altodo-locals.el | `altodo-locals-code-policy`、`altodo--entry-code-permitted-p`、`altodo--get-entry-count` |  |
| `matcher-remaining-test` | 4 | Tests for remaining matcher functions | `altodo--dep-blocked-text-matcher`、`altodo--due-overdue-severe-text-matcher`、`altodo--start-not-yet-text-matcher` |  |
| `task-operation-test` | 1 | Tests for task operation functions | `altodo-add-task` |  |
| `user-command-remaining-test` | 4 | Tests for remaining user commands | `altodo-set-task-progress`、`altodo-set-task-waiting`、`altodo-set-task-cancelled` |  |

## test/archive

実行しない（アサーションを持たない調査用のスクリプトなど）。`test/archive/README.md` を参照する。

`debug-child-blocked-test`、`debug-demo-test`、`debug-filter-test`、`debug-line7-test`、`debug-parent-test`、`debug-seq-tasks-last-child-test`、`debug-seq-tasks-test`、`debug-simple-test`、`face-application-test`、`heading-spacing-debug2`、`sidebar-debug-test`
