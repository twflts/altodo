# altodo - TODO text file format, and Emacs Major Mode Package

このレポジトリは、__altodo__ フォーマットの仕様、および altodo を便利に管理する Emacs Major Mode 用のパッケージ __altodo.el__ を配布する。

- __altodo__ フォーマット: Markdown (CommonMark) ファイル上に埋め込み可能な TODO フォーマット
    - altodo フォーマット仕様（独自拡張部分）には MIT ライセンスが適用される
- __altodo.el__: Emacs 上で altodo フォーマットの TODO を管理する Emacs Lisp パッケージ
    - GNU General Public License v3.0 が適用される


## altodo フォーマットについて

__altodo__ は __Markdown__ および __CommonMark__ フォーマット仕様の独自拡張である。なお altodo は Creative Commons CC0 1.0 Universal でライセンスされた __[x]it!__ https://xit.jotaen.net/ を一部ベースにし、参考にした。

詳細は doc/altodo_spec.md を参照すること。

- Markdown (CommonMark) の独自拡張としてのテキストフォーマット仕様
    - altodo のフォーマット以外は Markdown (CommonMark) のフォーマット仕様に従う
- TODO は無限にネスト可能
- 1 行および複数行コメントを表現可
- タグ、スター、優先度、開始日・期日、依存関係タグを付与可

特に、 TODO を Markdown 内に埋め込めるというファイルフォーマットであり、プレインテキストである、無限にネストができること、複数行のコメントが付与できるのが特徴。
エディタで表示支援がなくても、分かりやすくシンプルな TODO フォーマットである（はず）。


### サンプル

```markdown
# altodo は Markdown 内に記載のできる TODO フォーマットである

前後がタスク行でなければ、 __通常の Markdown (CommonMark) 同様のテキスト__ を記載できる。

[ ] ここから TODO 行
[ ] __太字__ ~~斜線~~ のように、インラインの `Markdown` 記法をタスク内に埋め込める
[x] ここまで TODO 行

TODO 行、およびコメント行以外は通常の Markdown (CommonMark) のフォーマットである。


# 見出しにも #tag を埋め込むことができる

## altodo ファイル例 #tag

以下、altodo フォーマットのタスクを記載したものである。

[@] 進行中のタスク
    /// シングルコメント行
    [ ] 子タスク A（ネストのスペースは通常 4 文字）
        [x] 完了した子タスク
            [~] 廃止したタスク
    [w] 保留タスク @JohnDoe が対応中
[ ] + スターの付いたタスク
    [ ] ! 優先度の高いタスク
        [ ] !! さらに優先度の高いタスク
            [ ] !!! 最も優先度の高いタスク
[ ] タスク
    複数行コメント 1 行目
    複数行コメント 2 行目
    [ ] ネストされたタスク A
        ネストされたタスク A の複数行コメント 1 行目
        ネストされたタスク A の複数行コメント 2 行目
        
        ネストをしていれば、改行して何も記載されていない行も OK（複数行コメント 4 行目）
[ ] タグの付いたタスク #home タグの前後は半角スペースを入れる
[ ] 開始日があるタスク 2025-01-01 -> から開始
    [ ] 期限のあるタスク -> 2025-12-31 までに完了させる
    [ ] 開始日と期限があるタスク 2025-02-01 -> 2025-03-31 内に対応する
[ ] key-value 型のタグのあるタスク #key:value
[ ] 特殊なタグ（id）を使用した依存関係のあるタスク（ユニークの ID を持つ） #id:20250101-0000
[ ] 特殊なタグ（dep）を利用した依存関係のあるタスク（依存先 ID を指定） #dep:20250101-0000
[ ] 依存関係のあるタスク 2（依存先 ID を指定）  #dep:20250101-0000
[ ] 人 @JohnDoe や場所 @home を @person タグで表わすことができる
```

### 主要構文

#### タスク管理

- `[ ]`: オープン
- `[x]`: 完了（自動で #done タグ追加）
- `[@]`: 進行中
- `[w]`: 待機
- `[~]`: キャンセル


#### コメント

- `/// コメント`: 1 行コメント
- タスク行・1行コメントのインデント + 4 つのスペース: 複数行コメント


#### フラグ

- `!`, `!!`, `!!!`: 優先度（仕様上は無制限であるが通常 3 段階まで。 ! が多いほど優先度が高い）
- `+` - スターフラグ


#### タグ

- `#tag`: 一般タグ
- `#tag:value`: 値付きタグ
- `@person`: 担当者・場所タグ（例: `@smith`, `@名無しさん`, `@company`）

以下は機能のある特殊タグである

- `#id:value`: ID タグ
- `#dep:value`: 依存関係タグ。 ID タグの value を指定する


#### 期日・開始日

- `-> YYYY-MM-DD`: 期日
- `YYYY-MM-DD ->`: 開始日
- `YYYY-MM-DD -> YYYY-MM-DD`: 開始日と期日


## altodo.el

Emacs 上で altodo フォーマットの TODO を管理する Emacs Lisp パッケージである。 __Emacs Markdown Mode__ https://github.com/jrblevin/markdown-mode の独自拡張とし、altodo ファイルを操作し、face 適用やフィルタリングなどの機能でタスクを閲覧・操作しやすくする。
詳細は doc/design.md を参照すること。

- altodo ファイルを管理するのに便利な色付け（face）対応、キーバインドや各種コマンドの提供
- フィルタや、フィルタにマッチする件数をある程度動的にカウント表示してくれるサイドバー
    - サイドバーの内容は自由にカスタマイズ可能

特徴として、数千行の TODO を柔軟かつ素早く管理・表示できるように altodo.el はテストされており、操作性を含め Emacs フレンドリであり快適で素早いこと、柔軟なカスタマイズができるサイドバーがあげられる。
柔軟性の高いフィルタを設定可能にするため、フィルタリングで利用できる DSL や豊富な predicate 関数を提供する。


### キーバインド

altodo-mode は markdown-mode を継承しているため、markdown-mode のキーバインドも使用できる。タスク行や複数コメント行など、 altodo ファイルフォーマット特有の行でなければ markdown-mode のキーバインドとなる。


#### タスク操作

- `C-c C-x`: タスク状態トグル（オープン `[ ]` ⇔ 完了 `[x]`）
- `C-c C-t o`: オープンに設定
- `C-c C-t x`: 完了に設定
- `C-c C-t @`: 進行中に設定
- `C-c C-t w`: 待機に設定
- `C-c C-t ~`: キャンセルに設定


#### フラグ操作

- `C-c C-s`: スターフラグトグル
- `C-c C-f 1`: 優先度 1 に設定
- `C-c C-f 2`: 優先度 2 に設定
- `C-c C-f 3`: 優先度 3 に設定


#### インデント（ネスト）操作

- `TAB`: スマートインデント
- `M-<right>`: インデント増加
- `M-<left>`: インデント減少


#### その他

- `S-TAB`: アウトラインサイクル
- `C-c C-t d`: done タスクを done ファイルに移動


### done タスク移動機能

完了（`[x]`）またはキャンセル（`[~]`）されたタスクを別ファイルに自動移動する機能。
現在のバージョンでは、元タスクのネスト（ツリー）構造は維持や考慮をせず、単純に見出し（heading）のみを維持し、行そのものを移動する。


#### 基本機能

- 手動移動: `C-c C-t d` でカーソル位置のタスクを移動
- バッファ全体移動: `M-x altodo-move-all-done-tasks` でバッファ内の全 done タスクを移動
- 自動移動タイマー: 定期的に全バッファの done タスクを自動移動


#### done ファイル

- done タスクは `{元のファイル名}_done.altodo` に移動
- 見出し（セクション）ごとにグループ化
- マルチラインコメントも一緒に移動
- 空行は保持


#### 自動移動タイマー

```elisp
;; タイマーを開始/停止（toggle）
M-x altodo-toggle-auto-move-timer

;; または個別に
M-x altodo-start-auto-move-timer
M-x altodo-stop-auto-move-timer

;; 実行間隔を変更（デフォルト: 3600 秒 = 1 時間）
(setq altodo-auto-move-interval 1800)  ; 30 分

;; 自動保存を有効化（デフォルト: nil）
(setq altodo-auto-save-after-move t)

;; done ファイルをスキップ（デフォルト: t）
(setq altodo-auto-move-skip-done-files t)

;; モードライン表示（デフォルト: t）
(setq altodo-show-auto-move-in-mode-line t)
```


#### done ファイルのカスタマイズ

```elisp
;; done ファイルのサフィックスを変更（デフォルト: "_done"）
(setq altodo-done-file-prefix "_archive")
```


### 設定

#### 基本設定

| 変数名                                         | 説明                                             | デフォルト値 |
|------------------------------------------------|--------------------------------------------------|--------------|
| `altodo-indent-size`                           | インデントサイズ（スペース数）                   | `4`          |
| `altodo-enable-markdown-in-multiline-comments` | 複数行コメント内で Markdown フォーマットを有効化 | `t`          |
| `altodo-auto-save`                             | タスク状態変更時にファイルを自動保存             | `nil`        |
| `altodo-skk-wrap-newline`                      | SKK 入力メソッドとの互換性のため改行をラップ     | `t`          |


#### サイドバー設定

| 変数名                                  | 説明                                        | デフォルト値         |
|-----------------------------------------|---------------------------------------------|----------------------|
| `altodo-sidebar-modeline-enabled`       | サイドバーにフィルター状態を表示            | `t`                  |
| `altodo-sidebar-dynamic-count-enabled`  | 複数フィルター選択時にカウントを動的に更新  | `t`                  |
| `altodo-sidebar-buffer-name`            | サイドバーバッファ名                        | `"*altodo-filters*"` |
| `altodo-sidebar-position`               | サイドバー表示位置（`left` または `right`） | `'left`              |
| `altodo-sidebar-size`                   | サイドバー幅（ウィンドウ比 0.0-1.0）        | `0.2`                |
| `altodo-sidebar-indent`                 | サイドバーインデント幅                      | `2`                  |
| `altodo-sidebar-focus-after-activation` | アクティブ化後にサイドバーにフォーカス      | `nil`                |
| `altodo-sidebar-auto-resize`            | サイドバーを自動リサイズ                    | `nil`                |
| `altodo-sidebar-hide-mode-line`         | サイドバーのモードラインを非表示            | `nil`                |
| `altodo-sidebar-hide-line-numbers`      | サイドバーの行番号を非表示                  | `t`                  |


#### 日付・ID 設定

| 変数名                            | 説明                                   | デフォルト値   |
|-----------------------------------|----------------------------------------|----------------|
| `altodo-date-format`              | 日付フォーマット（nil で ISO 8601）    | `nil`          |
| `altodo-week-start-day`           | 週の開始日（1=月曜日, 0=日曜日）       | `1`            |
| `altodo-done-tag-datetime-format` | #done タグのタイムスタンプ形式         | `nil`          |
| `altodo-use-local-timezone`       | #done タグにローカルタイムゾーンを使用 | `t`            |
| `altodo-insert-id-format`         | #id: タグの ID 形式                    | `'tiny-random` |


#### タスク移動設定

| 変数名                                      | 説明                             | デフォルト値 |
|---------------------------------------------|----------------------------------|--------------|
| `altodo-done-file-prefix`                   | done ファイルのプレフィックス    | `"_done"`    |
| `altodo-move-single-line-comments-manually` | 1行コメントの手動移動を有効化    | `t`          |
| `altodo-auto-move-interval`                 | 自動移動の実行間隔（秒）         | `3600`       |
| `altodo-auto-save-after-move`               | 移動後に元ファイルを自動保存     | `nil`        |
| `altodo-auto-move-skip-done-files`          | done ファイルをスキップ          | `t`          |
| `altodo-show-auto-move-in-mode-line`        | モードラインに自動移動状態を表示 | `t`          |


#### デバッグ設定

| 変数名                                | 説明                                     | デフォルト値 |
|---------------------------------------|------------------------------------------|--------------|
| `altodo-debug-mode`                   | デバッグモードを有効化                   | `nil`        |
| `altodo-font-lock-maximum-decoration` | フォントロック装飾を最大化               | `t`          |
| `altodo-debug-log-file`               | デバッグログファイルパス                 | `nil`        |
| `altodo-debug-log-to-messages`        | デバッグログを *Messages* バッファに出力 | `nil`        |


#### デフォルトフィルター設定

| 変数名                           | 説明                                     | デフォルト値     |
|----------------------------------|------------------------------------------|------------------|
| `altodo-default-filter-patterns` | サイドバーのデフォルトフィルターパターン | 以下のリスト参照 |

```elisp
;; デフォルトフィルター設定例
(setq altodo-default-filter-patterns
  '((:title "Status" :type group-header :nest 0)
    (:title "Open [ ] - %n" :type search-simple :pattern "open" :count-format t :nest 1)
    (:title "In Progress [@] - %n" :type search-simple :pattern "progress" :count-format t :nest 1)
    (:title "Waiting [w] - %n" :type search-simple :pattern "waiting" :count-format t :nest 1)
    (:title "Done [x] - %n" :type search-simple :pattern "done" :count-format t :nest 1)
    (:title "Cancelled [~] - %n" :type search-simple :pattern "cancelled" :count-format t :nest 1)
    (:title "Flags" :type group-header :nest 0)
    (:title "Priority (!) - %n" :type search-simple :pattern "priority" :count-format t :nest 1)
    (:title "Star (+) - %n" :type search-simple :pattern "star" :count-format t :nest 1)
    (:title "Due" :type group-header :nest 0)
    (:title "Open and Over Due - %n"
            :type search-lambda
            :pattern (lambda ()
                       (and (altodo--due-date-matches-p 'overdue)
                            (not (or (altodo--line-state-p altodo-state-done)
                                     (altodo--line-state-p altodo-state-cancelled)))))
            :count-format t :nest 1)
    (:title "Section" :type separator :pattern "─" :nest 0)
    (:title "[Clear Filter]" :type command :nest 0 :command altodo-filter-clear)))
```


#### 設定例

```elisp
;; タイムゾーン設定
(setq altodo-use-local-timezone t)

;; 日付フォーマット設定
(setq altodo-date-format "%Y/%m/%d")

;; #done タグフォーマット設定
(setq altodo-done-tag-datetime-format nil)

;; 複数行コメント内の Markdown 要素を有効化
(setq altodo-enable-markdown-in-multiline-comments t)

;; インデントサイズ設定
(setq altodo-indent-size 4)

;; サイドバーを右側に表示
(setq altodo-sidebar-position 'right)

;; 自動移動を 30 分ごとに実行
(setq altodo-auto-move-interval 1800)

;; 移動後に自動保存
(setq altodo-auto-save-after-move t)
```


### インストール

- Emacs 27.1 以上
- markdown-mode の導入
    - altodo.el がリリースされた時点でのバージョンで検証・開発をしている


altodo.el を適当なディレクトリに配置し、以下のように init.el に追加する。

```
cp ./altodo.el ~/.emacs.d/lisp/.
```

```elisp
(add-to-list 'load-path "~/.emacs.d/lisp/")
(require 'altodo)
(add-to-list 'auto-mode-alist '("\\.altodo\\'" . altodo-mode))
```

#### 使用開始

1. `.altodo` ファイルを作成または開く
2. `M-x altodo-mode` で altodo-mode を有効化
3. `M-x altodo-sidebar-show` でサイドバーを表示
4. キーバインドでタスクを管理


