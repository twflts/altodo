# フィルタ機能テスト仕様書

## 作成日時

2026-02-21 13:42 JST


## テスト対象

基本フィルタリング機能


## テスト環境

- Emacs: batch mode
- タイムアウト: 10 秒
- テストフレームワーク: ERT (Emacs Lisp Regression Testing)


## テストファイル

**`test/fixtures/filter-test.altodo`**:

```
[ ] タスク1 #tag1 @person1
[x] タスク2 #tag2 @person2
[@] タスク3 #tag1 ! -> 2026-01-01
[w] タスク4 #tag3 @person1 -> 2026-12-31
[ ] タスク5 ! + #important

# コメント行

[x] タスク6 -> 2025-01-01
[@] タスク7 #tag2 !!
```


## 単体テスト

### 1. `altodo--find-matching-lines`

**目的**: predicate に合致する行の範囲を取得

**テストケース 1-1**: done タスクを検索

**入力**:
```elisp
(altodo--find-matching-lines #'altodo--test-predicate-done)
```

**期待結果**:
- 2 つの範囲が返る
- タスク 2（`[x] タスク2 ...`）の範囲
- タスク 6（`[x] タスク6 ...`）の範囲

**テストケース 1-2**: progress タスクを検索

**入力**:
```elisp
(altodo--find-matching-lines #'altodo--test-predicate-progress)
```

**期待結果**:
- 2 つの範囲が返る
- タスク 3（`[@] タスク3 ...`）の範囲
- タスク 7（`[@] タスク7 ...`）の範囲

**テストケース 1-3**: 空のバッファ

**入力**:
```elisp
(with-temp-buffer
  (altodo--find-matching-lines #'altodo--test-predicate-done))
```

**期待結果**:
- 空のリスト `nil`
- エラーなし


### 2. `altodo--invert-ranges`

**目的**: 範囲を反転して非マッチング範囲を取得

**テストケース 2-1**: 2 つの範囲を反転

**入力**:
```elisp
;; バッファ: "line1\nline2\nline3\nline4\n"
;; 範囲: line2 と line4
(altodo--invert-ranges '((7 . 13) (20 . 26)))
```

**期待結果**:
- 3 つの範囲が返る
- line1 の範囲（`(1 . 7)`）
- line3 の範囲（`(13 . 20)`）
- EOF までの範囲（`(26 . point-max)`）

**テストケース 2-2**: 空の範囲

**入力**:
```elisp
(altodo--invert-ranges nil)
```

**期待結果**:
- 1 つの範囲が返る
- バッファ全体（`(point-min . point-max)`）

**テストケース 2-3**: バッファ全体がマッチ

**入力**:
```elisp
(altodo--invert-ranges '((1 . point-max)))
```

**期待結果**:
- 空のリスト `nil`


### 3. `altodo--create-overlays`

**目的**: 範囲に対して overlay を作成

**テストケース 3-1**: 2 つの範囲に overlay を作成

**入力**:
```elisp
(altodo--create-overlays '((1 . 7) (13 . 19)))
```

**期待結果**:
- 2 つの overlay が返る
- 各 overlay に `invisible` プロパティが設定されている（値: `'altodo-filter`）
- 各 overlay に `evaporate` プロパティが設定されている（値: `t`）

**テストケース 3-2**: 空の範囲

**入力**:
```elisp
(altodo--create-overlays nil)
```

**期待結果**:
- 空のリスト `nil`


## 結合テスト

### 4. `altodo--filter-lines`

**目的**: フィルタを適用して非マッチング行を非表示

**テストケース 4-1**: done タスクのみ表示

**入力**:
```elisp
(altodo--filter-lines #'altodo--test-predicate-done 'done)
```

**期待結果**:
- `altodo--filter-overlays` に overlay が設定されている
- `altodo--filter-mode` が `'done`
- done タスク以外の行に overlay が作成されている

**テストケース 4-2**: progress タスクのみ表示

**入力**:
```elisp
(altodo--filter-lines #'altodo--test-predicate-progress 'progress)
```

**期待結果**:
- `altodo--filter-overlays` に overlay が設定されている
- `altodo--filter-mode` が `'progress`
- progress タスク以外の行に overlay が作成されている


### 5. `altodo--filter-clear`

**目的**: フィルタをクリア

**テストケース 5-1**: フィルタ適用後にクリア

**入力**:
```elisp
(altodo--filter-lines #'altodo--test-predicate-done 'done)
(altodo--filter-clear)
```

**期待結果**:
- `altodo--filter-overlays` が `nil`
- `altodo--filter-mode` が `nil`
- 全ての overlay が削除されている

**テストケース 5-2**: フィルタ未適用時にクリア

**入力**:
```elisp
(altodo--filter-clear)
```

**期待結果**:
- エラーなし
- `altodo--filter-overlays` が `nil`
- `altodo--filter-mode` が `nil`


### 6. 初期化・終了処理

**テストケース 6-1**: 初期化

**入力**:
```elisp
(altodo--filter-init)
```

**期待結果**:
- `buffer-invisibility-spec` に `'altodo-filter` が追加されている

**テストケース 6-2**: 終了処理

**入力**:
```elisp
(altodo--filter-init)
(altodo--filter-lines #'altodo--test-predicate-done 'done)
(altodo--filter-cleanup)
```

**期待結果**:
- `altodo--filter-overlays` が `nil`
- `altodo--filter-mode` が `nil`
- `buffer-invisibility-spec` から `'altodo-filter` が削除されている


## predicate 関数テスト

### 7. `altodo--test-predicate-done`

**テストケース 7-1**: done タスク

**入力**: `[x] task`

**期待結果**: `t`

**テストケース 7-2**: done 以外

**入力**: `[ ] task`

**期待結果**: `nil`


### 8. `altodo--test-predicate-progress`

**テストケース 8-1**: progress タスク

**入力**: `[@] task`

**期待結果**: `t`

**テストケース 8-2**: progress 以外

**入力**: `[ ] task`

**期待結果**: `nil`


### 9. `altodo--test-predicate-tag`

**テストケース 9-1**: タグあり

**入力**: `[ ] task #tag1`

**期待結果**: `t`（tag="tag1"）

**テストケース 9-2**: タグなし

**入力**: `[ ] task`

**期待結果**: `nil`（tag="tag1"）

**テストケース 9-3**: 別のタグ

**入力**: `[ ] task #tag2`

**期待結果**: `nil`（tag="tag1"）


### 10. `altodo--test-predicate-priority`

**テストケース 10-1**: 優先度あり

**入力**: `[ ] task !`

**期待結果**: `t`

**テストケース 10-2**: 優先度なし

**入力**: `[ ] task`

**期待結果**: `nil`


## テスト実行方法

```bash
# 構文チェック
timeout 5 emacs --batch -l ./altodo/altodo.el

# テスト実行
timeout 10 emacs --batch -l ./altodo/test/test-filter.el
```


## 成功基準

- 全てのテストケースが通る
- タイムアウトしない
- 構文エラーがない
- エラーメッセージが出ない


## テスト結果の記録

各テスト実行後、以下を記録：

- 実行日時
- 成功/失敗
- 失敗した場合のエラーメッセージ
- 実行時間
