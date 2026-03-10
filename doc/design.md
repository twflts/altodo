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


### 拡張モジュール

- __altodo-enhanced.el__ - 進捗可視化・統計機能 (WIP)


### 実装方針

#### プレーンテキスト重視

- データ構造体は使用せず、バッファ内容を直接操作
- 行ごとの正規表現マッチングで機能を実行
- 必要時のみテキスト解析を行い、軽量性を保持
- プレーンテキストファイルとしての利点を最大化


#### シンプルな実装

- Emacs 標準機能を最大限活用
- 複雑なキャッシュや非同期処理は避ける
- font-lock の標準機能でシンタックスハイライト
- 必要に応じて段階的に最適化を追加


## 3. 実装状況

### ✅ 完成済み機能

#### Font-lock

- 5段階の Layer 処理（タスクブラケット → ベース → 部分要素 → 強調要素 → 最優先）
- 29個の face 定義（全タスク状態、フラグ、タグ、コメント、日付ベース）
- 統合処理による効率化


#### タスク状態管理

- 5つのタスク状態（オープン、完了、進行中、待機、廃止）
- 状態トグル機能（`C-c C-x`）
- 状態設定コマンド（`C-c C-t o/x/@/w/~`）


#### フラグ・優先度

- スターフラグ（`+`）
- 優先度フラグ（`!`, `!!`, `!!!`）


#### コメント

- 1行コメント（`///` マーカー）
- 複数行コメント（関数ベース判定）


#### タグ

- 一般タグ（`#tag`）
- 値付きタグ（`#key:value`）
- 特殊タグ（`#id`, `#dep`, `#done`）
- @person タグ


#### タスク移動機能

- 手動移動（`C-c C-t d`）
- 自動移動（タイマー方式）
- done ファイル管理


#### フィルタリング機能

- 親タスク正規表現フィルタ
- 複合条件対応（AND/OR/NOT）
- サイドバー `:title` 拡張機能


#### ナビゲーション機能

- 依存タスクジャンプ（`C-c C-j`）
- 複数バッファ対応


### 📋 未実装機能

#### ナビゲーション機能

- imenu 統合
- 折りたたみ機能
- タスク検索


#### 拡張機能

- 分析・レポート機能
- 外部ツール連携（Vertico/Consult）


#### その他

- `altodo-toggle-comment` コマンド
- `#group-start`, `#group-due` タグ


## 4. 仕様定義

### 4.1 定数定義

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

##### タスク行正規表現

```elisp
(defconst altodo-task-regex
  (concat "^\\([ \t]*\\)"
          "\\(\\[\\([~xw@ ]\\)\\]\\)"  ; タスク状態ブラケット
          "\\(?: \\(.*\\)\\)?$")        ; タスク本文（オプション）
  "Regex matching a task line.")
```

**構成**:
- `^` - 行頭
- `[ \t]*` - 先頭の空白（インデント）
- `\\[[~xw@ ]\\]` - タスク状態ブラケット（`[ ]`, `[@]`, `[w]`, `[x]`, `[~]`）
- `\\(?: \\(.*\\)\\)?$` - タスク本文（オプション）


##### コメント行正規表現

```elisp
(defconst altodo-comment-regex
  (format "^\\([ \t]*\\)%s \\(.*\\)$"
          (regexp-quote altodo-comment-marker))
  "Regex matching a comment line.")
```

**構成**:
- `^` - 行頭
- `[ \t]*` - 先頭の空白（インデント）
- `/// ` - コメントマーカー
- `\\(.*\\)$` - コメント本文


##### タグ正規表現

```elisp
(defconst altodo-tag-regex
  (concat "\\(?:^\\|[ \t]\\)"        ; 行頭または空白後
          "\\(#\\)"                  ; # タグ開始
          "\\(" altodo-tag-name-regex "\\)"  ; タグ名
          "\\(?::\\([^ \t\n]*\\)\\)?")      ; 値（オプション）
  "Regex matching a tag.")
```

**構成**:
- `\\(?:^\\|[ \t]\\)` - 行頭または空白後
- `#` - タグ開始
- タグ名（`altodo-tag-name-regex`）
- `:値`（オプション）


##### 日付正規表現

```elisp
(defconst altodo-date-regex
  (concat "\\([0-9]\\{4\\}[-/][0-9]\\{2\\}[-/][0-9]\\{2\\}\\)"  ; 日付
          "\\(?: -> \\)?"                                        ; 矢印（オプション）
          "\\(?:\\([0-9]\\{4\\}[-/][0-9]\\{2\\}[-/][0-9]\\{2\\}\\)\\)?")  ; 終了日
  "Regex matching a date range.")
```

**構成**:
- `YYYY-MM-DD` または `YYYY/MM/DD` 形式の日付
- ` -> ` 矢印（オプション）
- 終了日（オプション）


#### タスク状態文字リスト

```elisp
(defconst altodo-task-state-chars
  (concat altodo-state-done altodo-state-progress
          altodo-state-waiting altodo-state-cancelled)
  "List of task state characters.")
```

**値**: `"x@w~"`


### 4.2 カスタマイズ変数

| 変数名                                | デフォルト            | 説明                               |
|---------------------------------------|-----------------------|------------------------------------|
| `altodo-indent-size`                  | 4                     | インデントサイズ                   |
| `altodo-auto-save`                    | t                     | 自動保存の有効/無効                |
| `altodo-font-lock-maximum-decoration` | t                     | フォントロック装飾の最大化         |
| `altodo-done-tag-format`              | `"%Y-%m-%d_%H:%M:%S"` | 完了タグのタイムスタンプ形式       |
| `altodo-due-warning-days`             | 7                     | 期限警告開始日数                   |
| `altodo-due-urgent-days`              | 2                     | 期限緊急表示開始日数               |
| `altodo-date-patterns`                | YYYY-MM-DD 形式       | サポートする日付形式パターンリスト |
| `altodo-done-file-prefix`             | `"_done"`             | done ファイルの prefix             |
| `altodo-auto-move-enabled`            | t                     | 自動移動の有効/無効                |
| `altodo-auto-move-interval`           | 3600                  | 自動移動の実行間隔（秒）           |
| `altodo-auto-save-after-move`         | t                     | 移動後に元ファイルを自動保存       |


### 4.3 Face 定義

#### タスク状態 Face

| Face                         | 説明             |
|------------------------------|------------------|
| `altodo-task-open-face`      | オープンタスク用 |
| `altodo-task-done-face`      | 完了タスク用     |
| `altodo-task-progress-face`  | 進行中タスク用   |
| `altodo-task-waiting-face`   | 待機タスク用     |
| `altodo-task-cancelled-face` | 廃止タスク用     |

#### タスク本文 Face

| Face                              | 説明                                   |
|-----------------------------------|----------------------------------------|
| `altodo-task-open-text-face`      | オープンタスク本文用（ライトグリーン） |
| `altodo-task-done-text-face`      | 完了タスク本文用（斜線）               |
| `altodo-task-progress-text-face`  | 進行中タスク本文用（マゼンタ）         |
| `altodo-task-waiting-text-face`   | 待機タスク本文用（ライトグレイ）       |
| `altodo-task-cancelled-text-face` | 廃止タスク本文用（斜線）               |

#### コメント Face

| Face                            | 説明                       |
|---------------------------------|----------------------------|
| `altodo-comment-face`           | 1行コメント用（赤色）      |
| `altodo-multiline-comment-face` | 複数行コメント用（グレー） |

#### フラグ Face

| Face                         | 説明                        |
|------------------------------|-----------------------------|
| `altodo-flag-star-face`      | スターフラグ用（金色太字）  |
| `altodo-flag-priority1-face` | 優先度1フラグ用（赤色）     |
| `altodo-flag-priority2-face` | 優先度2フラグ用（赤色太字） |
| `altodo-flag-priority3-face` | 優先度3フラグ用（赤色太字） |

#### タグ・日付 Face

| Face                      | 説明                       |
|---------------------------|----------------------------|
| `altodo-tag-face`         | 一般タグ用（紫色）         |
| `altodo-tag-value-face`   | タグ値用（濃紫太字）       |
| `altodo-special-tag-face` | 特殊タグ用（マゼンタ太字） |
| `altodo-date-face`        | 日付用（青色）             |

#### 依存関係 Face

| Face                           | 説明                         |
|--------------------------------|------------------------------|
| `altodo-dep-blocked-text-face` | 依存関係ブロック中用（赤色） |
| `altodo-dep-blocked-tag-face`  | 依存タグブロック中用（赤色） |
| `altodo-dep-ready-tag-face`    | 依存タグ実施可能用（緑色）   |
| `altodo-dep-error-tag-face`    | 依存関係エラー用（赤色太字） |


### 4.4 キーマップ

| キー        | 機能               | 関数名                            | 説明                                                        |
|-------------|--------------------|-----------------------------------|-------------------------------------------------------------|
| `TAB`       | インデント操作     | `altodo-indent-line`              | サブタスク化・解除                                          |
| `RET`       | 改行・新規タスク   | `altodo-enter`                    | 文脈に応じた改行処理                                        |
| `C-c C-x`   | タスク状態トグル   | `altodo-toggle-task-state`        | オープン ↔ 完了のトグル                                    |
| `C-c C-t o` | オープンタスク     | `altodo-set-task-open`            | `[ ]` に変更                                                |
| `C-c C-t x` | 完了タスク         | `altodo-set-task-done`            | `[x]` に変更                                                |
| `C-c C-t @` | 進行中タスク       | `altodo-set-task-progress`        | `[@]` に変更                                                |
| `C-c C-t w` | 保留タスク         | `altodo-set-task-waiting`         | `[w]` に変更                                                |
| `C-c C-t ~` | 廃止タスク         | `altodo-set-task-cancelled`       | `[~]` に変更                                                |
| `C-c C-t d` | 終了タスク移動     | `altodo-move-done-tasks-at-point` | カーソル位置/リージョン内の終了タスクを done ファイルに移動 |
| `C-c C-a`   | タスク追加         | `altodo-add-task`                 | サブタスクまたは新規タスクを追加                            |
| `C-c C-m`   | 複数行コメント開始 | `altodo-start-multiline-comment`  | 複数行コメントを開始                                        |
| `C-c C-s`   | スターフラグトグル | `altodo-toggle-star-flag`         | `+` フラグのトグル                                          |
| `C-c C-f 1` | 優先度1設定        | `altodo-set-priority-1`           | `!` フラグを設定                                            |
| `C-c C-f 2` | 優先度2設定        | `altodo-set-priority-2`           | `!!` フラグを設定                                           |
| `C-c C-f 3` | 優先度3設定        | `altodo-set-priority-3`           | `!!!` フラグを設定                                          |
| `C-c C-v f c` | フィルタクリア   | `altodo-filter-clear`             | 全てのフィルタを解除                                        |
| `C-c C-v s t` | サイドバートグル | `altodo-sidebar-toggle`           | サイドバーの表示/非表示を切り替え                           |
| `C-c C-v s r` | サイドバー更新   | `altodo-sidebar-refresh`          | サイドバーの内容を更新                                      |
| `C-c =`     | コメント切り替え   | `altodo-toggle-comment`           | タスク ↔ コメントのトグル                                  |


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

`.altodo-locals.el` は alist 形式で任意の変数を指定可能。実装はファイルを Lisp データとして読み込むだけなので、制限はない。

| 変数名                      | 説明                                        |
|-----------------------------|---------------------------------------------|
| `altodo-filter-patterns`    | サイドバーフィルタパターンリスト            |
| `altodo-sidebar-face-alist` | サイドバー用 face 定義                      |
| `altodo-sidebar-position`   | サイドバー表示位置（`left` または `right`） |
| `altodo-sidebar-size`       | サイドバー幅（文字数）                      |
| `altodo-sidebar-indent`     | サイドバーインデント幅                      |

**例**:

```elisp
(
 (altodo-filter-patterns . (...))
 (altodo-sidebar-face-alist . (...))
 (altodo-sidebar-position . right)
 (altodo-sidebar-size . 30)
 )
```


### 4.4 デフォルト設定

ファイルが存在しない場合は以下のデフォルト値を使用：

- `altodo-filter-patterns` → `altodo--default-filter-patterns` 変数
- サイドバー face → デフォルト face


## 5. 機能仕様

### 5.1 タスク状態管理

5つのタスク状態：

| 状態     | マーク | 説明                           |
|----------|--------|--------------------------------|
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


#### 優先度フラグ

- フラグ: `!`, `!!`, `!!!`
- 用途: 重要度に応じたタスクの優先度付け
- 例: `[ ] !!! 最も優先度の高いタスク`


### 5.3 コメント

#### 1行コメント

- マーカー: `///`
- 例: `/// これは一行コメント行`


#### 複数行コメント

- タスク行または1行コメント行の直後のインデント行
- インデント規則: 親行のインデント + 4 スペース
- 空行（インデントなし）で終了


#### 複数行コメントの終了判定

複数行コメントは**空行（インデントなし）**で終了する。

**判定ロジック**:

```elisp
(defun altodo--multiline-comment-p ()
  "Check if current line is part of a multiline comment.
Returns t if in multiline comment, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (let ((indent (current-indentation)))
      (cond
       ;; 1行コメント行は複数行コメントではない
       ((looking-at-p (format "^%s[ \t]*$"
                             (regexp-quote altodo-comment-marker)))
        nil)
       ;; インデントなしは複数行コメントの終了
       ((= indent 0)
        nil)
       ;; インデントありは複数行コメントの継続
       (t t)))))
```

**処理**:
1. 現在の行が1行コメント行（`///` のみ）の場合は終了
2. 現在の行がインデントなしの場合は終了
3. 現在の行がインデントありの場合は継続


### 5.4 タグ

#### 一般タグ

- 形式: `#tag`
- 例: `[ ] #home でタスクを行う`


#### 値付きタグ

- 形式: `#key:value`
- 例: `[ ] #work-by:john`


#### 特殊タグ

| タグ                | 説明                         |
|---------------------|------------------------------|
| `#id:value`         | ユニーク識別子               |
| `#dep:value`        | 依存関係（参照先 ID を指定） |
| `#group-start:date` | グループのタスクの開始日     |
| `#group-due:date`   | グループのタスクの期日       |
| `#done:timestamp`   | タスクが完了・廃止された時刻 |


#### @person タグ

- 形式: `@person`
- 用途: 担当者・場所の指定
- 例: `[ ] タスク @john に確認`


### 5.5 日付システム

#### 開始日・期限

- 開始日: `YYYY-MM-DD ->`
- 期限: `-> YYYY-MM-DD`
- 両方: `YYYY-MM-DD -> YYYY-MM-DD`


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


### 5.7 タスク移動機能

#### 手動移動

- コマンド: `altodo-move-done-tasks-at-point`
- キーバインド: `C-c C-t d`
- 対象: 完了（`[x]`）・廃止（`[~]`）タスク + 複数行コメント


#### 自動移動

- タイマー方式（グローバルタイマー）
- 実行間隔: `altodo-auto-move-interval`（デフォルト: 3600秒）
- 対象: すべての開いている altodo バッファ


#### done ファイル

- 命名規則: `[ファイル名]_done.altodo`
- prefix: `altodo-done-file-prefix` で設定可能


### 5.8 フィルタリング機能

#### 親タスク正規表現フィルタ

- 変数: `parent-task-regexp`, `root-task-regexp`
- 用途: 特定の親タスク配下のタスクを抽出


#### 複合条件対応

- AND/OR/NOT 条件での組み合わせ
- 複数フィルタの同時適用


#### サイドバー機能

- `:title` に `%n` プレースホルダーでマッチ数を表示
- `:count-format` オプション: カウント処理の有効/無効
- `:type` オプション: フィルタタイプの指定（nil, "comment", "group-header", "dynamic"）


## 6. Font-lock 設計

### 6.0 markdown-pre 対策

**問題**: markdown-mode は 4 スペース以上のインデント行を「インデント済みコードブロック」として認識し、`markdown-pre` text property を設定する。これにより、altodo のタスク行・コメント行に `markdown-pre-face`（水色）が適用される。

**解決方法**: `font-lock-remove-keywords` で `markdown-match-pre-blocks` を font-lock-keywords から除外する。

**実装場所**: `define-derived-mode altodo-mode` の body 内

```elisp
;; Disable markdown-mode's indented code block highlighting
(font-lock-remove-keywords nil '((markdown-match-pre-blocks (0 'markdown-pre-face))))
```

**影響範囲**:
- altodo-mode バッファ内で `markdown-pre-face` が適用されなくなる
- altodo ファイルではインデント済みコードブロック（Markdown 仕様）は使用しないため、影響なし
- `syntax-propertize-function` には手を加えないため、Emacs の設計原則に反しない

### 6.1 処理順序（Layer 構造）

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


### 6.2 Override フラグ戦略

**注**: markdown-pre 対策により、altodo-mode バッファ内で `markdown-match-pre-blocks` が font-lock-keywords から除外される。そのため `markdown-pre-face` は適用されない。

| Layer | 要素                     | Override フラグ | 理由                                                       |
|-------|--------------------------|-----------------|-----------------------------------------------------------|
| 1     | ブラケット・状態文字     | `t`             | ブラケットと状態文字の face を確定させる                   |
| 2     | 本文全体                 | `append`        | markdown-mode の face を優先し、altodo-mode の face を追加 |
| 3     | （空）                   | -               | タグは Layer 4 に移動                                      |
| 4     | 日付ベーステキスト       | `prepend`       | 複数の face を重ねる                                       |
| 4     | フラグ（記号部分）       | `t`             | フラグ記号の face を確定させる                             |
| 4     | フラグ（本文部分）       | `prepend`       | 複数の face を重ねる                                       |
| 4     | タグ・日付               | `t`             | タグと日付の face を確定させる                             |
| 5     | コメント                 | `prepend`       | 複数の face を重ねる                                       |
| 5     | 斜線                     | `t`             | 斜線の face を確定させる                                   |


### 6.3 seq-tasks 実装

#### seq-tasks blocked 状態判定

- Layer 1: 状態文字に `altodo-dep-blocked-text-face` を適用
- Layer 2.5: 本文全体に `altodo-task-waiting-text-face` を適用（先に処理）
- Layer 2: 通常タスク本文に `altodo-task-open-text-face` を適用（後に処理）


#### Helper Functions

- `altodo--has-seq-tasks-tag()`: 現在行が seq-tasks タグを持つかチェック
- `altodo--get-seq-tasks-parent()`: 現在行の親タスク（seq-tasks タグを持つ）を取得
- `altodo--get-seq-tasks-children()`: 現在行の直下の子タスクを取得
- `altodo--line-seq-tasks-blocked-p()`: 現在行が seq-tasks blocked 状態かチェック
- `altodo--is-seq-tasks-child-blocked-p()`: 現在行が seq-tasks child blocked 状態かチェック


## 7. 関数リファレンス

### 7.1 ユーティリティ関数

#### `altodo--normalize-state (state-str)`

- 引数: `state-str` - 状態文字列
- 戻り値: 正規化された状態文字列
- 説明: タスク状態文字列を正規化


#### `altodo--get-state-face (state)`

- 引数: `state` - タスク状態文字
- 戻り値: 対応する face シンボル
- 説明: タスク状態に対応する face を取得


#### `altodo--get-state-text-face (state)`

- 引数: `state` - タスク状態文字
- 戻り値: 対応するテキスト face シンボル
- 説明: タスク状態に対応するテキスト face を取得


### 7.2 タスク状態操作関数

#### `altodo-toggle-task-state ()`

- 説明: 現在行のタスク状態をトグル


#### `altodo-set-task-open ()`

- 説明: 現在行のタスクをオープン状態に設定


#### `altodo-set-task-done ()`

- 説明: 現在行のタスクを完了状態に設定


#### `altodo-set-task-progress ()`

- 説明: 現在行のタスクを進行中状態に設定


#### `altodo-set-task-waiting ()`

- 説明: 現在行のタスクを待機状態に設定


#### `altodo-set-task-cancelled ()`

- 説明: 現在行のタスクを廃止状態に設定


### 7.3 日付処理関数

#### `altodo--parse-date (date-str)`

- 引数: `date-str` - 日付文字列
- 戻り値: `(year month day)` のリストまたは nil
- 説明: 日付文字列を解析してリスト形式に変換


#### `altodo--days-diff (date-time)`

- 引数: `date-time` - 日付
- 戻り値: 日数差（整数）
- 説明: 指定日付と今日の日数差を計算


#### `altodo--determine-start-date-face (date-str)`

- 引数: `date-str` - 日付文字列
- 戻り値: face シンボルまたは nil
- 説明: 開始日に基づいて適用すべき face を決定


#### `altodo--determine-due-date-face (date-str)`

- 引数: `date-str` - 日付文字列
- 戻り値: face シンボルまたは nil
- 説明: 期限に基づいて適用すべき face を決定


### 7.4 行判定関数

#### `altodo--task-p ()`

- 戻り値: t または nil
- 説明: 現在行がタスク行かどうかを判定


#### `altodo--comment-p ()`

- 戻り値: t または nil
- 説明: 現在行が1行コメント行かどうかを判定


#### `altodo--multiline-comment-p ()`

- 戻り値: t または nil
- 説明: 現在行が複数行コメントかチェック


### 7.5 インデント支援関数

#### `altodo-indent-line ()`

- 説明: 現在行のインデントをスマートに調整


#### `altodo-enter ()`

- 説明: Enter キー処理（改行とインデント）


#### `altodo-add-task ()`

- 説明: 現在行のタイプに応じてサブタスクまたは新規タスクを追加


#### `altodo-start-multiline-comment ()`

- 説明: タスク行または1行コメント行から複数行コメントを開始


### 7.6 Font-lock マッチャー関数

#### `altodo--start-date-matcher (limit)`

- 引数: `limit` - 検索上限位置
- 戻り値: t または nil
- 説明: 開始日マッチャー


#### `altodo--due-date-matcher (limit)`

- 引数: `limit` - 検索上限位置
- 戻り値: t または nil
- 説明: 期限マッチャー


#### `altodo--multiline-comment-matcher (limit)`

- 引数: `limit` - 検索上限位置
- 戻り値: t または nil
- 説明: 複数行コメント処理用の font-lock マッチャー


## 8. 参考資料

- `doc/altodo_spec.md` - altodo フォーマット仕様書
- `doc/altodo_spec_en.md` - altodo フォーマット仕様書（英語版）
- `doc/design.md.backup_*` - 詳細設計（削除前のバージョン）
- `doc/tmp_design.md` - 実装詳細セクション（詳細設計用）
- `.kiro/memo/` - 開発メモ

