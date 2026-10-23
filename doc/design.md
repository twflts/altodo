# altodo-mode 設計仕様書

## 1. 概要

altodo-mode は Emacs 用のタスク管理メジャーモードである。 __Emacs Markdown Mode__ https://github.com/jrblevin/markdown-mode の独自拡張とし、altodo ファイルを操作し、face 適用やフィルタリングなどの機能でタスクを閲覧・操作しやすくする。


## 2. アーキテクチャ

### 全体構成

altodo.el は  __Emacs Markdown Mode__ https://github.com/jrblevin/markdown-mode の独自拡張として機能する。そして、一般的な Emacs Major-mode の構成に従って実装する。

- __Constants and Variables__ - 定数・変数定義
- __Customizable Variables__ - カスタマイズ可能変数
- __Font Lock Keywords__ - シンタックスハイライト定義
- __Keymap__ - キーバインド定義
- __Mode Definition__ - メジャーモード定義
- __Interactive Commands__ - ユーザーコマンド
- __Task Management Functions__ - タスク操作関数
- __Parsing Functions__ - テキスト解析関数
- __Utility Functions__ - 補助関数


### 実装方針

#### プレーンテキスト重視

- データ構造体は使用せず、バッファ内容を直接操作
- 行ごとの正規表現マッチングで機能を実行
- 必要時のみテキスト解析を行い、軽量性を保持
- プレーンテキストファイルとしての利点を最大化


#### シンプルな実装

- Emacs 標準機能を最大限活用
- キャッシュは、再計算の費用が大きい結果（1 回の描画の間の件数、見出しの範囲、設定ファイルの内容）に限る。非同期処理は、自動移動のタイマーだけである
- font-lock の標準機能でシンタックスハイライト
- 必要に応じて段階的に最適化を追加


## 3. 仕様定義

### 3.1 定数定義

#### タスク状態文字

- `altodo-state-done`: `"x"` - 完了タスク
- `altodo-state-progress`: `"@"` - 進行中タスク
- `altodo-state-waiting`: `"w"` - 待機タスク
- `altodo-state-cancelled`: `"~"` - 廃止タスク
- `altodo-state-open`: `" "` - オープンタスク


#### フラグ文字

- `altodo-flag-star`: `"+"` - スターフラグ
- `altodo-flag-priority`: `"!"` - 優先度フラグ


#### コメント・タグ関連

- `altodo-comment-marker`: `"///"` - コメントマーカー
- `altodo-special-tag-names`: `'("id" "group-start" "group-due" "done")` - 特殊タグ名リスト
  - 注: `"dep"` は `altodo--dep-tag-matcher` で別途処理される


#### 正規表現定義

実装が定義する定数は次のとおり。

- `altodo-task-regex`: タスク行。値は `^\([ ]*\)\[\([x@w~ ]?\)\]\(.*\)$`。グループ 1 は行頭のインデント、グループ 2 は状態文字、グループ 3 は状態マークより後ろの文字列
- `altodo-comment-regex`: 一行コメント行。値は `^\([ \t]*\)/// \(.*\)$`
- `altodo-tag-with-value-regex`: 値付きタグ。値は `\(?:^\|[ \t]\)\(#[a-zA-Z0-9_-]+\):\("[^"]*"\|[^[:space:]]+\)`。値はダブルクオートで囲める
- `altodo-tag-without-value-regex`: 値なしタグ。値は `\(?:^\|[ \t]\)\(#[a-zA-Z0-9_-]+\)\b`
- `altodo-special-tag-regex`: 特殊タグ。`altodo-special-tag-names` から生成する

日付の正規表現は定数ではない。`altodo-date-format`（既定値 `nil` は `YYYY-MM-DD`）から、実行時に `altodo--date-regex-info` が生成する。


#### タスク状態文字リスト

`altodo-task-state-chars` は、完了・進行中・待機・廃止の状態文字を連結した文字列 `"x@w~"` である。


### 3.2 カスタマイズ変数

| 変数名                                         | デフォルト     | 説明                                               |
| ---------------------------------------------- | -------------- | -------------------------------------------------- |
| `altodo-indent-size`                           | `4`            | インデントサイズ                                   |
| `altodo-enable-markdown-in-multiline-comments` | `t`            | 複数行コメント内で Markdown 書式を有効化           |
| `altodo-auto-save`                             | `nil`          | タスク状態の変更時にファイルを自動保存             |
| `altodo-skk-wrap-newline`                      | `t`            | SKK 入力メソッドとの互換のため改行をラップ         |
| `altodo-done-tag-datetime-format`              | `nil`          | `#done` の時刻書式（`nil` は ISO 8601 の時差付き） |
| `altodo-use-local-timezone`                    | `t`            | `#done` の時刻にローカルタイムゾーンを使用         |
| `altodo-insert-id-format`                      | `'tiny-random` | `#id` の ID 形式                                   |
| `altodo-date-format`                           | `nil`          | 日付書式（`nil` は `YYYY-MM-DD`）                  |
| `altodo-week-start-day`                        | `0`            | 週の開始日（0 は日曜日、1 は月曜日）               |
| `altodo-done-file-prefix`                      | `"_done"`      | done ファイル名に付ける文字列                      |
| `altodo-move-unit`                             | `'subtree`     | 移動の単位（`subtree` または `line`）              |
| `altodo-auto-move-interval`                    | `3600`         | 自動移動の実行間隔（秒。正の数）                   |
| `altodo-move-after-days`                       | `nil`          | `#done` から移動までの日数（`nil` はすぐに移動）   |
| `altodo-auto-save-after-move`                  | `nil`          | 移動後に元ファイルを自動保存                       |
| `altodo-auto-move-skip-done-files`             | `t`            | 自動移動で done ファイルを対象外にする             |
| `altodo-show-auto-move-in-mode-line`           | `t`            | モードラインに自動移動の状態を表示                 |

サイドバーの変数は、`README.md` の「設定」を参照する。


### 3.3 Face 定義

主な face を示す。全ての face（日付の状態、`@person`、サイドバー、カレンダー、一覧を含む）は、`M-x customize-group RET altodo RET` で確認できる。


#### タスク状態 Face

| Face                         | 説明             |
| ---------------------------- | ---------------- |
| `altodo-task-open-face`      | オープンタスク用 |
| `altodo-task-done-face`      | 完了タスク用     |
| `altodo--task-progress-face` | 進行中タスク用   |
| `altodo-task-waiting-face`   | 待機タスク用     |
| `altodo-task-cancelled-face` | 廃止タスク用     |


#### タスク本文 Face

| Face                              | 説明                                   |
| --------------------------------- | -------------------------------------- |
| `altodo-task-open-text-face`      | オープンタスク本文用（ライトグリーン） |
| `altodo-task-done-text-face`      | 完了タスク本文用（斜線）               |
| `altodo--task-progress-text-face` | 進行中タスク本文用（マゼンタ）         |
| `altodo-task-waiting-text-face`   | 待機タスク本文用（ライトグレイ）       |
| `altodo-task-cancelled-text-face` | 廃止タスク本文用（斜線）               |


#### コメント Face

| Face                            | 説明                       |
| ------------------------------- | -------------------------- |
| `altodo-comment-face`           | 1 行コメント用（赤色）     |
| `altodo-multiline-comment-face` | 複数行コメント用（グレー） |


#### フラグ Face

| Face                         | 説明                          |
| ---------------------------- | ----------------------------- |
| `altodo-flag-star-face`      | スターフラグ用（金色太字）    |
| `altodo-flag-priority1-face` | 優先度 1 フラグ用（赤色）     |
| `altodo-flag-priority2-face` | 優先度 2 フラグ用（赤色太字） |
| `altodo-flag-priority3-face` | 優先度 3 フラグ用（赤色太字） |


#### タグ・日付 Face

| Face                      | 説明                       |
| ------------------------- | -------------------------- |
| `altodo-tag-face`         | 一般タグ用（紫色）         |
| `altodo-tag-value-face`   | タグ値用（濃紫太字）       |
| `altodo-special-tag-face` | 特殊タグ用（マゼンタ太字） |
| `altodo-date-face`        | 日付用（青色）             |


#### 依存関係 Face

| Face                           | 説明                         |
| ------------------------------ | ---------------------------- |
| `altodo-dep-blocked-text-face` | 依存関係ブロック中用（赤色） |
| `altodo-dep-blocked-tag-face`  | 依存タグブロック中用（赤色） |
| `altodo-dep-ready-tag-face`    | 依存タグ実施可能用（緑色）   |
| `altodo-dep-error-tag-face`    | 依存関係エラー用（赤色太字） |


### 3.4 キーマップ

キーは、有効な行の種類で 4 つに分かれる。有効でない行では、各キーは `markdown-mode` の同じキーの割り当てを呼び出す（`altodo--on-line`）。


#### 全ての行

| キー          | 関数名                   | 機能                                                   |
| ------------- | ------------------------ | ------------------------------------------------------ |
| `TAB`         | `altodo-indent-line`     | サブタスク化・解除（行の種類に応じて処理を切り替える） |
| `RET`         | `altodo-enter`           | 文脈に応じた改行処理                                   |
| `<backtab>`   | `outline-cycle`          | アウトラインの循環                                     |
| `C-c C-v f c` | `altodo-filter-clear`    | フィルタクリア                                         |
| `C-c C-v s t` | `altodo-sidebar-toggle`  | サイドバーの表示切替                                   |
| `C-c C-v s r` | `altodo-sidebar-refresh` | サイドバーの更新                                       |


#### タスク行

| キー        | 関数名                            | 機能                             |
| ----------- | --------------------------------- | -------------------------------- |
| `C-c C-x`   | `altodo-toggle-task-state`        | オープン ↔ 完了のトグル         |
| `C-c C-t o` | `altodo-set-task-open`            | オープンに設定                   |
| `C-c C-t x` | `altodo-set-task-done`            | 完了に設定                       |
| `C-c C-t @` | `altodo-set-task-progress`        | 進行中に設定                     |
| `C-c C-t w` | `altodo-set-task-waiting`         | 待機に設定                       |
| `C-c C-t ~` | `altodo-set-task-cancelled`       | 廃止に設定                       |
| `C-c C-t d` | `altodo-move-done-tasks-at-point` | 終了タスクを done ファイルへ移動 |
| `C-c C-t D` | `altodo-move-done-task-alone`     | 終了タスクの行だけを移動         |


#### タスク行・1 行コメント行

| キー                  | 関数名                              | 機能                     |
| --------------------- | ----------------------------------- | ------------------------ |
| `C-c C-a`             | `altodo-add-task`                   | タスクの追加             |
| `M-RET`               | `altodo-add-subtask`                | サブタスクの追加         |
| `C-c C-m`             | `altodo-start-multiline-comment`    | 複数行コメントの開始     |
| `C-c C-s`             | `altodo-toggle-star-flag`           | スターフラグのトグル     |
| `C-c C-f 1`、`2`、`3` | `altodo-set-priority-1`、`-2`、`-3` | 優先度の設定             |
| `C-c C-e d`           | `altodo-select-due-calendar`        | カレンダーで期日を選ぶ   |
| `C-c C-e s`           | `altodo-select-start-calendar`      | カレンダーで開始日を選ぶ |
| `C-c C-i`             | `altodo-insert-id`                  | `#id` の挿入             |
| `C-c C-j`             | `altodo-goto-dependency`            | 依存先タスクへジャンプ   |


#### タスク行・1 行コメント行・複数行コメント行

| キー                    | 関数名                                             | 機能             |
| ----------------------- | -------------------------------------------------- | ---------------- |
| `M-<right>`、`M-<left>` | `altodo-indent-increase`、`altodo-indent-decrease` | インデントの増減 |

`altodo-toggle-comment`（タスク ↔ コメントのトグル）は、キーに割り当てていない。`M-x` で実行する。


## 4. 設定ファイル（.altodo-locals.el）

altodo はバッファローカルな設定を `.altodo-locals.el` ファイルで管理する。


### 4.1 ファイル配置

altodo ファイルと同じディレクトリに `.altodo-locals.el` を配置する。


### 4.2 フォーマット

alist 形式で複数の変数を指定可能：

```elisp
(
 ;; フィルタパターン
 (altodo-filter-patterns .
  (
   (:title "Status" :type group-header :nest 0)
   (:title "Open [ ] - %n" :type search-simple :pattern "open" :count-format t :nest 1)
   (:title "Done [x] - %n" :type search-simple :pattern "done" :count-format t :nest 1)
   (:title "@Person - %n" :type dynamic :dynamic-type person :count-format t :nest 1)
   (:title "#Tag - %n" :type dynamic :dynamic-type tag :count-format t :nest 1)
   (:title "Priority - %n" :type search-simple :pattern "priority" :count-format t :nest 1
    :face-rules ((>= 5 error)
                 (>= 1 warning)))
   (:title "" :type separator :nest 0)
   (:title "[Clear]" :type command :command altodo-filter-clear :nest 0)
   ))
 
 ;; サイドバー用 face 定義
 (altodo-sidebar-face-alist .
  ((done-face . ((t (:foreground "green"))))
   (error-face . ((t (:foreground "red"))))
   (warning-face . ((t (:foreground "orange"))))))
 )
```


### 4.3 設定可能な変数

`.altodo-locals.el` から読む変数は、次の 5 つである（`altodo--get-locals-value`）。他の変数を書いても、使わない。

| 変数名                      | 説明                                        |
| --------------------------- | ------------------------------------------- |
| `altodo-filter-patterns`    | サイドバーフィルタパターンリスト            |
| `altodo-sidebar-face-alist` | サイドバー用 face 定義                      |
| `altodo-sidebar-position`   | サイドバー表示位置（`left` または `right`） |
| `altodo-sidebar-size`       | サイドバー幅（ウィンドウ幅に対する比率）    |
| `altodo-sidebar-indent`     | サイドバーインデント幅                      |

**例**:

```elisp
(
 (altodo-filter-patterns . (...))
 (altodo-sidebar-face-alist . (...))
 (altodo-sidebar-position . right)
 (altodo-sidebar-size . 0.3)
 )
```


### 4.4 デフォルト設定

ファイルが存在しない場合は以下のデフォルト値を使用：

- `altodo-filter-patterns` → `altodo-default-filter-patterns` 変数
- サイドバー face → デフォルト face


#### 設定ファイルの異常

- 構文エラー、または内容が alist でない場合は、警告を表示し、設定ファイルがないときと同じく既定の設定を使う
- `altodo-filter-patterns` のエントリのうち、`:title` が文字列の plist でないものは、警告を表示し、そのエントリだけを使わない
- 警告は、同じ内容につき、ファイルを更新するごとに 1 回だけ表示する


### 4.5 設定ファイル内のコードの実行

`.altodo-locals.el` に書かれた次のコードは、`altodo-locals-code-policy` の値に従って実行する。

- `:type search-lambda` の `:pattern`（lambda）と `:count-pattern-lambda`
- `:command` に指定した、このパッケージ以外（名前が altodo- で始まらない）のコマンド

| 値        | 動作                                                                                           |
| --------- | ---------------------------------------------------------------------------------------------- |
| `deny`    | 既定。実行しない                                                                               |
| `confirm` | 設定ファイルの SHA-256 が `altodo-trusted-locals` にあれば実行する。なければ、選択時に確認する |
| `allow`   | 常に実行する                                                                                   |

- 実行しない項目も、サイドバーに表示する。件数は `?` と表示し、`:face-rules` は評価しない。項目を選択すると、実行しない旨のメッセージを表示する（`confirm` では確認する）
- `confirm` で承認すると、ファイルの絶対パスと SHA-256 を `altodo-trusted-locals` に保存する（`customize-save-variable`）。ファイルの内容が変わると、承認は無効になる
- `altodo-default-filter-patterns`（Emacs の設定）に書いたコードは、方針の対象外である。設定ファイル由来の項目だけが対象になる
- `:face-rules` の演算子は、`<`、`>`、`<=`、`>=`、`=`、`/=` だけを評価する。他の演算子の規則は無視する


## 5. 機能仕様

### 5.1 タスク状態管理

5 つのタスク状態：

| 状態     | マーク | 説明                           |
| -------- | ------ | ------------------------------ |
| オープン | `[ ]`  | 実行前タスク                   |
| 進行中   | `[@]`  | 現在、進行・対応中のタスク     |
| 待機     | `[w]`  | 保留（待ち状態）のタスク       |
| 完了     | `[x]`  | 完了（実行後）タスク           |
| 廃止     | `[~]`  | 完了する前に廃止となったタスク |


### 5.2 フラグ・優先度

#### スターフラグ

- フラグ: `+`
- 用途: 特に重要度の高いタスク
- 例: `[ ] + スターフラグの付いたタスク`


#### フラグを付与できる行

- フラグは、タスク行のタスク状態マークの直後、および 1 行コメント行の `///` の直後に置く
- フラグの後に半角スペースが必要


#### スターと優先度の併用

- 併用できる。順序は任意で、それぞれ 1 行に 1 つまでである
- コマンド（`altodo-set-priority-1`〜`3`、`altodo-toggle-star-flag`）は、スター、優先度の順に書く。もう一方のフラグは保持する
- 解析は `altodo--parse-flags` が行う


#### 優先度フラグ

- フラグ: `!`, `!!`, `!!!`
- 用途: 重要度に応じたタスクの優先度付け
- 例: `[ ] !!! 最も優先度の高いタスク`


### 5.3 コメント

#### 1 行コメント

- マーカー: `///`
- 用途: タスクの一部ではない、分離した注記（補足、レビューメモ）
- 例: `/// これは一行コメント行`
- フラグ（`+`、`!`）を付与できる。例: `/// ! 重要な注記`


#### 複数行コメント

- 付随先: 直前のタスク行または 1 行コメント行
- 用途: タスクの説明など、タスクの一部
- 例: `[ ] タスク` の次の行 `    タスクの説明`


#### 複数行コメントの判定規則

仕様の詳細は `doc/altodo_spec.md` の 3.2.3 に従う。判定規則は次のとおり。

- 開始の行は、直前のタスク行・1 行コメント行のインデント + 4 スペースで始まる。例外はない
- 開始の行と同じインデントの行のうち、タスク行以外は全て本文である。Markdown のリスト、リンク、フェンス付きコードブロックを含む
- 続きの行は、前行の複数行コメントと同じインデントである。インデントを保った、スペースだけの行も本文である
- インデントが異なる行（浅い行と深い行）、および完全な空行（0 文字）で終了する。入れ子の Markdown リストのように、深いインデントの行は本文にならない
- タスク状態マークで始まる行は、常にタスク行である

判定は、バッファの行ごとに、正規表現と直前の行の状態で行う。インデント付きの行を Markdown のインデント付きコードブロックとして扱わない（6.1 節）。


### 5.4 タグ

#### 一般タグ

- 形式: `#tag`
- 例: `[ ] #home でタスクを行う`


#### 値付きタグ

- 形式: `#key:value`
- 例: `[ ] #work-by:john`


#### 特殊タグ

| タグ                | 説明                         |
| ------------------- | ---------------------------- |
| `#id:value`         | ユニーク識別子               |
| `#dep:value`        | 依存関係（参照先 ID を指定） |
| `#group-start:date` | グループのタスクの開始日     |
| `#group-due:date`   | グループのタスクの期日       |
| `#done:timestamp`   | タスクが完了・廃止された時刻 |
| `#seq-tasks`        | 子タスクを上から順に実行     |


#### @person タグ

- 形式: `@person`
- 用途: 担当者・場所の指定
- 例: `[ ] タスク @john に確認`


### 5.5 日付システム

#### 開始日・期限

- 開始日: `YYYY-MM-DD ->`
- 期限: `-> YYYY-MM-DD`
- 両方: `YYYY-MM-DD -> YYYY-MM-DD`


#### 日付の入力

次のコマンドで、カーソルのタスク行（または `///` 行）の日付を設定する。それ以外の行では `user-error` にする。

- `altodo-select-due-calendar`（`C-c C-e d`）、`altodo-select-start-calendar`（`C-c C-e s`）: `calendar` のウィンドウを開き、`RET` で日付を確定する。`q` で中止する。週の開始日は `altodo-week-start-day` に従い、カーソルは、行にある日付から始まる
- `altodo-input-due-date`、`altodo-input-start-date`: `calendar-read-date` で、ミニバッファに入力する
- 書式は `altodo-date-format` に従う。同じ種類の日付があれば置き換える。なければ、期日は `-> DATE`、開始日は `DATE ->` として行末に加える。他方の日付があるときは、矢印を共有する（`START -> DUE`）


#### 存在しない日付

`2026-02-30` のように存在しない日付は、日付として扱わない。`altodo--parse-date` が nil を返し、色付けは通常の日付の face になる。期日・開始日の条件にも一致しない。相対的な条件（`today`、`overdue` など）は、`altodo-date-format` の設定によらず、実際の日付で判定する。


#### 日付ベースの色付け

- 開始日超過: グレー
- 期限超過: 赤色太字
- 期限当日: 赤色
- 期限緊急: 太字


### 5.6 依存関係管理

#### #id タグ

- 用途: タスクのユニーク識別
- 例: `[ ] タスク #id:20250101-0000`


#### #dep タグ

- 用途: 依存関係の指定
- 例: `[ ] 依存タスク #dep:20250101-0000`


#### ID と依存関係の異常

- `#id` の値の照合は、値の直後が空白または行末のときだけ一致とする。`#id:T1` は `#id:T1-2` に一致しない
- 同じ `#id` が複数あるときは、最初の一致だけを使う。2 個目以降は参照されず、エラーにならない
- 自分自身への `#dep` と、循環した `#dep` は「循環」になり、`altodo-dep-error-tag-face` で表示する
- 存在しない `#id` への `#dep` は、依存先がないものとして扱う（実施可能）


### 5.7 タスク移動機能

#### 手動移動

- コマンド: `altodo-move-done-tasks-at-point`
- キーバインド: `C-c C-t d`
- 対象: カーソルのタスクが完了（`[x]`）または廃止（`[~]`）のとき、そのタスクを移動する。子孫を含めるかは「移動の単位」で決まる


#### 自動移動

- タイマー方式（グローバルタイマー）
- 実行間隔: `altodo-auto-move-interval`（デフォルト: 3600 秒）
- 対象: すべての開いている altodo バッファ


#### done ファイル

- 命名規則: `[ファイル名]_done.altodo`
- prefix: `altodo-done-file-prefix` で設定可能


#### 移動の単位

- 移動の単位は、`altodo-move-unit`（`subtree` または `line`）で選ぶ。既定は `subtree` である
- `subtree`: 完了・廃止したタスクと、その子孫（子タスク、`///` 行、複数行コメント）を移動する。子孫に未完了のタスクがあるときは、移動しない。手動では `user-error` にし、一括・自動では飛ばす。一括移動と自動移動は、親のないタスクだけを対象にし、完了した子は、サブツリー全体が完了するまで移動しない。手動の移動は、親が未完了でも、その子のサブツリーを移動する。done ファイルには、根をインデント 0 に揃え、子孫の相対インデントを保って書く
- `line`: タスクの行と複数行コメントだけを移動する。子タスクは元のバッファに残り、完了した子は親から離れて移動する
- `altodo-move-done-task-alone`（`C-c C-t D`）は、`altodo-move-unit` によらず、`line` の単位で移動する
- `altodo-move-after-days` が数値 N のとき、一括移動と自動移動は、`#done` タグの日付が N 日以上前のタスクだけを移動する。手動の移動には適用しない。`#done` がない、または日付として読めないタスクは移動しない。`subtree` では、サブツリーの全てのタスクが条件を満たす必要がある。日付は、ISO 8601 の日付の部分、Unix 時間（秒）、`altodo-date-format` の日付を読む
- `#done` の日付は、書かれた時刻のタイムゾーンの日付であり、今日の日付はローカルタイムゾーンで数える。`altodo-use-local-timezone` が `nil`（UTC で記録）のときは、`#done` の日付がローカルの日付と最大 1 日ずれ、判定に最大 1 日の誤差が出る。ISO 8601 の値の時差は、判定に使わない。理由: 日付の部分だけで判定する実装であり、時差を使うと、日付だけの値や Unix 時間と扱いが分かれるため


#### 移動の前提条件と異常

- 前提条件: バッファが書き込み可能であること。done ファイルが書き込めること（ファイルがディレクトリでない、親ディレクトリに書き込める）。満たさない場合は、何も移動せず `user-error` にする。done ファイルへの追記だけが成功し、元のバッファでの削除が失敗する状態を作らないためである
- 書き込み: 同じディレクトリの一時ファイルに書き、`rename-file` で置き換える。書き込みが失敗しても、done ファイルは元の内容のままである
- done ファイルを訪問しているバッファがある場合は、そのバッファに追記する。そのバッファに未保存の変更がなければ保存し、あれば保存せず、メッセージで知らせる
- 自動移動で、あるバッファの移動が失敗したときは、メッセージを表示し、他のバッファの処理を続ける。読み取り専用のバッファは、移動せず、メッセージを表示する
- `altodo-auto-move-interval` は、正の数でなければならない。そうでなければ、タイマーを設定せず `user-error` にする


### 5.8 フィルタリング機能

サイドバーの項目、DSL パターン、動的フィルタ、カレンダー、一覧、見出しジャンプの仕様は、`doc/design-filter.md` に書く。ここでは概要だけを示す。

- 項目の種類: `:type` で指定する。`nil`、`comment`、`group-header`、`separator`、`command`、`dynamic`、`search-simple`、`search-lambda`、`calendar`、`agenda`
- 条件: DSL パターンで書く。`and:`、`or:`、`not:` で組み合わせる。複数の項目を選ぶと、AND または OR で結合する
- 親タスクの条件: DSL パターン `parent-task-regexp:REGEXP`、`root-task-regexp:REGEXP` で、特定の親タスクの配下のタスクを抽出する
- 件数: `:title` の `%n` に、一致した件数を表示する。`:count-format` で、件数の計算の有無を指定する


## 6. Font-lock 設計

### 6.1 markdown-mode との共存

altodo-mode は markdown-mode の派生モードである。色付けのとき、markdown-mode の次の 2 つの処理を調整する。


#### インデント付きコードブロックの除外

- markdown-mode は、4 スペース以上のインデントの行を「インデント付きコードブロック」として認識し、`markdown-pre` の text property を設定する。altodo はインデントでネストと複数行コメントを表すため、そのままではタスク行とコメント行に `markdown-pre-face`（水色）が付く
- `define-derived-mode altodo-mode` の本体で、`font-lock-remove-keywords` により `markdown-match-pre-blocks` を font-lock-keywords から除く。`syntax-propertize-function` は変更しない
- altodo ではインデント付きコードブロックを使わないため、この除外による影響はない

タスク行・1 行コメント行・複数行コメントの判定（`altodo--task-p`、`altodo--comment-p`、`altodo--multiline-comment-p`）は、フェンス付きコードブロックの内側かどうかだけを調べる（`altodo--in-fenced-code-block-p`）。インデント付きコードブロックとしては扱わない。


#### フェンス付きコードブロックの色の復元

- フェンス付きコードブロック（` ``` ` と `~~~`）の内側にも、altodo の face が付く
- `altodo--restore-code-block-faces` が、色付けした領域のうち、フェンス付きコードブロックの行の face を `markdown-pre-face` と `markdown-code-face` に置き換える。`font-lock-fontify-region-function` を包み、元の関数の実行後に呼ぶ
- 対象の行は、text property `markdown-gfm-code`（バッククォートのフェンス）または `markdown-fenced-code`（チルダのフェンス）を持つ行である。インデント付きの複数行コメントの行は、この text property を持たないため対象外である


### 6.2 処理順序（Layer 構造）

```
Layer 1: タスクブラケット（状態文字に blocked face を適用）
  ├── ブラケット
  ├── 状態文字
  └── ブラケット
  ↓
Layer 2: ベース（本文全体）
  ├── seq-tasks blocked タスク本文（先に処理）
  ├── 通常タスク本文
  ├── 待機タスク本文
  └── 進行中タスク本文
  ↓
Layer 3: （空 - タグは Layer 4 に移動）
  ↓
Layer 4: 強調要素（日付ベーステキスト、フラグ本文、タグ、日付）
  ├── 日付ベーステキスト（本文全体の色変更）
  ├── 優先度フラグ（3段階）
  ├── スターフラグ
  ├── 一般タグ（値付き・値なし）
  ├── @person タグ
  ├── 特殊タグ
  ├── 依存関係タグ
  ├── 日付の矢印
  ├── 開始日
  └── 期限
  ↓
Layer 5: 最優先（コメント全体、斜線）
  ├── 複数行コメント
  ├── 複数行コメント内リスト
  ├── 1行コメント全体
  └── 完了・廃止タスクの斜線
```


### 6.3 Override フラグ戦略

**注**: markdown-pre 対策により、altodo-mode バッファ内で `markdown-match-pre-blocks` が font-lock-keywords から除外される。そのため `markdown-pre-face` は適用されない。また、フェンスドコードブロック内の altodo face は `altodo--restore-code-block-faces` で markdown face に上書きされる。

| Layer | 要素                 | Override フラグ | 理由                                                       |
| ----- | -------------------- | --------------- | ---------------------------------------------------------- |
| 1     | ブラケット・状態文字 | `t`             | ブラケットと状態文字の face を確定させる                   |
| 2     | 本文全体             | `append`        | markdown-mode の face を優先し、altodo-mode の face を追加 |
| 3     | （空）               | -               | タグは Layer 4 に移動                                      |
| 4     | 日付ベーステキスト   | `prepend`       | 複数の face を重ねる                                       |
| 4     | フラグ（記号部分）   | `t`             | フラグ記号の face を確定させる                             |
| 4     | フラグ（本文部分）   | `prepend`       | 複数の face を重ねる                                       |
| 4     | タグ・日付           | `t`             | タグと日付の face を確定させる                             |
| 5     | コメント             | `prepend`       | 複数の face を重ねる                                       |
| 5     | 斜線                 | `t`             | 斜線の face を確定させる                                   |


### 6.4 seq-tasks 実装

#### seq-tasks blocked 状態判定

`#seq-tasks` を持つタスクの子は、すぐ上の兄弟が完了・廃止でない間、blocked とする。最初の子は blocked にならない。親（`#seq-tasks` を持つタスク）は blocked にしない。

- Layer 1: 状態文字に `altodo-dep-blocked-text-face` を適用
- Layer 2.5: 本文全体に `altodo-task-waiting-text-face` を適用（先に処理）
- Layer 2: 通常タスク本文に `altodo-task-open-text-face` を適用（後に処理）


#### Helper Functions

- `altodo--has-seq-tasks-tag()`: 現在行が seq-tasks タグを持つかチェック
- `altodo--is-seq-tasks-child-blocked-p()`: 現在行が、`#seq-tasks` を持つ親の子で、すぐ上の兄弟が未完了かチェック（インデントのない行は親がないため調べない）


## 7. 参考資料

- `doc/altodo_spec.md` - altodo フォーマット仕様書
- `doc/altodo_spec_en.md` - altodo フォーマット仕様書（英語版）
- `doc/design-filter.md` - フィルタリング機能設計書（DSL 仕様含む）
