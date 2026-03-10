# フィルタリング機能 設計書

## 1. 概要

### 目的

altodo-mode でタスクやコメントを条件に基づいてフィルタリングする機能を実装する。フィルタリング機能を元に、フィルタを選択しやくく、状態やフィルタのカウントを表示するサイドバー（バッファ）機能を実装する。


### 機能一覧

- **非表示フィルタ**: 条件に合わない行を非表示にする
- **背景色変更**: 条件に合わない行の背景色を変更する（オプション）（WIP）
- **クリア**: フィルタを解除して全ての行を表示する
- **複数の条件**: 状態、タグ、優先度、日付などでフィルタリング
- **複合条件**: AND/OR/NOT 条件での組み合わせ
- **サイドバー連携**: サイドバーからのフィルタ選択


## 2. 機能要件

### フィルタ種類

| フィルタ         | 説明                                       |
|------------------|--------------------------------------------|
| 状態フィルタ     | done, progress, waiting, open, cancelled   |
| タグフィルタ     | `#tag` でフィルタリング                    |
| @person フィルタ | `@person` でフィルタリング                 |
| 優先度フィルタ   | `!` フラグでフィルタリング                 |
| 期限フィルタ     | 期限超過、期限内などでフィルタリング       |
| 動的フィルタ     | バッファ内の値を自動収集してフィルタリング |
| 親タスクフィルタ | 親タスクの条件でフィルタリング             |


### 複合条件

- **AND**: 全ての条件にマッチ
- **OR**: いずれかの条件にマッチ
- **NOT**: 条件にマッチしない


## 3. 技術選択

### 実装方法

**overlay + buffer-invisibility-spec を使用**

理由:
- 非破壊的（バッファの内容を変更しない）
- 高速（`buffer-invisibility-spec` の変更は非常に高速）
- 標準機能（Emacs の公式機能）
- 柔軟（複数の種類のフィルタを管理可能）


### 代替案と却下理由

| 方法                         | 却下理由                                     |
|------------------------------|----------------------------------------------|
| `keep-lines` / `flush-lines` | 破壊的（バッファの内容を削除）               |
| `occur-mode`                 | 別バッファに表示（元のバッファは変更しない） |
| text property                | undo/redo の対象になる                       |


### パフォーマンス要件

- 5000 行のバッファで 1 秒以内
- フィルタリングは undo/redo の対象外


## 4. 設計の基本原則

### フィルタリングの流れ

1. **predicate 関数**: 各行が条件に合うか判定（`t` = 表示、`nil` = 非表示）
2. **マッチング**: 条件に合う行の範囲を取得
3. **反転**: 条件に合わない行の範囲に変換
4. **overlay 作成**: 非表示範囲に `invisible` プロパティを設定


### predicate 関数の仕様

**入力**: なし（`(point)` が行の先頭にある状態で呼ばれる）

**出力**:
- `t`: この行は条件に**マッチする**（表示したい行）
- `nil`: この行は条件に**マッチしない**（非表示にしたい行）

**例**:
```elisp
;; done タスクを表示
(lambda ()
  (looking-at "^[ ]*\\[x\\]"))

;; @person を含む行を表示
(lambda ()
  (save-excursion
    (re-search-forward "@person\\>" (line-end-position) t)))
```


### ヘルパー関数の仕様

**命名規則**: `altodo--line-*-p` - 現在行が条件に合うか判定

**返り値**: `t`（条件に合う）、`nil`（条件に合わない）


### DSL コンパイラの仕様

`altodo--compile-filter-predicate`: DSL 式から predicate 関数を生成

**例**:
```elisp
;; 入力
(state done)

;; 出力
(lambda ()
  (altodo--line-done-p))
```


## 5. アーキテクチャ

### コンポーネント構成

```
altodo-filter
├── Internal Functions (altodo--*)
│   ├── altodo--filter-init          ; 初期化
│   ├── altodo--filter-lines         ; フィルタリング
│   ├── altodo--filter-cleanup       ; 終了処理
│   ├── altodo--compile-filter-predicate ; DSL コンパイル
│   └── altodo--combine-predicates   ; 述語結合
├── Sidebar Functions (sidebar--*)
│   ├── sidebar--render              ; サイドバー描画
│   ├── sidebar--insert-entry        ; エントリ挿入
│   ├── sidebar--get-face            ; face 取得
│   └── sidebar--apply-filter        ; フィルタ適用
├── User Commands (altodo-filter-*)
│   ├── altodo-filter-clear          ; クリア
│   ├── altodo-filter-show-done-only
│   ├── altodo-filter-show-progress-only
│   └── ...
└── Variables
    ├── altodo--filter-overlays      ; overlay のリスト
    ├── altodo--filter-mode          ; フィルタモード
    └── altodo-sidebar--selected-filters ; 選択されたフィルタ
```

### データフロー

```
User Command / Sidebar Selection
    ↓
DSL Pattern / Filter Entry
    ↓
altodo--compile-filter-predicate
    ↓
predicate 関数
    ↓
altodo--filter-lines / sidebar--apply-filter
    ↓
各行を順番にチェック
    ↓
条件に合わない行に overlay を作成
    ↓
overlay に 'invisible プロパティを設定
    ↓
buffer-invisibility-spec により非表示
```


## 6. 詳細設計

### 6.1 変数

#### altodo--filter-overlays

```elisp
(defvar-local altodo--filter-overlays nil
  "List of overlays used for filtering.")
```

**説明**: フィルタリングで作成された overlay のリスト
**用途**: クリア時に全ての overlay を削除


#### altodo--filter-mode

```elisp
(defvar-local altodo--filter-mode nil
  "Current filter mode.")
```

**説明**: 現在のフィルタモード
**値**: シンボル（`'done`, `'progress`, `'tag`, など）または `nil`


#### altodo-sidebar--selected-filters

```elisp
(defvar-local altodo-sidebar--selected-filters nil
  "List of selected filter entries.")
```

**説明**: サイドバーで選択されたフィルタのリスト


#### altodo-sidebar--combine-mode

```elisp
(defvar-local altodo-sidebar--combine-mode 'and
  "Filter combination mode: 'and or 'or.")
```

**説明**: フィルタの組み合わせモード


### 6.2 内部関数

#### altodo--filter-init

**説明**: フィルタシステムの初期化
**動作**: `buffer-invisibility-spec` に `'altodo-filter` を追加


#### altodo--filter-lines

**説明**: predicate に合致しない行を非表示にする
**入力**: `predicate` 関数
**出力**: overlay のリスト


#### altodo--filter-cleanup

**説明**: フィルタシステムの終了処理
**動作**: 全ての overlay を削除


#### altodo--compile-filter-predicate

**説明**: DSL 式から predicate 関数を生成
**入力**: DSL s 式
**出力**: predicate 関数


#### altodo--combine-predicates

**説明**: 複数の predicate を結合
**入力**: predicate のリスト、結合モード（`and`/`or`）
**出力**: 結合された predicate 関数


### 6.3 サイドバー描画処理

#### sidebar--insert-entry

**説明**: サイドバーにエントリを挿入
**処理**:

1. `:type` に基づいて `action` を決定
   - `'(separator group-header comment nil)` の場合: `action` = `nil`（クリック不可）
   - それ以外の場合: `action` = `#'altodo-sidebar--apply-filter`（クリック可能）

2. `:type` に基づいて face を決定
   - `nil` または `comment`: `'altodo-sidebar-comment-face`
   - `group-header`: `'altodo-sidebar-group-header-face`
   - `search-simple`: `'altodo-sidebar-search-simple-face`
   - `search-lambda`: `'altodo-sidebar-search-lambda-face`
   - `command`: `'altodo-sidebar-command-face`
   - `separator`: `'altodo-sidebar-separator-face`
   - それ以外: `'default`

3. クリック可能な場合: `insert-button` でボタンを作成
4. クリック不可の場合: テキストを挿入（ボタンなし）


#### sidebar--get-face

**説明**: エントリの face を決定（Layer 構造）

**処理順序**:

```
Layer 1: Selection（最優先）
  ↓ 選択されたフィルタエントリ
Layer 2: COUNT（face-rules / count-face-rules）
  ↓ カウント数に基づく face
Layer 3: Default（:face 指定）
  ↓ エントリに :face が指定されている場合
Layer 4: Type-based（デフォルト face）
  ↓ :type に基づくデフォルト face
Layer 5: Non-clickable（コメント行など）
  ↓ クリック不可のエントリ
```

**face-rules フォールバック**:
- face-rules がマッチしない場合、`:face` で指定した face にフォールバック
- `:face` も指定されていない場合、デフォルト face を使用


#### sidebar--apply-filter

**説明**: フィルタを適用
**処理**:

1. `:type` に基づいてフィルタを適用
   - `search-simple`: DSL パターンをコンパイルして predicate を生成
   - `search-lambda`: lambda 関数を predicate として使用
   - `command`: 指定したコマンドを実行
   - `dynamic`: 値を自動収集して展開
   - `nil`/`comment`/`group-header`/`separator`: フィルタなし

2. `altodo--filter-lines` で predicate を適用


### 6.4 動的フィルタ展開

#### altodo--expand-dynamic-filter

**説明**: 動的フィルタエントリを展開

**処理**:

1. `altodo--collect-dynamic-values-*` でバッファから値を収集
   - `person`: `@person` タグの値を収集
   - `tag`: `#tag` の値を収集
   - `due`: `#due:DATE` の値を収集
   - `start`: `#start:DATE` の値を収集

2. `altodo--sort-dynamic-values` でソート
   - `alpha`: アルファベット順
   - `count`: マッチ数順
   - `reverse-count`: マッチ数逆順

3. `altodo--limit-dynamic-values` で制限
   - `:limit` で指定された数まで制限
   - `nil` の場合は制限なし

4. 各値から `search-simple` エントリを生成
   - `:title` の `%s` を値に置換
   - `:pattern` を自動生成（例: `person:NAME`）


#### 6.4.1 altodo--get-entry-count

**説明**: エントリにマッチするタスクの数をカウント

**入力**:
- `entry`: フィルタエントリ plist
- `source-buffer`: ソースバッファ
- `combined-predicate`: 複合フィルタの predicate（オプション）

**処理**:

1. エントリの `:type` に基づいて predicate を生成
   - `search-simple`: DSL パターンをコンパイル
   - `search-lambda`: lambda 関数を predicate として使用
   - `dynamic`: 展開後の predicate を使用

2. バッファ内のタスク行を走査
   - タスク行（`[ ]`, `[@]`, `[w]`, `[x]`, `[~]`）のみカウント
   - コメント行はカウントしない（`:count-exclude-others` が `t` の場合）

3. predicate を適用してマッチ数をカウント
   - `combined-predicate` が指定されている場合は両方を適用

**返り値**: マッチしたタスクの数（整数）


#### 6.4.2 altodo--format-sidebar-title

**説明**: エントリのタイトルを書式化して返す

**入力**:
- `pattern-spec`: フィルタエントリ plist
- `source-buffer`: ソースバッファ
- `combined-predicate`: 複合フィルタの predicate（オプション）
- `combine-mode`: 結合モード（`'and` または `'or`）

**処理**:

1. `:title` から `%n` を検出

2. `%n` がある場合、カウントを計算
   - `altodo--get-entry-count` でマッチ数を取得

3. カウントに face を適用
   - `count-face-rules` が指定されている場合は評価
   - `face-count` が指定されている場合は適用
   - どちらも指定されていない場合は `:face` またはデフォルト

4. `%n` をカウント数に置換
   - カウント文字列に face プロパティを適用

**返り値**: 書式化されたタイトル文字列


### 6.6 複合条件フィルタ

#### 複数選択時の処理

1. ユーザーが複数のエントリを選択
2. `altodo-sidebar--combine-mode` で結合モードを決定
   - `'and`: 全ての predicate にマッチ
   - `'or`: いずれかの predicate にマッチ

3. `altodo--combine-predicates` で predicate を結合
   - 選択された全てのエントリの predicate を収集
   - 結合モードに基づいて結合

4. 結合された predicate を `altodo--filter-lines` に適用


### 6.7 ユーザーコマンド

| コマンド                            | 説明                         |
|-------------------------------------|------------------------------|
| `altodo-filter-clear`               | 全てのフィルタを解除         |
| `altodo-filter-show-done-only`      | done タスクのみ表示          |
| `altodo-filter-show-progress-only`  | progress タスクのみ表示      |
| `altodo-filter-show-waiting-only`   | waiting タスクのみ表示       |
| `altodo-filter-show-open-only`      | open タスクのみ表示          |
| `altodo-filter-show-cancelled-only` | cancelled タスクのみ表示     |
| `altodo-filter-show-tag`            | 指定タグのタスクを表示       |
| `altodo-filter-show-priority`       | 優先度フラグ付きタスクを表示 |
| `altodo-filter-show-star`           | スターフラグ付きタスクを表示 |
| `altodo-filter-show-overdue`        | 期限超過タスクを表示         |
| `altodo-filter-show-person`         | 指定担当者のタスクを表示     |
| `altodo-filter-and`                 | AND モードに切り替え         |
| `altodo-filter-or`                  | OR モードに切り替え          |
| `altodo-filter-not`                 | NOT 条件を適用               |


## 7. サイドバー連携

### フィルタエントリ構造

```elisp
(list
 :title "Filter Name"
 :predicate predicate-function
 :action filter-action
 :type nil  ; nil, "comment", "group-header", "dynamic"
 :nest 0
 :count-format nil
 :count-exclude-others t
 :face nil
 :face-rules nil)
```


### 動的フィルタ

**`:type "dynamic"`** のエントリは表示時に値を自動収集:

- `@person` - 担当者の一覧
- `#tag` - タグの一覧
- `#due` - 期限日の一覧
- `#start` - 開始日の一覧


### 複合条件フィルタ

**`:type nil`** のエントリを複数選択可能:

- `altodo-sidebar--combine-mode` で AND/OR を切り替え
- `altodo--combine-predicates` で述語を結合


## 8. キーバインド

### フィルタ操作

| キー      | 機能                 |
|-----------|----------------------|
| `C-c C-f` | フィルタメニュー表示 |
| `C-c C-c` | フィルタクリア       |

### サイドバー操作

| キー      | 機能                 |
|-----------|----------------------|
| `C-SPC`   | フィルタ選択/解除    |
| `C-c C-a` | AND モードに切り替え |
| `C-c C-o` | OR モードに切り替え  |
| `C-c C-t` | AND/OR をトグル      |


## 9. モードライン表示

### フィルタ状態表示

```
[Filter: done] [AND] (Single)
```

- **Filter: フィルタ名** - 現在のフィルタ
- **[AND]/[OR]** - 結合モード
- **(Single)/(Multiple)** - 選択モード


## 10. パフォーマンス

### 最適化

1. **predicate キャッシュ**: 同じ predicate を再利用
2. **heading-range キャッシュ**: 見出し範囲をキャッシュ
3. **行単位処理**: 1 行ずつ処理し、不要な goto-char を削減


### ベンチマーク目標

- 5000 行のバッファ: 1 秒以内
- 動的フィルタ更新: 100ms 以内


## 11. Face 適用優先度（Layer 構造）

### Layer 1: Selection（最優先）

選択されたフィルタエントリに適用


### Layer 2: COUNT

カウント数に基づく face 適用（`:count-face-rules`）


### Layer 3: Default

エントリに `:face` が指定されている場合


### Layer 4: Type-based

エントリ `:type` に基づくデフォルト face


### Layer 5: Non-clickable

クリック不可のエントリ（`"comment"`, `"group-header"`）


## 12. 参考資料

- `doc/design.md` - 全体設計書
- `doc/altodo_spec.md` - フォーマット仕様書
- `project.altodo` - 実装計画
- `.kiro/memo/` - 開発メモ


## 13. altodo-filter-patterns 仕様

### 13.1 概要

`altodo-filter-patterns` はサイドバーに表示するフィルタパターンを定義するリストである。
`.altodo-locals.el` ファイルまたは `altodo--default-filter-patterns` 変数で設定する。


### 13.2 エントリ構造

各フィルタエントリは plist（プロパティリスト）で定義する：

```elisp
(:title "Display Name" :type TYPE :nest 0 ...)
```


### 13.3 共通プロパティ

| プロパティ              | 必須       | 説明                                                        |
|-------------------------|------------|-------------------------------------------------------------|
| `:title`                | 必須       | サイドバーに表示するタイトル。`%n` でマッチ数を表示         |
| `:type`                 | 必須       | エントリタイプ（後述）                                      |
| `:nest`                 | オプション | インデントレベル（デフォルト: 0）                           |
| `:count-format`         | オプション | `t` で `%n` をカウントに置換（デフォルト: `t`）             |
| `:face`                 | オプション | 適用する face                                               |
| `:face-count`           | オプション | カウント部分 `%n` に適用する face                           |
| `:display-context`      | オプション | 表示コンテキスト（`'all`: 全て, `'heading-only`: 見出しのみ, `'none`: マッチ行のみ） |
| `:count-exclude-others` | オプション | `t` でタスク行のみカウント（デフォルト: `nil`）             |


### 13.4 エントリタイプ（`:type`）

#### `"comment"` もしくは `nil`（コメント行）

クリック不可、フィルタ非適用。視覚的な区切りや説明文に使用。

| プロパティ              | 必須/オプション | 説明                           |
|-------------------------|-----------------|--------------------------------|
| `:face`                 | オプション      | 適用する face                  |
| `:count-exclude-others` | オプション      | `t` でタスク行のみカウント     |


#### `"group-header"`（グループヘッダー）

クリック不可、視覚的な区切り

| プロパティ | 必須/オプション | 説明                     |
|------------|-----------------|--------------------------|
| なし       | -               | フィルタとして機能しない |


#### `"dynamic"`（動的フィルタ）

表示時に値を自動収集

| プロパティ           | 必須/オプション | 説明                                            |
|----------------------|-----------------|-------------------------------------------------|
| `:dynamic-type`      | 必須            | 収集対象（`person`, `tag`, `due`, `start`）     |
| `:exclude-person`    | オプション      | 除外する `@person` リスト                       |
| `:exclude-tag`       | オプション      | 除外する `#tag` リスト                          |
| `:exclude-tag-value` | オプション      | 除外する `#tag:value` リスト                    |
| `:sort`              | オプション      | ソート方法（`alpha`, `count`, `reverse-count`） |
| `:limit`             | オプション      | 表示数制限（デフォルト: nil = 無制限）          |


#### `"search-simple"`（シンプル検索）

DSL パターンマッチ。DSL パターン文字列でフィルタ条件を記述。詳細は「13.5 DSL 構文」を参照

| プロパティ | 必須/オプション | 説明               |
|------------|-----------------|--------------------|
| `:pattern` | 必須            | DSL パターン文字列 |

**DSL パターン例**:

```elisp
;; 完了タスク
(:title "Done [x] - %n" :type search-simple :pattern "done" :count-format t :nest 1)

;; 優先度フラグ付きタスク
(:title "Priority - %n" :type search-simple :pattern "priority" :count-format t :nest 1)

;; 複合条件（AND）
(:title "Open + Priority - %n"
 :type search-simple
 :pattern "(and open priority)"
 :count-format t
 :nest 1)
```


#### `"search-lambda"`（ラムダ検索）

直接 predicate 関数を指定。lambda 関数は引数なしで現在の行で評価され、t を返すと表示、nil を返すと非表示。

| プロパティ | 必須/オプション | 説明        |
|------------|-----------------|-------------|
| `:pattern` | 必須            | lambda 関数 |

**例**:

```elisp
;; 期限が今日で且つ優先度フラグ付きタスク
(:title "Due Today + Priority - %n"
 :type search-lambda
 :pattern (lambda ()
            (and (altodo--due-date-matches-p 'today)
                 (altodo--line-has-flag-p)))
 :count-format t
 :nest 1)
```

**lambda 関数の要件**:
- 引数なし
- 現在の行で評価
- 返り値: `t`（表示）または `nil`（非表示）


#### `"separator"`（区切り線）

視覚的な区切り

| プロパティ | 必須/オプション | 説明                   |
|------------|-----------------|------------------------|
| `:pattern` | オプション      | 区切り線に表示する文字 |


#### `"command"`（コマンド実行）

クリック時に指定したコマンドを実行

| プロパティ | 必須/オプション | 説明         |
|------------|-----------------|--------------|
| `:command` | 必須            | 実行する関数 |


**例**:

```elisp
;; フィルタクリア
(:title "[Clear Filter]" :type command :command altodo-filter-clear :nest 0)

;; カスタムコマンド実行
(:title "[Archive Done]" :type command :command altodo-archive-done-tasks :nest 0)
```

**`:command` に指定できるもの**:
- インタラクティブに呼び出せる関数名（シンボル）
- クリック時にその関数が source buffer で実行される


### 13.5 DSL パターン仕様

#### 13.5.1 単純パターン

文字列で直接指定：

| パターン                  | 説明               |
|---------------------------|--------------------|
| `"done"`                  | 完了タスク         |
| `"progress"`              | 進行中タスク       |
| `"waiting"`               | 待機タスク         |
| `"open"`                  | オープンタスク     |
| `"cancelled"`             | 廃止タスク         |
| `"priority"`              | 優先度フラグ付き   |
| `"star"`                  | スターフラグ付き   |
| `"has-multiline-comment"` | 複数行コメント付き |


#### 13.5.2 引数付きパターン

`(type value)` 形式で指定：

| タイプ                       | 書式                                     | 説明                             |
|------------------------------|------------------------------------------|----------------------------------|
| `tag`                        | `(tag "TAGNAME")`                        | 指定タグを持つタスク             |
| `person`                     | `(person "NAME")`                        | 指定担当者を持つタスク           |
| `text`                       | `(text "STRING")`                        | テキストを含むタスク             |
| `regexp`                     | `(regexp "PATTERN")`                     | 正規表現にマッチ                 |
| `level`                      | `(level N)`                              | ネストレベル N                   |
| `heading`                    | `(heading "PATTERN")`                    | 見出し内に存在                   |
| `due-date`                   | `(due-date CONDITION)`                   | 期限日でフィルタ                 |
| `start-date`                 | `(start-date CONDITION)`                 | 開始日でフィルタ                 |
| `tag-value`                  | `(tag-value "KEY VALUE")`                | タグの値でフィルタ               |
| `parent-task-regexp`         | `(parent-task-regexp "PATTERN")`         | 親タスクがパターンにマッチ       |
| `root-task-regexp`           | `(root-task-regexp "PATTERN")`           | ルート親タスクがパターンにマッチ |
| `multiline-comment-contains` | `(multiline-comment-contains "PATTERN")` | 複数行コメントがパターンを含む   |


#### 13.5.3 日付条件（due-date / start-date）

| 条件                    | 説明        | 例                                           |
|-------------------------|-------------|----------------------------------------------|
| `'overdue`              | 期限超過    | `(due-date 'overdue)`                        |
| `'today`                | 本日期限    | `(due-date 'today)`                          |
| `'this-week`            | 今週期限    | `(due-date 'this-week)`                      |
| `'this-month`           | 今月期限    | `(due-date 'this-month)`                     |
| `after:DATE`            | DATE より後 | `(due-date "after:2024-01-01")`              |
| `before:DATE`           | DATE より前 | `(due-date "before:2024-12-31")`             |
| `between:START:END`     | 範囲内      | `(due-date "between:2024-01-01:2024-12-31")` |


#### 13.5.4 論理演算

| 演算  | 書式                  | 説明             |
|-------|-----------------------|------------------|
| `and` | `(and PAT1 PAT2 ...)` | 全てにマッチ     |
| `or`  | `(or PAT1 PAT2 ...)`  | いずれかにマッチ |
| `not` | `(not PAT)`           | マッチしない     |


#### 13.5.5 タグ値条件（tag-value）

| 書式                                    | 説明                        |
|-----------------------------------------|-----------------------------|
| `(tag-value "key" "value")`             | 完全一致                    |
| `(tag-value "key" ("value1" "value2"))` | 複数値（OR）                |
| `(tag-value "key" (> 5))`               | 数値比較（>, <, =, >=, <=） |


### 13.6 face-rules および count-face-rules 仕様

`:face-rules` と `:count-face-rules` でカウント数に基づく face を指定できる。

- face-rules: フィルタ行本文全体
- count-face-rules: フィルタ行のカウント部分 `%n` のみに適用される。この項目が存在しない場合、 `%n` には `:face-rules` や `:face` の項目が適用される


```elisp
:face-rules ((>= 5 (:foreground "red" :weight bold))
             (>= 3 (:foreground "orange"))
             (>= 1 (:foreground "green"))
             (= 0 (:foreground "gray")))
```

**書式**: `(条件 face-spec)`

**条件**:
- `>= N` - N 以上
- `> N` - N より大きい
- `= N` - N と等しい
- `<= N` - N 以下
- `< N` - N より小さい

__face-spec__ は以下の通り指定できる。

- face 名（`:foreground "red"`）
- face 名リスト（`error`, `warning`, `success`）
- plist（`(:foreground "red" :weight bold)`）

face-rules 内でマッチしない場合、`:face` で指定した face にフォールバック。`:face` も指定されていない場合はデフォルト face を使用。


### 13.7 設定例

```elisp
;; .altodo-locals.el
(
 (altodo-filter-patterns .
  (
   ;; グループヘッダー
   (:title "Status" :type group-header :nest 0)
   
   ;; 通常フィルタ
   (:title "Open [ ] - %n" :type search-simple :pattern "open" :count-format t :nest 1)
   (:title "Done [x] - %n" :type search-simple :pattern "done" :count-format t :nest 1)
   
   ;; 動的フィルタ
   (:title "@Person - %n" :type dynamic :dynamic-type person :count-format t :nest 1)
   (:title "#Tag - %n" :type dynamic :dynamic-type tag :count-format t :nest 1)
   
   ;; face-rules 付き
   (:title "Priority - %n" :type search-simple :pattern "priority" :count-format t :nest 1
    :face-rules ((>= 5 error)
                 (>= 1 warning)))
   
   ;; 複合条件
   (:title "Open + Priority - %n"
    :type search-simple
    :pattern "(and open priority)"
    :count-format t :nest 1)
   
   ;; 区切り線
   (:title "" :type separator :nest 0)
   
   ;; コマンド
   (:title "[Clear]" :type command :command altodo-filter-clear :nest 0)
   ))
)
```


### 13.8 デフォルト設定

```elisp
altodo--default-filter-patterns = '(
 (:title "Status" :type group-header :nest 0)
 (:title "Open [ ] - %n" :type search-simple :pattern "open" :count-format t :nest 1)
 (:title "In Progress [@] - %n" :type search-simple :pattern "progress" :count-format t :nest 1)
 (:title "Waiting [w] - %n" :type search-simple :pattern "waiting" :count-format t :nest 1)
 (:title "Done [x] - %n" :type search-simple :pattern "done" :count-format t :nest 1)
 (:title "Cancelled [~] - %n" :type search-simple :pattern "cancelled" :count-format t :nest 1)
 (:title "Flags" :type group-header :nest 0)
 (:title "Priority (!) - %n" :type search-simple :pattern "priority" :count-format t :nest 1)
 (:title "Star (+) - %n" :type search-simple :pattern "star" :count-format t :nest 1)
 (:title "[Clear Filter]" :type command :command altodo-filter-clear :nest 0)
)
```

---

**最終更新**: 2026-03-07
**バージョン**: 2.1.0
