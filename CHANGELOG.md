# 変更履歴

このファイルは、[Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) の形式に従う。バージョン番号は、`altodo.el` のヘッダー（現在は 0.1.0）に従う。


## 未リリース

### 互換性に影響する変更

- サイドバーのエントリで `:count-format` を省略したとき、`t` として扱う（従来は、通常のエントリは `nil`、動的フィルタと見出しは `t`）。`:title` に `%n` があれば、数に置き換わる。置き換えたくないときは `:count-format nil` を指定する
- `:count-face-rules` は、`%n` の数字だけに適用する。`:face-rules` がないときに行全体にも適用していた動作をやめた（設計書 13.6 節のとおり）
- サイドバーの内部変数 `altodo-sidebar--active-entries` と内部関数 `altodo-sidebar--update-active-entry` を削除した。クリックしたエントリは `altodo-sidebar--selected-filters`（`altodo-sidebar--selection-mode` が `single`）に入る
- `.altodo-locals.el` に書いた `search-lambda` の lambda、`:count-pattern-lambda`、`altodo-` で始まらない `:command` は、既定では実行しない。実行する場合は、`altodo-locals-code-policy` を `confirm`（ファイルの SHA-256 を承認したときだけ実行）または `allow`（常に実行）にする。`altodo-default-filter-patterns` に書いたコードは、従来どおり実行する
- 内部関数のうち、接頭辞のない `sidebar-*` を `altodo-sidebar--*` に改名した（`sidebar-display` は `altodo-sidebar--display`）。互換用の別名はない
- 組み込みの自己テスト関数（`altodo-run-full-test-suite` など）を削除した。テストは `test/` の ERT に統一した
- 存在しない日付（`2026-02-30` など）を日付として扱わない。色付けは通常の日付の face になり、日付条件に一致しない
- `:face-rules` の演算子は、`<`、`>`、`<=`、`>=`、`=`、`/=` だけを評価する
- 完了・廃止したタスクの移動の単位を、子孫を含むサブツリーにした（`altodo-move-unit` の既定は `subtree`）。子孫に未完了のタスクがあるときは移動しない。一括移動と自動移動は、親のないタスクだけを対象にする。従来の動作は、`altodo-move-unit` を `line` にするか、`C-c C-t D`（`altodo-move-done-task-alone`）で使える
- dynamic フィルタの `:limit 0` を、無制限にした（従来は 0 行になった）。`:limit nil` と同じ扱いである
- DSL の `heading:REGEXP` は、正規表現として、見出しの文字列の中から探す（従来は、状態によって、部分文字列または先頭一致になっていた）。同じ文字列の見出しが複数あるときは、すべてを対象にする。`C++` のように特殊文字を含む指定は、`C\+\+` に直す
- `#seq-tasks` の子は、すぐ上の兄弟が完了・廃止でない間だけ blocked になる（従来は、前にある兄弟のどれかが未完了なら blocked だった）。`#seq-tasks` を持つ親は、blocked の表示にならない
- 期日（`-> DATE`）と開始日（`DATE ->`）の認識を、色付け、絞り込み、カレンダー、日付入力で統一した。対象の行はタスク行、`///` コメント行、見出しで、複数行コメントとコードブロックの中は対象外。日付と矢印の前後に空白が要る（従来、絞り込みは `a->2026-01-01` なども日付として扱った）
- 効果のなかった設定 `altodo-font-lock-maximum-decoration`、`altodo-move-single-line-comments-manually`、`altodo-sidebar-buffer-name`、`altodo-sidebar-auto-resize` を削除した
- `altodo-insert-id-format` の `uuid` と `base62` は、RFC 9562 の UUIDv7（先頭 48 ビットがミリ秒の Unix 時刻）を生成する。従来の ID は有効だが、新しい ID とは時刻順に並ばない
- `altodo-week-start-day` の既定を、月曜日（1）から日曜日（0）に変えた。サイドバーのカレンダー、日付入力のカレンダー、日付条件 `this-week` の範囲が、日曜日始まりになる。月曜日始まりにするには、`altodo-week-start-day` を `1` にする。値が `nil` のときの週の開始日も、日曜日である
- デバッグ機構を作り直した。`debug-helper.el`、`altodo-debug-mode`、`altodo-debug-log-file`、`altodo-debug-log-to-messages`、`altodo-debug-enable`、`altodo-debug-disable`、`altodo-debug-add-function`、`altodo-debug-remove-function`、`altodo-debug-clear-log`、`altodo-debug-view-log` を削除した。`altodo-debug-mode` が非 nil のとき `message` を全体で再定義する処理も削除した。代わりに、任意のファイル `altodo-debug.el` の調査用のコマンドを使う
- `altodo-done-tag-datetime-format` を指定したとき、`#done` の値は書式の結果だけになる（従来は時差が付いた）。結果に空白があるときは、二重引用符で囲む
- `:count-exclude-others nil` を指定したとき、タスク行以外も数える（従来は指定が無視された）
- 保存時に、サイドバーが表示されていなければ、サイドバーを再描画しない（表示するときに描画する）


### 追加

- 調査用のコマンド（`altodo-debug.el`）: 行の診断（`altodo-debug-describe-line`）、DSL パターンの診断（`altodo-debug-explain-pattern`）、関数の追跡（`altodo-debug-trace`）、性能の測定（`altodo-debug-profile`）、不具合の報告用の情報（`altodo-debug-report`）。バッチ用に `scripts/debug-line.sh` と `scripts/debug-pattern.sh`。`doc/debug.md` を参照
- `altodo-filter-by-pattern`: DSL パターンに一致する行だけを表示する。`altodo-filter-show-*` は、DSL を使う実装に統一した（`altodo-filter-show-overdue` が `altodo-date-format` に依存しなくなった）
- `altodo-sidebar-focus-after-activation` を実装した。非 nil のとき、サイドバーでフィルタを選んだ後に、ソースのウィンドウへフォーカスを移す
- フォントロックの所要時間を測る `scripts/bench-fontlock.sh`
- スターフラグ（`+`）と優先度フラグ（`!`〜`!!!`）を同じ行で併用できる
- `altodo-locals-code-policy`、`altodo-trusted-locals`
- 見出しジャンプ: `altodo-filter-patterns` の `:type dynamic` に `:dynamic-type "heading"` を追加した。見出しを選ぶと、ソースのバッファの見出しの行へカーソルを移して、上端付近に表示する（絞り込みは変えない。見出しが非表示なら絞り込みを解除する）。`:level`、`:limit`（`0` または `nil` で無制限）、`:indent-by-level`（`t`、整数、`nil`）、`:title` の `%s`、`%l`、`%n`（見出しごとの未完了のタスク数）を指定できる。既定のパターンの `People` の後ろに、`Headings` グループを加えた
- サイドバーの既定のパターン（`altodo-default-filter-patterns`）の先頭に、月のカレンダー（`calendar`）を加えた。サイドバーの幅が足りないとき（既定の幅は、フレームの 20%）は、注記を表示する。カレンダーが不要なときは、`altodo-default-filter-patterns` から、`:type calendar` の行を除く
- 一覧（`agenda`）の曜日の名前は、`altodo-calendar-day-names` を既定から変更したとき、その名前になる（既定のままのときは、従来どおり `Tue` など）
- サイドバーの `calendar`（月のカレンダー）と `agenda`（日ごとの一覧）のエントリ。期日と開始日のあるタスクの数を、face とボタンで示し、日を選ぶとその日のタスクで絞り込む。土日と祝日（既定は日本の国民の祝日）、今日、期日（赤い背景）、開始日（青い背景）、期日が多い日、期限超過を、`altodo-calendar` グループの face で示す。曜日・月の名前、見出しの書式、`<` `>` の表示、祝日の関数、期日と開始日の優先を、オプションで変更できる。一覧（`agenda`）の日付の書式（`altodo-date-format` に合わせる、`#done` の書式に合わせる、または独自の書式）、曜日の表示、「Today」「Tomorrow」「Overdue」の文字列、ラベルの後ろの改行は、エントリのプロパティ（`:date-format`、`:show-weekday`、`:today-label`、`:tomorrow-label`、`:overdue-label`、`:label-newline`）で指定する
- ミニカレンダーのライブラリ `altodo-calendar.el`（`calendar` だけに依存）。altodo.el と同じディレクトリに置く。`altodo-calendar-insert`、`altodo-calendar-japanese-holiday`、`altodo-calendar-emacs-holiday`
- 日付の入力: `C-c C-e d`（`altodo-select-due-calendar`）と `C-c C-e s`（`altodo-select-start-calendar`）でカレンダーのウィンドウから期日・開始日を選ぶ。`altodo-input-due-date` と `altodo-input-start-date` でミニバッファから入力する
- サイドバーのヘルプ: `?` または `h`（`altodo-sidebar-help`）でキーバインドを表示する
- `altodo-move-after-days`: 一括移動と自動移動で、`#done` タグの日付が N 日以上前のタスクだけを移動する
- DSL のパターンを追加した: `state-any`、`has-any-flag`、`has-any-tag`、`has-all-tags`、`has-any-person`（複数の値。値は、カンマまたは `|` で区切る）、`task`、`comment`、`multiline-comment`、`heading`、`empty-line`、`any-line`
- `#group-start`、`#group-due` を仕様書に追加した
- done ファイルを開いているバッファがあるときは、そのバッファに追記する
- 自動移動で、あるバッファの移動に失敗しても、他のバッファの移動を続ける。読み取り専用のバッファは、メッセージを表示して飛ばす
- 開発用スクリプト（`scripts/`）: Emacs の導入、テスト、lint、ベンチマーク、ドキュメントの名前の確認、ローカル CI
- テストの一覧（`test/INDEX.md`）、共通のヘルパー、サンプルファイルの検証テスト


### 変更

- サイドバーの動的フィルタ（`:type dynamic`）と見出しの展開は、`:face-rules`、`:count-face-rules`、`:count-exclude-others`、`:display-context`、`:multiline-comment` など、展開に使わないプロパティを展開後のエントリに引き継ぐ（従来は `:face`、`:face-count`、`:count-format` だけだった）。見出しの `:face-rules` は、見出しの未完了のタスク数で評価する
- `:face`、`:face-count`、`:face-rules` と `:count-face-rules` の値に、face 名、face 名のリスト、plist（`(:foreground "red")`）、defface 形式（`((t (:foreground "red")))`）を指定できる。従来の `:face` は、plist を無視した
- 書式が不正な `:face-rules`、`:count-face-rules` の規則は、その規則だけを無視して、メッセージを 1 回表示する（従来は、サイドバー全体が描画されなかった）
- `:face-rules` に使うカウントは、複数選択のとき、タイトルの `%n` と同じ（結合した predicate を適用した）値になる。`%n` のないタイトルでも同じである
- サイドバーのクリックの処理時間を短縮した。1 回のクリックで描画が 2 回起きていたのを 1 回にし、バッファが変わらない間は、エントリのカウントを再利用する。5000 行、既定のパターンで、約 1.4 秒から約 0.2 秒（2 回目以降）になった
- サイドバーのバッファを、`special-mode` から派生したメジャーモード `altodo-sidebar-mode` にした。`special-mode` のキー割り当ても使える
- 既定のパターンの期限のエントリ（"Open and Over Due" など）を、`lambda` から DSL のパターンに変えた。表示と件数は同じである
- 既定のパターンの「`Star (+)`」から `:count-face-rules` を外した（件数が 5 以上で `error`、1 以上で `warning` の色にしていた）。「`Priority (!)`」と同じく、件数に色を付けない
- 内部の整理: 使われていない関数（旧い絞り込みの部品、行番号の計算、重複したマッチャーなど約 20 件）と、古いコメント（存在しないファイルへの参照、開発工程の名前）を削除した。キーマップの 24 個の `lambda` と、状態を設定する 5 つのコマンドの重複を整理した
- 複数行コメントの判定を、仕様（直前のタスク行・`///` 行のインデント + 4 スペース）どおりにした。深いインデントの行や、完全な空行（0 文字）で終わる
- フィルタの処理時間を短縮した。10,000 行（`tag:work`、表示コンテキストあり）で 2.99 秒から 0.36 秒になった。行数の上限（10,000 行）を撤廃した
- 設定ファイルの構文エラー、alist でない内容、不正なエントリは、警告を表示して使わない。同じ警告は、ファイルを更新するごとに 1 回だけ表示する
- done ファイルは、一時ファイルに書いてから置き換える。読み取り専用のバッファや、書き込めない done ファイルでは、何も移動せずにエラーにする
- フィルタの述語がエラーを出したときは、フィルタを解除する
- `altodo-auto-move-interval` は、正の数だけを受け付ける
- 日付の差は、暦の日数で数える。夏時間の切替日も 1 日として数える


### 修正

- `search-lambda` のエントリをクリックしたとき、複数選択が解除されない不具合を直した。`:display-context` も適用する
- `altodo-filter-by-pattern` と `altodo-filter-show-*` を実行したとき、サイドバーの選択（色）が実際のフィルタと食い違う不具合を直した。サイドバーの選択を解除して、描画し直す
- サイドバーの `c` が、ソースのバッファのフィルタを解除しない不具合を直した
- サイドバーを非表示にして再表示したとき、複数選択のカウントが全体の数に戻る不具合を直した
- `C-c C-v f c`、`C-c C-v s t`、`C-c C-v s r` が、見出しや通常の文章の行では動かず、Markdown のコマンドに回っていた。どの行でも動く
- フォントロックの時間が行数の 2 乗になり、5000 行のバッファ全体の色付けに 53 秒かかる
- `#done` の書式を指定したとき、時差が付く、または空白で値が切れる
- 完了ファイルへの移動で、`# Work` のタスクが `# Workshop` の下に入る
- `.altodo-locals.el` の読み取りで `read-eval` を無効にした
- 人（`@name`）の誤検知。`https://example.com/test@hogefuge` や `john@example.com` のように、行頭でも空白の後ろでもない `@` を、dynamic フィルタの person、`person:NAME` のパターン、`altodo-filter-show-person` が人として扱っていた
- `this-week` と `this-month` の日付条件の境界（週開始日の設定、月末日）
- `altodo-date-format` が `%Y-%m-%d` 以外のとき、`today`、`overdue`、`this-week` などの相対的な条件が誤った結果になる
- ハイフンを含む `#id` の前方一致（`#id:T1` が `#id:T1-2` に一致する）。`altodo-goto-dependency` が `#id:A1` を `#id:A` の移動先にする
- 夏時間のあるタイムゾーンで、日付が 01:00 に符号化される
- 状態のトグル（`altodo-toggle-comment`）で空白が二重になり、インデントを失う
- TAB でタスクを動かしたときに、複数行コメントが付いてこない。通常のテキスト行で TAB を押すと無限再帰になる。`indent-tabs-mode` により TAB が挿入される
- `altodo--filter-lines` で、複数行コメントの非表示（`show-multiline-comment` に `nil`）を指定できない
- サイドバーで、フィルタ未選択のときの AND/OR の切り替えと、`nil` の項目の選択がエラーになる
- `#seq-tasks` のタグを、タグ名の一部（`#seq-tasks-x` など）にも誤って一致させる
- 未使用の `altodo--update-seq-tasks-status`（未定義の `font-lock-fontify-line` を呼ぶ）を削除した
- docstring、バイトコンパイル、checkdoc、package-lint の警告を解消した（package-lint は 17 件から 5 件）
