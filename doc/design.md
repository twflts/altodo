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
- 複雑なキャッシュや非同期処理は避ける
- font-lock の標準機能でシンタックスハイライト
- 必要に応じて段階的に最適化を追加


## 3. 実装状況

### ✅ 完成済み機能

#### Font-lock

- 5段階の Layer 処理（タスクブラケット → ベース → 部分要素 → 強調要素 → 最優先）
- 50 個の face 定義（全タスク状態、フラグ、タグ、コメント、日付ベース）
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

- `altodo-toggle-comment` のキー割り当て（コマンド自体は実装済み）
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

実装が定義する定数は次のとおり。

- `altodo-task-regex`: タスク行。値は `^\([ ]*\)\[\([x@w~ ]?\)\]\(.*\)$`。グループ 1 は行頭のインデント、グループ 2 は状態文字、グループ 3 は状態マークより後ろの文字列
- `altodo-comment-regex`: 一行コメント行。値は `^\([ \t]*\)/// \(.*\)$`
- `altodo-tag-with-value-regex`: 値付きタグ。値は `\(?:^\|[ \t]\)\(#[a-zA-Z0-9_-]+\):\("[^"]*"\|[^[:space:]]+\)`。値はダブルクオートで囲める
- `altodo-tag-without-value-regex`: 値なしタグ。値は `\(?:^\|[ \t]\)\(#[a-zA-Z0-9_-]+\)\b`
- `altodo-person-tag-regex`: @person タグ。値は `\(?:^\|[[:space:]]\)\(@[^[:space:]]+\)`
- `altodo-special-tag-regex`: 特殊タグ。`altodo-special-tag-names` から生成する

日付の正規表現は定数ではない。`altodo-date-format`（既定値 `nil` は `YYYY-MM-DD`）から、実行時に `altodo--date-regex-info` が生成する。


#### タスク状態文字リスト

```elisp
(defconst altodo-task-state-chars
  (concat altodo-state-done altodo-state-progress
          altodo-state-waiting altodo-state-cancelled)
  "List of task state characters.")
```

**値**: `"x@w~"`


### 4.2 カスタマイズ変数

| 変数名                                         | デフォルト     | 説明                                               |
| ---------------------------------------------- | -------------- | -------------------------------------------------- |
| `altodo-indent-size`                           | `4`            | インデントサイズ                                   |
| `altodo-enable-markdown-in-multiline-comments` | `t`            | 複数行コメント内で Markdown 書式を有効化           |
| `altodo-auto-save`                             | `nil`          | タスク状態の変更時にファイルを自動保存             |
| `altodo-skk-wrap-newline`                      | `t`            | SKK 入力メソッドとの互換のため改行をラップ         |
| `altodo-font-lock-maximum-decoration`          | `t`            | フォントロック装飾の最大化                         |
| `altodo-done-tag-datetime-format`              | `nil`          | `#done` の時刻書式（`nil` は ISO 8601 の時差付き） |
| `altodo-use-local-timezone`                    | `t`            | `#done` の時刻にローカルタイムゾーンを使用         |
| `altodo-insert-id-format`                      | `'tiny-random` | `#id` の ID 形式                                   |
| `altodo-date-format`                           | `nil`          | 日付書式（`nil` は `YYYY-MM-DD`）                  |
| `altodo-week-start-day`                        | `1`            | 週の開始日（0 は日曜日、1 は月曜日）               |
| `altodo-done-file-prefix`                      | `"_done"`      | done ファイル名に付ける文字列                      |
| `altodo-move-single-line-comments-manually`    | `t`            | 1 行コメントの手動移動を有効化                     |
| `altodo-auto-move-interval`                    | `3600`         | 自動移動の実行間隔（秒）                           |
| `altodo-auto-save-after-move`                  | `nil`          | 移動後に元ファイルを自動保存                       |
| `altodo-auto-move-skip-done-files`             | `t`            | 自動移動で done ファイルを対象外にする             |
| `altodo-show-auto-move-in-mode-line`           | `t`            | モードラインに自動移動の状態を表示                 |

サイドバーとデバッグの変数は、`README.md` の「設定」を参照する。


### 4.3 Face 定義

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
| `altodo-comment-face`           | 1行コメント用（赤色）      |
| `altodo-multiline-comment-face` | 複数行コメント用（グレー） |


#### フラグ Face

| Face                         | 説明                        |
| ---------------------------- | --------------------------- |
| `altodo-flag-star-face`      | スターフラグ用（金色太字）  |
| `altodo-flag-priority1-face` | 優先度1フラグ用（赤色）     |
| `altodo-flag-priority2-face` | 優先度2フラグ用（赤色太字） |
| `altodo-flag-priority3-face` | 優先度3フラグ用（赤色太字） |


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


### 4.4 キーマップ

タスク行・一行コメント行以外では、各キーは `markdown-mode` の割り当てを呼び出す。

| キー                            | 関数名                                                                 | 機能                             |
| ------------------------------- | ---------------------------------------------------------------------- | -------------------------------- |
| `TAB`                           | `altodo-indent-line`                                                   | サブタスク化・解除               |
| `RET`                           | `altodo-enter`                                                         | 文脈に応じた改行処理             |
| `<backtab>`                     | `outline-cycle`                                                        | アウトラインの循環               |
| `C-c C-x`                       | `altodo-toggle-task-state`                                             | オープン ↔ 完了のトグル         |
| `C-c C-t o`、`x`、`@`、`w`、`~` | `altodo-set-task-open`、`-done`、`-progress`、`-waiting`、`-cancelled` | 状態の設定                       |
| `C-c C-t d`                     | `altodo-move-done-tasks-at-point`                                      | 終了タスクを done ファイルへ移動 |
| `C-c C-a`                       | `altodo-add-task`                                                      | タスクの追加                     |
| `M-RET`                         | `altodo-add-subtask`                                                   | サブタスクの追加                 |
| `C-c C-m`                       | `altodo-start-multiline-comment`                                       | 複数行コメントの開始             |
| `C-c C-s`                       | `altodo-toggle-star-flag`                                              | スターフラグのトグル             |
| `C-c C-f 1`、`2`、`3`           | `altodo-set-priority-1`、`-2`、`-3`                                    | 優先度の設定                     |
| `C-c C-i`                       | `altodo-insert-id`                                                     | `#id` の挿入                     |
| `C-c C-j`                       | `altodo-goto-dependency`                                               | 依存先タスクへジャンプ           |
| `M-<right>`、`M-<left>`         | `altodo-indent-increase`、`altodo-indent-decrease`                     | インデントの増減                 |
| `C-c C-v f c`                   | `altodo-filter-clear`                                                  | フィルタクリア                   |
| `C-c C-v s t`                   | `altodo-sidebar-toggle`                                                | サイドバーの表示切替             |
| `C-c C-v s r`                   | `altodo-sidebar-refresh`                                               | サイドバーの更新                 |

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

`.altodo-locals.el` は alist 形式で任意の変数を指定可能。実装はファイルを Lisp データとして読み込むだけなので、制限はない。

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


## 5. 機能仕様

### 5.1 タスク状態管理

5つのタスク状態：

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

- フラグは、タスク行のタスク状態マークの直後、および1行コメント行の `///` の直後に置く
- フラグの後に半角スペースが必要


#### 優先度フラグ

- フラグ: `!`, `!!`, `!!!`
- 用途: 重要度に応じたタスクの優先度付け
- 例: `[ ] !!! 最も優先度の高いタスク`


### 5.3 コメント

#### 1行コメント

- マーカー: `///`
- 用途: タスクの一部ではない、分離した注記（補足、レビューメモ）
- 例: `/// これは一行コメント行`
- フラグ（`+`、`!`）を付与できる。例: `/// ! 重要な注記`


#### 複数行コメント

- 付随先: 直前のタスク行または1行コメント行
- 用途: タスクの説明など、タスクの一部
- 例: `[ ] タスク` の次の行 `    タスクの説明`


#### 複数行コメントの判定規則

仕様の詳細は `doc/altodo_spec.md` の 3.2.3 に従う。判定規則は次のとおり。

- 開始の行は、直前のタスク行・1行コメント行のインデント + 4 スペースで始まる。例外はない
- 開始の行と同じインデントの行のうち、タスク行以外は全て本文である。Markdown のリスト、リンク、フェンス付きコードブロックを含む
- 続きの行は、前行の複数行コメントと同じインデントである。インデントを保った、スペースだけの行も本文である
- インデントが異なる行（浅い行と深い行）、および完全な空行（0 文字）で終了する。入れ子の Markdown リストのように、深いインデントの行は本文にならない
- タスク状態マークで始まる行は、常にタスク行である

判定は、バッファの行ごとに、正規表現と直前の行の状態で行う。インデント付きの行を Markdown のインデント付きコードブロックとして扱わない（6.0 節）。


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


#### 制約

- 現在のバージョンは、タスクのネスト（ツリー）構造を維持しない。完了・廃止したタスクの行と、その複数行コメントだけを、見出しの下に移動する。子タスクは元のバッファに残る
- 将来、子タスクを含めて移動するよう改善する予定である


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
- `:type` オプション: フィルタタイプの指定（`nil`、`comment`、`group-header`、`separator`、`command`、`dynamic`、`search-simple`、`search-lambda`）


## 6. Font-lock 設計

### 6.0 markdown-pre 対策とコードブロック対応

**問題 1**: markdown-mode は 4 スペース以上のインデント行を「インデント済みコードブロック」として認識し、`markdown-pre` text property を設定する。これにより、altodo のタスク行・コメント行に `markdown-pre-face`（水色）が適用される。

**解決方法 1**: `font-lock-remove-keywords` で `markdown-match-pre-blocks` を font-lock-keywords から除外する。

**実装場所**: `define-derived-mode altodo-mode` の body 内

```elisp
;; Disable markdown-mode's indented code block highlighting
(font-lock-remove-keywords nil '((markdown-match-pre-blocks (0 'markdown-pre-face))))
```

**影響範囲**:
- altodo-mode バッファ内で `markdown-pre-face` が適用されなくなる
- altodo ファイルではインデント済みコードブロック（Markdown 仕様）は使用しないため、影響なし
- `syntax-propertize-function` には手を加えないため、Emacs の設計原則に反しない

---

**問題 2**: Markdown のフェンスドコードブロック（` ``` ` / `~~~`）内でも altodo-mode の face が適用される。

**解決方法 2**: `altodo--restore-code-block-faces` で フェンスドコードブロック内の altodo face を markdown face で上書きする。

**実装場所**: `define-derived-mode altodo-mode` の body 内

```elisp
;; Restore markdown faces in fenced code blocks
(let ((orig-fn font-lock-fontify-region-function))
  (setq-local font-lock-fontify-region-function
              (lambda (beg end &optional loudly)
                (funcall orig-fn beg end loudly)
                (altodo--restore-code-block-faces beg end))))
```

**ヘルパー関数**:

```elisp
(defun altodo--restore-code-block-faces (beg end)
  "Restore markdown faces in fenced code blocks between BEG and END.
Overwrites altodo faces with markdown-pre-face and markdown-code-face.
Only targets fenced code blocks (``` or ~~~), not indented code blocks."
  (save-excursion
    (goto-char beg)
    (while (< (point) end)
      (when (or (get-text-property (point) 'markdown-gfm-code)
                (get-text-property (point) 'markdown-fenced-code))
        (put-text-property (line-beginning-position) (line-end-position)
                           'face '(markdown-pre-face markdown-code-face)))
      (forward-line 1))))
```

**text property の種類**:
- `markdown-gfm-code`: バッククォートフェンス（` ``` `）
- `markdown-fenced-code`: チルダフェンス（`~~~`）

**影響範囲**:
- フェンスドコードブロック内の altodo face が markdown face で上書きされる
- インデント済みコメント行（複数行コメント）は対象外（text property がないため）


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
- `doc/design-filter.md` - フィルタリング機能設計書（DSL 仕様含む）
- `doc/design.md.backup_*` - 詳細設計（削除前のバージョン）
- `doc/tmp_design.md` - 実装詳細セクション（詳細設計用）
- `.kiro/memo/` - 開発メモ
