# altodo プロジェクト

Emacs の major mode（`altodo.el`）と、altodo フォーマット（Markdown 埋め込み型の TODO 形式）の仕様を管理する。
グローバルの CLAUDE.md に加えて、次の規則に従う。矛盾する場合は本ファイルを優先する。


## 構成

- `altodo.el`: 本体
- `altodo-calendar.el`: ミニカレンダーのライブラリ（`calendar` だけに依存。altodo.el が require する。`altodo.el` と同じ場所に置く）
- `altodo-debug.el`: 調査用のコマンド（任意。altodo.el は読み込まない。`scripts/debug-line.sh`、`scripts/debug-pattern.sh` が使う。`altodo.el` と一緒に配布するときは同じ場所に置く）
- `doc/`: 仕様書・設計書（`*_en.md` は英訳。調査用のコマンドは `doc/debug.md`）
- `test/`: ERT。`project.altodo`: TODO（ルート）
- `.claude/memo/`: メモ（旧い計画のアーカイブは `.claude/memo/etc/project-altodo-archive-20261018.altodo`）。`.claude/backup/`: バックアップ
- `scripts/`: 開発用スクリプト（`setup-emacs.sh`: Emacs 29.3、markdown-mode、package-lint の導入。Ubuntu 24.04）
- `LICENSE`: GPL v3（`altodo.el`）。仕様の MIT は `doc/LICENSE-MIT`
- 動作環境: Emacs 29.1 以上、markdown-mode（2.6 で確認）


## 仕様書

- 正は `doc/altodo_spec_compact.md`。`doc/altodo_spec.md` と `doc/altodo_spec_en.md` は、同じ内容の詳細版
- 仕様を変えたときは、上の 3 ファイルに加えて、`README.md`、`README_en.md`、`doc/design*.md` を同期する
- 利用者に見える挙動を変えたときは、`CHANGELOG.md` と `CHANGELOG_en.md` の「未リリース」にも書く
- `~/.claude/rules/altodo_spec_compact.md` は別のコピー。ユーザが更新する
- 解釈が曖昧な点は、推測せずユーザに確認する
- 動作に関する仕様は、自分で決めずに、実装の前にユーザに確認する（`AskUserQuestion`）。選択肢を示し、推奨を最初に置く
    - 確認の対象: 機能の振る舞い、既定値、キー割り当て、設定変数の名前と意味、コマンドの名前、エラー時と境界の扱い、日付・書式の解釈、既存の動作の変更
    - 確認しなくてよいもの: 内部の関数名や構造、テストの書き方、ドキュメントの体裁、docstring の文言
    - ユーザが「推奨の通り」と答えた場合も、確認の時に示していなかった細部は、実装の前に改めて確認する。確認せずに決めたときは、決めた内容と理由を、報告の冒頭に書く
    - 調査（関数の有無、既存の挙動の確認）は、確認せずに進めてよい


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
- ローカル CI: `scripts/ci.sh`（lint、テスト、ドキュメントの名前の確認。別の Emacs は `EMACS=emacs-30 scripts/ci.sh`）
    - テスト: `scripts/run-tests.sh [test/NAME.el]`。ベースライン（`scripts/test-baseline.txt`。現在は失敗 0 件）との差分で、新しい失敗を報告する
    - lint: `scripts/lint.sh`。バイトコンパイル、checkdoc、package-lint の件数が、ベースライン（`scripts/lint-baseline.txt`）より増えないことを確認する
    - 失敗や警告を減らしたら、`--update-baseline` でベースラインを更新する
    - ドキュメントの名前: `scripts/check-doc-symbols.sh`。バッククォートで書かれた `altodo-*`、`sidebar-*` が `altodo.el` に定義されているか確認する。意図的に未定義の名前は `scripts/doc-symbols-ignore.txt` に書く
    - 性能: `scripts/bench-filter.sh [--sizes "5000 10000"] [--repeat N] [--max SECONDS]`。フィルタの処理時間を測定する。CI には含めない。処理速度は速いほどよい（5000 行で 1 秒は設計時の目安であり、上限ではない）
- テストの一覧: `test/INDEX.md`（`scripts/gen-test-map.py` が生成。テストを探す・追加する前に読む。`scripts/ci.sh` が最新かを確認する）
- テストの書き方
    - 共通の道具は `test/altodo-test-helper.el`（バッファ、一時ディレクトリ、サンプルの設定ファイル、今日の日付の固定）
    - 日付に依存するテストは `altodo-test-with-today` で日付を固定する。サンプルは一時ディレクトリに作り、プロジェクトのファイルを変更しない
    - 実装と仕様の差は、`:expected-result :failed` を付けて記録する。`(should t)` のような意味のないアサーションを書かない
    - 調査用のスクリプトは `test/archive/` に置き、`test/*.el` に置かない
- 手動確認用のサンプル: `testfiles/`（`testfiles/README.md`）。`scripts/gen-testfiles.sh` が、今日を基準にした日付のファイルと大きなファイルを生成する。`test/testfiles-test.el` が、サンプルの妥当性を確認する


## 開発支援スクリプトの提案

Emacs Lisp の作成・修正・改善で、繰り返す作業や間違えやすい確認を見つけたら、それを自動化するスクリプトを、ユーザに提案する。手作業や使い捨てのコマンドで済ませ続けない。

- 提案する場面
    - 同じ確認を 2 回以上行った、またはこれから繰り返す（再現、性能測定、プロファイル、比較、整合性の確認）
    - 手順が長い、または間違えやすい
    - 例: 大きなバッファでの性能測定、ドキュメントに書かれた関数・変数が `altodo.el` に実在するかの確認、日本語版と英語版の見出しの対応の確認、lint の指摘の差分の表示
- 提案に含める内容
    - 目的と、防げる問題
    - 使い方（引数、環境変数、終了コード）、置き場所（`scripts/`）、おおよその作成工数
    - 既存の `scripts/ci.sh` に組み込むか、単独で実行するか
    - 実行確認を省く設定（`.claude/settings.json`）の要否。読み取りだけを行うスクリプトに限る
- 作成の手順
    - 提案し、ユーザの了承を得てから作成する。依頼された作業そのものに必要な場合は、先に作成してよい
    - 既存のスクリプト（`ls scripts/`）で足りないかを、先に確認する
    - bash のスクリプトは、グローバルの bash コーディングルールに従う。100 行を超える、または制御が複雑な場合は、Python での作成を提案する
    - 作成したら、`project.altodo` に記録し、「構成」の節の `scripts/` の説明に追記する
- 使い捨ての確認用コードは、`scripts/` に置かない。メモのディレクトリ（`.claude/memo/issue/タスクID_内容/`）に置き、再利用する価値が出たら、スクリプト化を提案する


## TODO

- TODO は `project.altodo` のみで管理する
- 記法は、グローバルの `altodo_spec_compact.md` に従う。差異がある場合は、`doc/altodo_spec_compact.md` が最新である
