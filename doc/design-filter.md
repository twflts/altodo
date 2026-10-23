# フィルタリング機能 設計書

## 1. 概要

### 目的

altodo-mode でタスクやコメントを条件に基づいてフィルタリングする機能を実装する。フィルタリング機能を元に、フィルタを選択しやすく、状態やフィルタのカウントを表示するサイドバー（バッファ）機能を実装する。


### 機能一覧

- **非表示フィルタ**: 条件に合わない行を非表示にする
- **クリア**: フィルタを解除して全ての行を表示する
- **複数の条件**: 状態、タグ、優先度、日付などでフィルタリング
- **複合条件**: AND/OR/NOT 条件での組み合わせ
- **サイドバー連携**: サイドバーからのフィルタ選択


## 2. 機能要件

### フィルタ種類

| フィルタ         | 説明                                       |
| ---------------- | ------------------------------------------ |
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
| ---------------------------- | -------------------------------------------- |
| `keep-lines` / `flush-lines` | 破壊的（バッファの内容を削除）               |
| `occur-mode`                 | 別バッファに表示（元のバッファは変更しない） |
| text property                | undo/redo の対象になる                       |


### パフォーマンス要件

- 処理時間は短いほどよい。上限となる要件は設けない
- 設計時の目安は、5000 行のバッファで 1 秒以内である。測定は `scripts/bench-filter.sh` で行う
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


### predicate 関数のエラー

predicate 関数が途中の行でエラーを出したときは、その実行で作成した overlay を全て削除し（フィルタを解除し）、メッセージを表示して、エラーを再送出する。一部の行だけが非表示のまま残ると、フィルタの結果と区別できないためである。


### ヘルパー関数の仕様

**命名規則**: `altodo--line-*-p` - 現在行が条件に合うか判定

**返り値**: `t`（条件に合う）、`nil`（条件に合わない）


### DSL コンパイラの仕様

`altodo--compile-filter-predicate`: フィルタエントリ（plist）から predicate 関数を生成する。

- `:type` が `search-lambda` の場合: `:pattern` の関数をそのまま返す
- `:type` が `search-simple` の場合: `:pattern` の文字列を `altodo--compile-simple-pattern` でコンパイルする
- それ以外の場合: 常に `nil` を返す関数を返す

文字列パターンのコンパイルに失敗した場合（書式の誤り、未知の種類）は、メッセージを表示し、どの行にも一致しない関数を返す。パターンの書式は 13.5 節に記載する。

**例**: パターン文字列 `"and:open,priority"` から、オープンかつ優先度フラグ付きの行で `t` を返す関数を生成する。


## 5. アーキテクチャ

### コンポーネント構成

```
altodo-filter
├── Internal Functions (altodo--*)
│   ├── altodo--filter-init          ; 初期化
│   ├── altodo--filter-lines         ; フィルタリング
│   ├── altodo--compile-filter-predicate ; DSL コンパイル
│   └── altodo--combine-predicates   ; 述語結合
├── Sidebar Functions (altodo-sidebar--*)
│   ├── altodo-sidebar--render       ; サイドバー描画
│   ├── altodo-sidebar--insert-entry ; エントリ挿入
│   ├── altodo-sidebar--get-face     ; face 取得
│   └── altodo-sidebar--apply-filter ; フィルタ適用
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
altodo--filter-lines / altodo-sidebar--apply-filter
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


#### サイドバーの選択の状態

```elisp
(defvar-local altodo-sidebar--selected-filters nil)
(defvar-local altodo-sidebar--selection-mode nil)
(defvar-local altodo-sidebar--current-combined-predicate nil)
```

**説明**: サイドバーのバッファのバッファローカル変数。選択の状態を表す
**値**:
- `altodo-sidebar--selected-filters`: 選択されたフィルタエントリのリスト
- `altodo-sidebar--selection-mode`: `single`（エントリをクリックした状態。リストの要素は 1 つ）、`multiple`（`s` で複数選択した状態）、`nil`（選択なし）
- `altodo-sidebar--current-combined-predicate`: `multiple` のときの、結合した predicate。カウントに使う

**更新**: 3 つの変数は `altodo-sidebar--set-selection` だけが変更する。クリック、複数選択、`altodo-filter-clear`、`altodo-filter-show-*`、`altodo-filter-by-pattern` は、いずれもこの関数を通る。選択の状態が、実際のフィルタと食い違わない
**参照**: `altodo-sidebar--entry-state` が、エントリの状態（`selected`、`active`、`nil`）を返す。`single` のエントリは `active`、`multiple` のエントリは `selected` である


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


#### altodo--compile-filter-predicate

**説明**: フィルタエントリから predicate 関数を生成
**入力**: フィルタエントリ（plist）
**出力**: predicate 関数


#### altodo--combine-predicates

**説明**: 複数の predicate を結合
**入力**: predicate のリスト、結合モード（`and`/`or`）
**出力**: 結合された predicate 関数


### 6.3 サイドバー描画処理

#### altodo-sidebar--insert-entry

**説明**: サイドバーにエントリを挿入
**処理**:

1. `:type` に基づいて `action` を決定
   - `'(separator group-header comment nil)` の場合: `action` = `nil`（クリック不可）
   - それ以外の場合: `action` = `#'altodo-sidebar--apply-filter`（クリック可能）

2. `altodo--format-sidebar-title` でタイトルを作る。`%n` の数字には、カウント部分の face が付く

3. `altodo-sidebar--get-face` で行全体の face を求め、タイトルのうち face のない文字に付ける。選択されたエントリ（`selected`、`active`）は、タイトルの face を取り除き、タイトル全体にその face を付ける

4. クリック可能な場合: `make-text-button` でボタンにする。クリック不可の場合: ボタンにせず、読み取り専用にする。区切り線（`separator`）は、行全体に face を付ける

行全体の face の付け方は、この 1 つの経路だけである。


#### altodo-sidebar--get-face

**説明**: エントリの行全体の face を決定（Layer 構造）

**処理順序**: 11.1 節の Layer 構造に従う。カウント部分（`%n`）の face は、`altodo--count-face` が決める（11.2 節）。

**カウント**: `:face-rules` の評価に使うカウントは、タイトルの `%n` と同じ値である（`%n` がなくても数える）。複数選択のときは、結合した predicate を適用したカウントである。


#### altodo-sidebar--apply-filter

**説明**: フィルタを適用
**処理**:

1. `:type` に基づいてフィルタを適用
   - `search-simple`: DSL パターンをコンパイルして predicate を生成
   - `search-lambda`: lambda 関数を predicate として使用
   - `command`: 指定したコマンドを実行
   - `heading-jump`: 見出しへ移動
   - `nil`/`comment`/`group-header`/`separator`: フィルタなし

2. `search-simple` と `search-lambda` は、選択の状態を `single`（クリックしたエントリ 1 つ）にして、`altodo--filter-lines` で predicate を適用する。`:display-context` と `:multiline-comment` は、両方の種類に適用する

3. サイドバーの描画は 1 回である。`command` の場合、実行したコマンドがフィルタを変えるときは、そのコマンドが選択の状態を解除する


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
   - `nil` または `0` の場合は制限なし

4. 各値から `search-simple` エントリを生成
   - `:title` の `%s` を値に置換
   - `:pattern` を自動生成（例: `person:NAME`）


#### altodo--expand-heading-filter

**説明**: `:dynamic-type "heading"` のエントリを展開

**処理**:

1. `altodo--collect-headings` が、バッファを 1 回走査して、見出し（ATX と Setext。コードブロック内は除く）の文字列、レベル、位置、未完了のタスク数を返す
2. `:level` で絞り、`:limit` で先頭から切る
3. 見出しごとに `:type heading-jump` のエントリを作る。`:marker` に見出しの行頭のマーカーを設定する。`:nest` には、エントリの `:nest` と `:indent-by-level` の段数の和を設定する

`altodo-sidebar--apply-filter` は、`heading-jump` のエントリを `save-window-excursion` の外で `altodo-sidebar--jump-to-heading` に渡す。この関数は、次の順に処理する。

1. マーカーの行が見出しであることを確認する。見出しでなければ、メッセージを表示して終了する
2. 見出しがフィルタのオーバーレイで非表示なら、`altodo-filter-clear` を呼ぶ
3. ソースのウィンドウを選択し、`recenter 0` で見出しを上端に置く

**性能**: 10000 行のバッファで、未完了のタスク数を含む走査は約 13 ms、50000 行で約 60 ms である。


#### altodo--get-entry-count

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

**再利用**: 1 回の描画の中では、エントリごとに 1 回だけ数える（タイトルと行の face が同じ値を使う）。`combined-predicate` がなく、パターンが文字列（DSL）のときは、バッファの文字、狭窄、今日の日付が同じ間、数えた結果を `altodo--count-memo` に残す。クリック、選択、AND/OR の切り替えでは、バッファを数え直さない。パターンが関数のエントリは、関数が何を読むか分からないため、毎回数える


#### altodo--format-sidebar-title

**説明**: エントリのタイトルを書式化して返す

**入力**:
- `pattern-spec`: フィルタエントリ plist
- `source-buffer`: ソースバッファ
- `combined-predicate`: 複合フィルタの predicate（オプション）
- `combine-mode`: 結合モード（`'and` または `'or`）

**処理**:

1. `:title` から `%n` を検出。`:count-format` が `nil` のときは置換しない（省略したときは `t`）

2. `%n` がある場合、カウントを計算
   - `altodo--get-entry-count` でマッチ数を取得

3. カウント部分の face を `altodo--count-face` で決める
   - `:count-face-rules` の最初にマッチした規則の face
   - なければ `:face-count`
   - どちらもなければ、カウントに face を付けない（行全体の face が付く）

4. `%n` をカウント数に置換
   - カウント文字列に face プロパティを適用

**返り値**: 書式化されたタイトル文字列


### 6.5 複合条件フィルタ

#### 複数選択時の処理

1. ユーザーが複数のエントリを選択
2. `altodo-sidebar--combine-mode` で結合モードを決定
   - `'and`: 全ての predicate にマッチ
   - `'or`: いずれかの predicate にマッチ

3. `altodo--combine-predicates` で predicate を結合
   - 選択された全てのエントリの predicate を収集
   - 結合モードに基づいて結合

4. 結合された predicate を `altodo--filter-lines` に適用


### 6.6 ユーザーコマンド

| コマンド                             | 説明                             |
| ------------------------------------ | -------------------------------- |
| `altodo-filter-clear`                | 全てのフィルタを解除             |
| `altodo-filter-by-pattern`           | DSL パターンに一致する行のみ表示 |
| `altodo-filter-show-done-only`       | done タスクのみ表示              |
| `altodo-filter-show-progress-only`   | progress タスクのみ表示          |
| `altodo-filter-show-waiting-only`    | waiting タスクのみ表示           |
| `altodo-filter-show-open-only`       | open タスクのみ表示              |
| `altodo-filter-show-cancelled-only`  | cancelled タスクのみ表示         |
| `altodo-filter-show-tag`             | 指定タグのタスクを表示           |
| `altodo-filter-show-priority`        | 優先度フラグ付きタスクを表示     |
| `altodo-filter-show-star`            | スターフラグ付きタスクを表示     |
| `altodo-filter-show-overdue`         | 期限超過タスクを表示             |
| `altodo-filter-show-person`          | 指定担当者のタスクを表示         |
| `altodo-sidebar-set-and-mode`        | AND モードに切り替え             |
| `altodo-sidebar-set-or-mode`         | OR モードに切り替え              |
| `altodo-sidebar-toggle-combine-mode` | AND/OR をトグル                  |

`altodo-filter-clear`、`altodo-filter-by-pattern`、`altodo-filter-show-*` は、サイドバーの選択の状態を解除して、サイドバーを描画し直す。サイドバーの `c` は、サイドバーに対応するバッファのフィルタを解除する。


## 7. サイドバー連携

### フィルタエントリ構造

フィルタエントリは plist である。プロパティは 13.3 節、種類（`:type`）は 13.4 節に記載する。


### 動的フィルタ

**`:type dynamic`** のエントリは表示時に値を自動収集:

- `@person` - 担当者の一覧
- `#tag` - タグの一覧
- `#due` - 期限日の一覧
- `#start` - 開始日の一覧
- 見出し - 見出しの一覧（選ぶと見出しの行へ移る。絞り込みは変えない）


### 複合条件フィルタ

サイドバーのエントリを複数選択できる（`s` キー、または Ctrl + マウス左ボタン）:

- `altodo-sidebar--combine-mode` で AND/OR を切り替え
- `altodo--combine-predicates` で述語を結合


## 8. キーバインド

### フィルタ操作

| キー          | 機能               |
| ------------- | ------------------ |
| `C-c C-v f c` | フィルタクリア     |
| `C-c C-v s t` | サイドバー表示切替 |
| `C-c C-v s r` | サイドバー更新     |


### サイドバー操作

| キー          | 機能                                                |
| ------------- | --------------------------------------------------- |
| `RET`、`SPC`  | フィルタを適用                                      |
| `s`           | フィルタを選択/解除                                 |
| `C-<mouse-1>` | フィルタを選択/解除                                 |
| `c`           | フィルタクリア                                      |
| `r`           | サイドバー更新                                      |
| `q`           | サイドバーを閉じる                                  |
| `?`、`h`      | キーバインドのヘルプを表示（`altodo-sidebar-help`） |
| `}`、`{`、`.` | カレンダーの次の月、前の月、今月                    |
| `n`、`p`      | 次の行、前の行へ移動                                |
| `C-c C-a`     | AND モードに切り替え                                |
| `C-c C-o`     | OR モードに切り替え                                 |
| `C-c C-t`     | AND/OR をトグル                                     |


## 9. モードライン表示

### フィルタ状態表示

```
[AND] (Single)
```

- `[AND]` と `[OR]`: 結合モード。クリックで切り替える
- `(Single)` と `(Multiple)`: 選択モード


## 10. パフォーマンス

### 最適化

1. **heading-range キャッシュ**: 見出し範囲をキャッシュする
2. **行位置の相対移動**: 行番号の昇順に処理し、前回の位置から移動する。バッファの先頭から行を数え直さない（`altodo--goto-line`）
3. **overlay の検索範囲の限定**: 対象行の範囲の overlay だけを調べる（`overlays-in`）
4. **カウントの再利用**: バッファが変わらない間は、エントリごとのカウントを再利用する（6.4 節の `altodo--get-entry-count`）。クリックの処理時間は、5000 行（既定のパターン、20 エントリ）で約 1.4 秒から約 0.2 秒（2 回目以降。1 回目は約 0.75 秒）になる
5. **見出しの範囲と行番号の一括処理**: 見出しの範囲を 1 回の走査で求め、行番号に変換する。マッチした行ごとに全見出しを調べず、overlay の一覧の更新は終了時に 1 回で行う


### 測定

`scripts/bench-filter.sh` で、行数、パターン、表示コンテキストごとの処理時間を測定する。

- 目安: 5000 行のバッファで 1 秒以内、動的フィルタの更新で 100ms 以内。いずれも設計時の目安であり、上限ではない。処理時間は短いほどよい
- 見出し範囲の計算（`altodo--compute-all-heading-ranges`）は、バッファを 1 回走査する（行数に比例する）
- 表示行の計算（`altodo--compute-display-lines`）は、見出しの範囲を行番号に変換し、マッチした行を昇順に走査して、行を含む見出しを求める。マッチした行ごとに全見出しを調べない。overlay の一覧（`altodo--filter-overlays`）からの削除は、`altodo--filter-lines` の終了時に 1 回で行う
- 測定値（`tag:work`、表示コンテキストあり）: 10,000 行で 0.36 秒、20,000 行で 0.85 秒である。行数を 2 倍にすると、処理時間は約 2.4 倍になる


## 11. Face 適用優先度（Layer 構造）

行全体の face と、カウント部分（`%n` の数字）の face は、別の軸で決める。


### 11.1 行全体の face

`altodo-sidebar--get-face` が、次の順に判定し、最初に決まったものを使う。

1. Selected: `s` で複数選択されたエントリ。`altodo-sidebar-selected-filter-face`
2. Active: クリックしたエントリ。`altodo-sidebar-active-filter-face`
3. `:face-rules`: `:count-format` が `nil` でないとき、カウントが最初にマッチした規則の face
4. `:face`
5. 種類ごとの既定の face

Selected と Active のエントリは、タイトルの face を取り除き、タイトル全体（カウントを含む）にその face を付ける。それ以外のエントリは、タイトルのうち face のない文字に、行全体の face を付ける。

種類ごとの既定の face は次の通り。クリック不可のエントリ（`comment`、`group-header`、`separator`）も、ここで決まる。

- `nil` と `comment`: `altodo-sidebar-comment-face`
- `group-header`: `altodo-sidebar-group-header-face`
- `search-simple` と `heading-jump`: `altodo-sidebar-search-simple-face`
- `search-lambda`: `altodo-sidebar-search-lambda-face`
- `command`: `altodo-sidebar-command-face`
- `separator`: `altodo-sidebar-separator-face`
- それ以外: `default`


### 11.2 カウント部分の face

`%n` の数字の face は、次の順に判定する。Selected と Active のエントリには適用しない。

1. `:count-face-rules`: カウントが最初にマッチした規則の face
2. `:face-count`
3. 行全体の face（11.1 節）

`:count-face-rules` と `:face-count` は、数字だけに適用する。行全体には適用しない。


### 11.3 カウントの値

`:face-rules` と `:count-face-rules` の条件に使うカウントは、タイトルの `%n` と同じ値である。タイトルに `%n` がなくても数える。複数選択のときは、結合した predicate を適用した値になる（AND はエントリと結合した predicate の両方、OR はエントリだけ）。


### 11.4 face の指定の形

`:face`、`:face-count`、`:face-rules` と `:count-face-rules` の値は、同じ関数（`altodo-sidebar--resolve-face`）で解釈する。指定できる形は 13.6 節に示す。解釈できない値は、指定がないものとして扱う。


## 12. 参考資料

- `doc/design.md` - 全体設計書
- `doc/altodo_spec.md` - フォーマット仕様書


## 13. altodo-filter-patterns 仕様

### 13.1 概要

`altodo-filter-patterns` はサイドバーに表示するフィルタパターンを定義するリストである。
`.altodo-locals.el` ファイルまたは `altodo-default-filter-patterns` 変数で設定する。


### 13.2 エントリ構造

各フィルタエントリは plist（プロパティリスト）で定義する。

```elisp
(:title "Display Name" :type TYPE :nest 0 ...)
```


### 13.3 共通プロパティ

| プロパティ              | 必須       | 説明                                                            |
| ----------------------- | ---------- | --------------------------------------------------------------- |
| `:title`                | 必須       | サイドバーに表示するタイトル。`%n` でマッチ数を表示             |
| `:type`                 | 必須       | エントリタイプ（後述）                                          |
| `:nest`                 | オプション | インデントレベル（デフォルト: 0）                               |
| `:count-format`         | オプション | `nil` で `%n` を置換しない（デフォルト: `t`）                   |
| `:face`                 | オプション | 行全体に適用する face（形は 13.6 参照）                         |
| `:face-count`           | オプション | カウント部分 `%n` に適用する face                               |
| `:face-rules`           | オプション | カウントに応じた行全体の face（13.6 参照）                      |
| `:count-face-rules`     | オプション | カウントに応じたカウント部分の face（13.6 参照）                |
| `:display-context`      | オプション | 表示コンテキスト（詳細は 13.3.1 参照）                          |
| `:multiline-comment`    | オプション | `nil` でマッチ行の複数行コメントを表示しない（デフォルト: `t`） |
| `:count-exclude-others` | オプション | カウント対象（詳細は 13.3.2 参照、デフォルト: `t`）             |


#### 13.3.1 `:display-context` - 表示コンテキスト

フィルタ適用時に、マッチ行に加えて表示する行を制御する。指定しない場合は `'heading-only` である。

| 値              | 説明                                                 |
| --------------- | ---------------------------------------------------- |
| `'heading-only` | マッチ行と、その見出し（デフォルト）                 |
| `'all`          | マッチ行、その見出し、およびマッチ行の複数行コメント |
| `'none`         | マッチ行のみ                                         |

**例**:

```elisp
;; マッチ行と見出しを表示（デフォルト）
(:title "Open - %n" :type search-simple :pattern "open" :display-context 'heading-only)

;; マッチ行、見出し、複数行コメントを表示
(:title "Open (all) - %n" :type search-simple :pattern "open" :display-context 'all)

;; マッチ行のみ表示
(:title "Open (lines only) - %n" :type search-simple :pattern "open" :display-context 'none)
```


#### 13.3.2 `:count-exclude-others` - カウント対象

カウント時に含める行の種類を制御する。タスク行とコメント行の両方が存在する場合、どちらをカウント対象にするかを指定。

| 値    | 説明                                                   | 用途                                         |
| ----- | ------------------------------------------------------ | -------------------------------------------- |
| `t`   | タスク行のみカウント（コメント行を除外）（デフォルト） | 通常のフィルタリング。複数行コメント行は除外 |
| `nil` | 全ての行をカウント（タスク行とコメント行の両方）       | コメント行も含めてカウントしたい場合         |

__具体例__

```
[ ] Task 1
    /// Comment for Task 1
[ ] Task 2
    /// Comment for Task 2
```

- `:count-exclude-others t` の場合: マッチ数は _2_（タスク行のみ）
- `:count-exclude-others nil` の場合: マッチ数は _4_（タスク行 + コメント行）

**設定例**:

```elisp
;; タスク行のみカウント（デフォルト）
(:title "Open Tasks - %n" :type search-simple :pattern "open" :count-exclude-others t)

;; 全ての行をカウント
(:title "All Matches - %n" :type search-simple :pattern "open" :count-exclude-others nil)
```


### 13.4 エントリタイプ（`:type`）

#### `comment` もしくは `nil`（コメント行）

クリック不可、フィルタ非適用。視覚的な区切りや説明文に使用。

| プロパティ              | 必須/オプション | 説明                       |
| ----------------------- | --------------- | -------------------------- |
| `:face`                 | オプション      | 適用する face              |
| `:count-exclude-others` | オプション      | `t` でタスク行のみカウント |


#### `group-header`（グループヘッダー）

クリック不可、視覚的な区切り。

| プロパティ | 必須/オプション | 説明                     |
| ---------- | --------------- | ------------------------ |
| なし       | -               | フィルタとして機能しない |


#### `dynamic`（動的フィルタ）

表示時に値を自動収集しリスト表示する。

| プロパティ           | 必須/オプション | 説明                                                         |
| -------------------- | --------------- | ------------------------------------------------------------ |
| `:dynamic-type`      | 必須            | 収集対象（`person`, `tag`, `due`, `start`, `heading`）       |
| `:tag-mode`          | オプション      | タグ抽出モード（`"all"`, `"name-only"`, `"with-value"`）     |
| `:exclude-person`    | オプション      | 除外する `@person` リスト                                    |
| `:exclude-tag`       | オプション      | 除外する `#tag` リスト                                       |
| `:exclude-tag-value` | オプション      | 除外する `#tag:value` リスト                                 |
| `:sort-by`           | オプション      | 並べ替え（`"alpha"`: 昇順（既定）、`"count"`: 件数の多い順） |
| `:limit`             | オプション      | 表示数制限（デフォルト: nil。nil または 0 は無制限）         |

`:sort-by` は `person` と `tag` にだけ効く。`due` と `start` は常に昇順（日付の文字列順）である。

`:tag-mode` のオプションは以下の通り。

| モード         | 説明                         | 例                                                       |
| -------------- | ---------------------------- | -------------------------------------------------------- |
| `"all"`        | 値なし・値ありタグを全て抽出 | `#java`, `#priority:high` → `["java", "priority:high"]` |
| `"name-only"`  | タグ名のみ（デフォルト）     | `#java`, `#priority:high` → `["java", "priority"]`      |
| `"with-value"` | 値ありタグのみ抽出           | `#priority:high` → `["priority:high"]`                  |

**注**: `:tag-ignore-value` と `:tag-mode "name-only"` は同様。

上の表と次の `:level`、`:indent-by-level` 以外のプロパティ（`:face`、`:face-count`、`:face-rules`、`:count-face-rules`、`:count-exclude-others`、`:display-context`、`:multiline-comment` など）は、展開後のエントリに引き継ぐ。展開後のエントリは、通常のエントリと同じに動作する。

`:dynamic-type "heading"` は、値を収集して絞り込むのではなく、見出しへ移るエントリ（`:type heading-jump`）に展開する。専用のプロパティは次の通り。`:sort-by`、`:exclude-*`、`:tag-mode` は無視する。

- `:level`（オプション）: 対象のレベル。整数、または整数のリスト。省略は全レベル
- `:limit`（オプション）: バッファの先頭からの見出しの数の上限。`0` または `nil` は無制限
- `:indent-by-level`（オプション）: `t`（既定。レベル 1 をインデントなしにする）、整数 N（レベル N までをインデントなしにする）、`nil`（なし）

`:title` の `%s` は見出しの文字列、`%l` はレベル、`%n` は見出しから次の見出しまでの未完了のタスク数（完了・廃止以外）である。未完了のタスク数は、`:count-format` が `nil` でなく、`:title` に `%n` があるか、`:face-rules` または `:count-face-rules` があるときだけ数える。`:face-rules` と `:count-face-rules` は、この数で評価する。


#### `search-simple`（シンプル検索）

DSL パターンマッチ。DSL パターン文字列でフィルタ条件を記述。詳細は「13.5 DSL 構文」を参照

| プロパティ | 必須/オプション | 説明               |
| ---------- | --------------- | ------------------ |
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
 :pattern "and:open,priority"
 :count-format t
 :nest 1)
```


#### `search-lambda`（ラムダ検索）

直接 predicate 関数を指定。lambda 関数は引数なしで現在の行で評価され、t を返すと表示、nil を返すと非表示。

| プロパティ | 必須/オプション | 説明        |
| ---------- | --------------- | ----------- |
| `:pattern` | 必須            | lambda 関数 |

`.altodo-locals.el` に書いた lambda は、既定では実行しない（`altodo-locals-code-policy`。詳細は `doc/design.md` の 4.5）。`altodo-default-filter-patterns` に書いた lambda は、常に実行する。

**例**:

```elisp
;; 期限が今日で且つ優先度フラグ付きタスク
(:title "Due Today + Priority - %n"
 :type search-lambda
 :pattern (lambda ()
            (and (altodo--due-date-matches-p 'today)
                 (altodo--line-has-priority-p)))
 :count-format t
 :nest 1)
```

**lambda 関数の要件**:
- 引数なし
- 現在の行で評価
- 返り値: `t`（表示）または `nil`（非表示）


#### `calendar`（月のカレンダー）

サイドバーに月のカレンダーを表示する。描画は、別ファイルのライブラリ `altodo-calendar.el` の `altodo-calendar-insert` が行い、altodo 側は、日ごとの face とボタン（`:day-function`）を渡す。期日と開始日のあるタスクの数に応じて日のセルの face が変わり、タスクのある日はボタンになって、その日のフィルタを適用する。

| プロパティ         | 必須/オプション | 説明                                                         |
| ------------------ | --------------- | ------------------------------------------------------------ |
| `:title`           | オプション      | カレンダーの上に表示する見出し。空文字列なら表示しない       |
| `:nest`            | オプション      | インデントレベル                                             |
| `:calendar-target` | オプション      | 対象。`due`（期日）、`start`（開始日）、`both`（両方。既定） |
| `:count-done`      | オプション      | `t` で完了・廃止のタスクも数える（既定は数えない）           |

- 日ごとの種類の決定: 対象の種類のタスクがある日だけがボタンになる。期日と開始日の両方がある日は、`altodo-calendar-priority`（`due` または `start`。既定 `due`）の種類で、face とフィルタ（`due-date:DATE` または `start-date:DATE`）を決める。片方だけがある日は、その種類
- 1 行目の `<` と `>` で前の月と次の月へ移り、月の名前のボタンで今月に戻る。`altodo-calendar-show-nav` を `nil` にすると、`<` と `>` を表示しない。サイドバーでは、`}`（次の月）、`{`（前の月）、`.`（今月）でも移れる
- 週の開始日は `altodo-week-start-day`。曜日の名前、月の名前、見出しの書式、祝日の関数は、`altodo-calendar` グループのオプションで変更する（`altodo-calendar-day-names`、`-day-name-faces`、`-month-names`、`-title-format`、`-holiday-function`）。全ての列の幅は、最も幅の広い曜日の名前（2 桁未満なら 2 桁）に合わせる
- 幅は、列の幅の 7 倍と区切りの 6 桁（既定は 20 桁）とインデントが要る。サイドバーの窓がそれより狭いときは、カレンダーの代わりに注記を表示する
- 存在しない日付（`2026-02-30` など）を持つタスクは数えない
- face（優先順位の高い順）: 絞り込み中の日（`altodo-calendar-selected-face`）、期限超過（`altodo-calendar-overdue-face`。期限が過ぎた未完了の期日に、太字と下線を重ねる）、期日が `altodo-calendar-heavy-count` 件以上（`altodo-calendar-due-heavy-face`）、期日あり（`altodo-calendar-due-face`）、開始日あり（`altodo-calendar-start-face`）、今日（`altodo-calendar-today-face`）、祝日（`altodo-calendar-holiday-face`）、日曜日（`altodo-calendar-sunday-face`）、土曜日（`altodo-calendar-saturday-face`）、通常の日（`altodo-calendar-day-face`）。見出しは `altodo-calendar-header-face`、`<` と `>` は `altodo-calendar-nav-face`、曜日の名前は `altodo-calendar-day-name-faces`（既定は `altodo-calendar-weekday-face`、日曜日と土曜日は各曜日の face）

**例**:

```elisp
(:title "" :type calendar :nest 1)
(:title "Due" :type calendar :calendar-target due :nest 1)
```


##### ライブラリ altodo-calendar

`altodo-calendar.el` は `calendar` だけに依存し、altodo の関数を使わない。主な関数は `(altodo-calendar-insert MONTH YEAR &rest OPTIONS)` で、オプションは `:indent`、`:week-start`、`:today`、`:day-function`、`:nav-function`、`:show-nav` である。`:day-function` は日付 `(MONTH DAY YEAR)` を受けて、`nil` または `(:faces FACES :action FUNCTION :properties PLIST :help TEXT)` を返す。`:action` があれば、その日はボタンになる。日のセルには、テキストプロパティ `altodo-calendar-date` が付く。

祝日の関数 `altodo-calendar-japanese-holiday` は、国民の祝日に関する法律（1948 年施行）に従う。成人の日、海の日、敬老の日、スポーツの日の月曜日への移動、2019 年の即位に伴う休日、2020 年と 2021 年の東京オリンピックに伴う移動、振替休日（2007 年以降は次の祝日でない日）、国民の休日（前日と翌日が祝日の日）を扱う。春分の日と秋分の日は、近似式で 1980〜2099 年だけを計算する（内閣府は、毎年 2 月に国立天文台が翌年の日を公表すると説明している）。


#### `agenda`（日ごとの一覧）

今日から数日分を、1 日 1 行で表示する。各行に、期日（D）と開始日（S）のあるタスクの数を示す。タスクのある行は、ボタンになり、その日のフィルタを適用する（期日と開始日の両方がある日は、`altodo-calendar-priority` の種類だけ）。

| プロパティ         | 必須/オプション | 説明                                                                   |
| ------------------ | --------------- | ---------------------------------------------------------------------- |
| `:title`           | オプション      | 一覧の上に表示する見出し                                               |
| `:nest`            | オプション      | インデントレベル                                                       |
| `:days`            | オプション      | 表示する日数（既定 7）                                                 |
| `:calendar-target` | オプション      | `due`、`start`、`both`（既定）                                         |
| `:count-done`      | オプション      | `t` で完了・廃止のタスクも数える                                       |
| `:agenda-overdue`  | オプション      | `nil` で、期限超過の行を表示しない（既定は、期限超過があれば表示する） |
| `:date-format`     | オプション      | 日付の書式。`altodo`（既定）、`done-tag`、または書式の文字列           |
| `:show-weekday`    | オプション      | `nil` で、日付の後ろの曜日を表示しない（既定 `t`。名前は下記）         |
| `:today-label`     | オプション      | 今日の行のラベル（既定 `"Today"`）                                     |
| `:tomorrow-label`  | オプション      | 明日の行のラベル（既定 `"Tomorrow"`）                                  |
| `:overdue-label`   | オプション      | 期限超過の行のラベル（既定 `"Overdue"`）                               |
| `:label-newline`   | オプション      | `t` で、ラベルを 1 行にし、日付と件数を次の行にする（既定 `nil`）      |

```
Overdue  1
Today    2026-03-10 Tue D2
Tomorrow 2026-03-11 Wed
         2026-03-12 Thu D1 S1
```

`:label-newline t` のとき（日付は `:date-format "%m/%d"`）:

```
Overdue
  1
Today
  03/10 Tue D2
Tomorrow
  03/11 Wed
  03/12 Thu D1 S1
```

- 先頭の「Overdue」の行は、期日が今日より前で未完了のタスクの数を示し、`due-date:overdue` のフィルタを適用する（対象に期日を含むとき）
- 曜日の名前: `altodo-calendar-day-names` が既定値と等しいときは、`calendar-day-abbrev-array`（Emacs の言語の略称。`Tue` など）。既定値から変更したときは、その名前を使い、カレンダーと一覧の表記を揃える。既定と同じ値を明示的に設定した場合も、略称になる
- 日付の書式（`:date-format`）: `altodo` は `altodo-date-format`（`nil` なら `%Y-%m-%d`）、`done-tag` は `altodo-done-tag-datetime-format`（`nil` なら日付だけの `%Y-%m-%d`）に従う。文字列は `format-time-string` の書式で、`%a` を書けば曜日も出せる（この場合は `:show-weekday nil` にする）。曜日は `calendar-day-abbrev-array` の名前である
- ラベルの列は、同じ行に置くときに限り、使うラベルのうち最も幅の広いものに揃える。ラベルが空の日は、列が空白になる（全てのラベルが空なら、列はない）。設定は全て、エントリのプロパティで行う（`altodo-filter-patterns`。専用のオプション変数はない）
- face: 期限超過の行は `altodo-agenda-overdue-face`、今日の行は `altodo-agenda-today-face`、タスクのない行は `altodo-agenda-empty-face`、その他の行は `altodo-agenda-date-face`。件数の部分は、さらに `altodo-agenda-count-face`

**例**:

```elisp
(:title "Next 7 days" :type agenda :days 7 :nest 1)
(:title "今後" :type agenda :days 5 :date-format "%m/%d" :today-label "今日"
 :tomorrow-label "明日" :overdue-label "期限超過" :label-newline t :nest 1)
```


#### `separator`（区切り線）

視覚的な区切り

| プロパティ | 必須/オプション | 説明                   |
| ---------- | --------------- | ---------------------- |
| `:pattern` | オプション      | 区切り線に表示する文字 |


#### `command`（コマンド実行）

クリック時に指定したコマンドを実行

| プロパティ | 必須/オプション | 説明         |
| ---------- | --------------- | ------------ |
| `:command` | 必須            | 実行する関数 |


**例**:

```elisp
;; フィルタクリア
(:title "[Clear Filter]" :type command :command altodo-filter-clear :nest 0)

;; ユーザーが定義したコマンドを実行
(:title "[Archive Done]" :type command :command altodo-archive-done-tasks :nest 0)
```

**`:command` に指定できるもの**:
- インタラクティブに呼び出せる関数名（シンボル）
- クリック時にその関数が source buffer で実行される


### 13.5 DSL パターン仕様

#### 13.5.1 パターンの書式

パターンは文字列であり、次の 3 種類がある。

- 単純パターン: 名前のみ。例: `"done"`
- 引数付きパターン: `種類:引数`。例: `"tag:java"`
- 論理演算パターン: `演算:パターン,パターン,...`。例: `"and:open,priority"`

書式の誤りや未知の種類のパターンは、どの行にも一致しない。


#### 13.5.2 単純パターン

| パターン                  | 説明                                                                    |
| ------------------------- | ----------------------------------------------------------------------- |
| `"done"`                  | 完了タスク                                                              |
| `"progress"`              | 進行中タスク                                                            |
| `"waiting"`               | 待機タスク                                                              |
| `"open"`                  | オープンタスク                                                          |
| `"cancelled"`             | 廃止タスク                                                              |
| `"priority"`              | 優先度フラグ付き                                                        |
| `"star"`                  | スターフラグ付き                                                        |
| `"has-multiline-comment"` | 複数行コメント付き                                                      |
| `"task"`                  | タスク行                                                                |
| `"comment"`               | `///` 行                                                                |
| `"multiline-comment"`     | 複数行コメントの行                                                      |
| `"heading"`               | 見出し行（ATX 見出しと Setext 見出しの題。Setext の下線の行は含まない） |
| `"empty-line"`            | 空行（空白だけの行を含む）                                              |
| `"any-line"`              | 全ての行                                                                |


#### 13.5.3 引数付きパターン

| 種類                         | 書式                                | 説明                             |
| ---------------------------- | ----------------------------------- | -------------------------------- |
| `tag`                        | `tag:NAME`                          | 指定タグを持つ行                 |
| `person`                     | `person:NAME`                       | 指定担当者を持つ行               |
| `text`                       | `text:STRING`                       | 文字列を含む行                   |
| `regexp`                     | `regexp:REGEXP`                     | 正規表現にマッチする行           |
| `level`                      | `level:N`                           | ネストレベル N の行              |
| `heading`                    | `heading:REGEXP`                    | 見出しの範囲内のタスク行（下記） |
| `due-date`                   | `due-date:CONDITION`                | 期日で絞り込む                   |
| `start-date`                 | `start-date:CONDITION`              | 開始日で絞り込む                 |
| `tag-value`                  | `tag-value:KEY VALUE`               | タグの値で絞り込む               |
| `state-any`                  | `state-any:S1,S2,...`               | いずれかの状態の行               |
| `has-any-flag`               | `has-any-flag:F1,F2,...`            | いずれかのフラグを持つ行         |
| `has-any-tag`                | `has-any-tag:T1,T2,...`             | いずれかのタグを持つ行           |
| `has-all-tags`               | `has-all-tags:T1,T2,...`            | 全てのタグを持つ行               |
| `has-any-person`             | `has-any-person:P1,P2,...`          | いずれかの担当者を持つ行         |
| `parent-task-regexp`         | `parent-task-regexp:REGEXP`         | 親タスクが正規表現にマッチ       |
| `root-task-regexp`           | `root-task-regexp:REGEXP`           | ルート親タスクが正規表現にマッチ |
| `multiline-comment-contains` | `multiline-comment-contains:REGEXP` | 複数行コメントが正規表現にマッチ |

論理演算の引数は、カンマで分割される。そのため、カンマを含む引数は論理演算の中に書けない。

複数の値を取る `state-any`、`has-any-flag`、`has-any-tag`、`has-all-tags`、`has-any-person` は、値をカンマまたは縦棒（`|`）で区切る。論理演算の中では、カンマが演算の引数の区切りになるため、縦棒を使う。例: `and:open,has-any-tag:a|b`。`state-any` の値は `done`、`progress`、`waiting`、`open`、`cancelled`、`has-any-flag` の値は `star`、`priority` である。未知の値は、メッセージを表示し、どの行にも一致しないパターンになる。


`heading:REGEXP` の `REGEXP` は正規表現で、見出しの文字列の中から探す（先頭固定ではない）。`^Work$` のように `^` と `$` で固定すると、`Workshop` を除ける。`C++` のように特殊文字を含む見出しは、`C\+\+` と書く。一致した見出しすべてが対象で、見出しの範囲には、子の見出しの下の行を含む。正規表現が不正なときは、パターンのコンパイルでエラーにする。


#### 13.5.4 日付条件（due-date / start-date）

期日（`-> DATE`）と開始日（`DATE ->`）は、色付け、絞り込み、サイドバーのカレンダーと一覧、日付の入力で、同じ規則で認識する。

- 対象の行: タスク行、`///` コメント行、見出し。複数行コメント、通常の文章、コードブロックの中では、日付として扱わない
- 空白: 日付の前後、矢印の前後に空白が要る（行頭と行末は空白と同じ）。`a->2026-01-01` や `2026-01-01x ->` は日付ではない

`due-date:CONDITION` の `CONDITION` は次のとおり。日付 `DATE` の書式は `altodo-date-format` に従う。

| 条件                | 説明              | 例                                       |
| ------------------- | ----------------- | ---------------------------------------- |
| `overdue`           | 期日超過          | `due-date:overdue`                       |
| `today`             | 本日期日          | `due-date:today`                         |
| `tomorrow`          | 明日期日          | `due-date:tomorrow`                      |
| `this-week`         | 今週の期日        | `due-date:this-week`                     |
| `this-month`        | 今月の期日        | `due-date:this-month`                    |
| `before:DATE`       | DATE より前       | `due-date:before:2024-12-31`             |
| `after:DATE`        | DATE より後       | `due-date:after:2024-01-01`              |
| `between:START:END` | 範囲内            | `due-date:between:2024-01-01:2024-12-31` |
| `within:N`          | 本日から N 日以内 | `due-date:within:7`                      |
| `past:N`            | N 日以上前        | `due-date:past:3`                        |
| `DATE`              | 指定日に一致      | `due-date:2024-06-30`                    |

`start-date:CONDITION` は、`overdue` の代わりに `passed`（開始日が過去）、`not-yet`（開始日が未来）を使う。それ以外の条件は同じである。

存在しない日付（`2026-02-30` など）を持つ行は、どの日付条件にも一致しない。条件に存在しない日付を書くと、エラーになる。相対的な条件（`today`、`overdue` など）は、`altodo-date-format` の設定によらず、実際の日付で判定する。


#### 13.5.5 論理演算

| 演算  | 書式            | 説明                                   |
| ----- | --------------- | -------------------------------------- |
| `and` | `and:P1,P2,...` | 全てにマッチ                           |
| `or`  | `or:P1,P2,...`  | いずれかにマッチ                       |
| `not` | `not:P`         | マッチしない（先頭のパターンのみ使う） |

- `not` は、タスク行以外の行（見出し、通常の文）にも作用する
- 入れ子は 1 段までである。同じ階層の演算子が複数ある場合のみ分割できる。例: `or:and:open,priority,and:progress,star` は「オープンかつ優先度付き」または「進行中かつスター付き」を表す。2 段以上の入れ子は未対応である


#### 13.5.6 タグ値条件（tag-value）

| 書式                    | 説明                                  |
| ----------------------- | ------------------------------------- |
| `tag-value:KEY VALUE`   | 完全一致                              |
| `tag-value:KEY (V1 V2)` | いずれかに一致（OR）                  |
| `tag-value:KEY (OP N)`  | 数値比較（`>`、`<`、`=`、`>=`、`<=`） |

例: `tag-value:priority (> 5)`


### 13.6 face-rules および count-face-rules 仕様

`:face-rules` と `:count-face-rules` でカウント数に基づく face を指定できる。

- `:face-rules`: フィルタ行の本文全体。`:count-format` が `nil` のときは評価しない
- `:count-face-rules`: フィルタ行のカウント部分 `%n` のみ。行全体には適用しない。この項目がないとき、`%n` には `:face-count`、それもなければ行全体の face が適用される

カウントの値は、タイトルの `%n` と同じである（11.3 節）。


```elisp
:face-rules ((>= 5 (:foreground "red" :weight bold))
             (>= 3 (:foreground "orange"))
             (>= 1 (:foreground "green"))
             (= 0 (:foreground "gray")))
```

**書式**: `(条件 N face-spec)`

**条件**:
- `>= N` - N 以上
- `> N` - N より大きい
- `= N` - N と等しい
- `<= N` - N 以下
- `/= N` - N と等しくない
- `< N` - N より小さい

規則は上から順に評価し、最初にマッチした規則の face を使う。マッチしない場合は、行全体では `:face`、`:face` もなければ種類ごとの既定の face を使う。カウント部分では、`:face-count`、それもなければ行全体の face を使う。

書式が不正な規則（条件が上の 6 つでない、N が数でない、要素が 3 つでない）は、その規則だけを無視し、規則ごとに 1 回、メッセージ `altodo: ignored the invalid face rule ...` を表示する。規則のリストがリストでない場合も、同様に無視する。サイドバーの描画は失敗しない。

__face-spec__ は以下の通り指定できる。`:face`、`:face-count` の値も同じ形である。

- face 名（`error`）
- face 名のリスト（`(bold error)`）
- plist（`(:foreground "red" :weight bold)`）
- defface 形式（`((t (:foreground "red")))`）。`t` の節の属性を使う

解釈できない値（属性の数が奇数の plist など）は、指定がないものとして扱う。


### 13.7 設定例

```elisp
;; .altodo-locals.el
(
 (altodo-filter-patterns .
  (
   ;; ステータスグループ
   (:title "Status" :type group-header :nest 0)
   (:title "Open [ ] - %n" :type search-simple :pattern "open" :count-format t :nest 1
           :count-exclude-others t :display-context 'all)
   (:title "In Progress [@] - %n" :type search-simple :pattern "progress" :count-format t :nest 1
           :count-exclude-others t :display-context 'all)
   (:title "Waiting [w] - %n" :type search-simple :pattern "waiting" :count-format t :nest 1
           :count-exclude-others t :display-context 'all)
   (:title "Done [x] - %n" :type search-simple :pattern "done" :count-format t :nest 1
           :count-exclude-others t :display-context 'all)
   (:title "Cancelled [~] - %n" :type search-simple :pattern "cancelled" :count-format t :nest 1
           :count-exclude-others t :display-context 'all)
   
   ;; フラググループ
   (:title "Flags" :type group-header :nest 0)
   (:title "Priority (!) - %n" :type search-simple :pattern "priority" :count-format t :nest 1
           :count-exclude-others t :face-rules ((>= 5 error) (>= 1 warning)))
   (:title "Star (+) - %n" :type search-simple :pattern "star" :count-format t :nest 1
           :count-exclude-others t)
   
   ;; 期限グループ
   (:title "Due" :type group-header :nest 0)
   (:title "Open and Over Due - %n" :type search-simple
           :pattern "and:due-date:overdue,not:state-any:done|cancelled"
           :count-format t :nest 1
           :count-exclude-others t
           :face-rules ((>= 1 error)))
   (:title "Open and Due Today - %n" :type search-simple
           :pattern "and:due-date:today,not:state-any:done|cancelled"
           :count-format t :nest 1
           :count-exclude-others t
           :face-rules ((>= 1 error)))
   
   ;; タググループ
   (:title "Tags" :type group-header :nest 0)
   (:title "#%s - %n" :type dynamic :dynamic-type "tag" :count-format t :limit 5 :nest 1
           :exclude-tag ("id" "dep" "done") :tag-mode "name-only"
           :count-exclude-others t :display-context 'all)
   
   ;; 人グループ
   (:title "People" :type group-header :nest 0)
   (:title "@%s - %n" :type dynamic :dynamic-type "person" :count-format t :limit 5 :nest 1
           :count-exclude-others t :display-context 'all)

   ;; 見出しグループ
   (:title "Headings" :type group-header :nest 0)
   (:title "%s - %n" :type dynamic :dynamic-type "heading" :count-format t :nest 1)
   
   ;; 複合条件の例
   (:title "Open + Priority - %n"
           :type search-simple
           :pattern "and:open,priority"
           :count-format t :nest 1
           :count-exclude-others t
           :face-rules ((>= 3 warning)))
   
   ;; 区切り線
   (:title "" :type separator :pattern "─" :nest 0)
   
   ;; コマンド
   (:title "[Clear Filter]" :type command :command altodo-filter-clear :nest 0)
   ))
)
```
