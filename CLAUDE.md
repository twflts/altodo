# altodo プロジェクト

Emacs の major mode（`altodo.el`）と、altodo フォーマット（Markdown 埋め込み型の TODO 形式）の仕様を管理する。
グローバルの CLAUDE.md に加えて、次の規則に従う。矛盾する場合は本ファイルを優先する。


## Stable 版

- `altodo-stable.el` は、ユーザが「stable 版を更新して」と明示的に指示するまで更新しない
- テストの完了後、複数フェーズの完了後でも、自動で更新しない
- 更新を指示されたとき: `cp altodo.el altodo-stable.el`


## 構成

- `altodo.el`: 本体（単一ファイル）
- `doc/`: 仕様書・設計書（`*_en.md` は英訳）
- `test/`: ERT。`project.altodo`: TODO（ルート）
- `.claude/memo/`: メモ。`.claude/backup/`: バックアップ
- `scripts/`: 開発用スクリプト（`setup-emacs.sh`: Emacs 29.3、markdown-mode、package-lint の導入。Ubuntu 24.04）
- `LICENSE`: GPL v3（`altodo.el`）。仕様の MIT は `doc/LICENSE-MIT`
- 動作環境: Emacs 29.1 以上、markdown-mode（2.6 で確認）


## 仕様書

- 正は `doc/altodo_spec_compact.md`。`doc/altodo_spec.md` と `doc/altodo_spec_en.md` は、同じ内容の詳細版
- 仕様を変えたときは、上の 3 ファイルに加えて、`README.md`、`README_en.md`、`doc/design*.md` を同期する
- `~/.claude/rules/altodo_spec_compact.md` は別のコピー。ユーザが更新する
- 解釈が曖昧な点は、推測せずユーザに確認する


## コード修正

- 修正前に、対象と呼び出し元を読み、設計書（`doc/design.md`。フィルタは `doc/design-filter.md`）を確認する
- バックアップを、`altodo.el` の修正前後に取得する
    - `bash .claude/backup_altodo.sh TASK_ID 内容 before` と `... after`
    - 形式と保存先は、グローバルの規則（`.claude/backup`）に従う
- 修正後に、構文チェックとテストを実行し、修正前と結果を比較する
- 重複定義を削除するとき
    1. `grep` で使用箇所を調べる
    2. 2 つの定義を比較し、残す側が削除する側の機能を含むことを確認する
    3. 1 つずつ削除し、削除ごとに構文チェックとテストを実行する


## 構文チェックとテスト

- 構文チェック: `emacs --batch -L . --eval '(progn (find-file "altodo.el") (check-parens))'`
- ローカル CI: `scripts/ci.sh`（lint とテスト。別の Emacs は `EMACS=emacs-30 scripts/ci.sh`）
    - テスト: `scripts/run-tests.sh [test/NAME.el]`。ベースライン（`scripts/test-baseline.txt`、66 件の失敗）との差分で、新しい失敗を報告する
    - lint: `scripts/lint.sh`。バイトコンパイル、checkdoc、package-lint の件数が、ベースライン（`scripts/lint-baseline.txt`）より増えないことを確認する
    - 失敗や警告を減らしたら、`--update-baseline` でベースラインを更新する
- 失敗の原因の多くはテスト側（旧パス、モック、日付の固定）。内訳は `.claude/memo/examine/code-reading-20261018/bug-list.md`


## TODO

- TODO は `project.altodo` のみで管理する
- 記法は、グローバルの `altodo_spec_compact.md` に従う。差異がある場合は、`doc/altodo_spec_compact.md` が最新である
