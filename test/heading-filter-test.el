;;; heading-filter-test.el --- Tests for heading filter functionality

(require 'ert)
(require 'altodo)

;;; Test data setup

(defun heading-test-setup ()
  "Create test buffer with heading structure."
  (with-temp-buffer
    (insert "# プロジェクト全体 進捗管理\n")
    (insert "全体の説明\n")
    (insert "\n")
    (insert "## プロジェクト A\n")
    (insert "[ ] タスク A1\n")
    (insert "[ ] タスク A2\n")
    (insert "\n")
    (insert "### プロジェクト A 要件定義\n")
    (insert "[x] タスク A1-1\n")
    (insert "[x] タスク A1-2\n")
    (insert "\n")
    (insert "### プロジェクト A 基本設計\n")
    (insert "[@] タスク A2-1\n")
    (insert "[@] タスク A2-2\n")
    (insert "\n")
    (insert "## プロジェクト B\n")
    (insert "[w] タスク B1\n")
    (insert "[w] タスク B2\n")
    (insert "\n")
    (insert "### プロジェクト B 要件定義\n")
    (insert "[~] タスク B1-1\n")
    (insert "[~] タスク B1-2\n")
    (current-buffer)))

;;; Tests for heading level detection

(ert-deftest heading-test-heading-level ()
  "Test altodo--heading-level function."
  (with-temp-buffer
    (insert "# Level 1\n")
    (insert "## Level 2\n")
    (insert "### Level 3\n")
    (insert "[ ] Task\n")
    
    (goto-char (point-min))
    (should (= (altodo--heading-level) 1))
    
    (forward-line 1)
    (should (= (altodo--heading-level) 2))
    
    (forward-line 1)
    (should (= (altodo--heading-level) 3))
    
    (forward-line 1)
    (should (null (altodo--heading-level)))))

(ert-deftest heading-test-heading-text ()
  "Test altodo--heading-text function."
  (with-temp-buffer
    (insert "# プロジェクト全体\n")
    (insert "## プロジェクト A\n")
    (insert "[ ] Task\n")
    
    (goto-char (point-min))
    (should (string= (altodo--heading-text) "プロジェクト全体"))
    
    (forward-line 1)
    (should (string= (altodo--heading-text) "プロジェクト A"))
    
    (forward-line 1)
    (should (null (altodo--heading-text)))))

;;; Tests for heading range detection

(ert-deftest heading-test-find-heading-range-basic ()
  "Test altodo--find-heading-range with basic structure."
  (with-temp-buffer
    (insert "# プロジェクト全体\n")
    (insert "説明\n")
    (insert "## プロジェクト A\n")
    (insert "[ ] タスク A1\n")
    (insert "## プロジェクト B\n")
    (insert "[ ] タスク B1\n")
    
    (goto-char (point-min))
    (let ((range (altodo--find-heading-range "プロジェクト A")))
      (should range)
      ;; Start should be after "## プロジェクト A\n"
      (should (> (car range) (point-min)))
      ;; End should be before "## プロジェクト B"
      (should (< (cdr range) (point-max))))))

(ert-deftest heading-test-find-heading-range-with-children ()
  "Test altodo--find-heading-range with child headings."
  (with-temp-buffer
    (insert "## プロジェクト A\n")
    (insert "[ ] タスク A1\n")
    (insert "### 要件定義\n")
    (insert "[x] タスク A1-1\n")
    (insert "### 基本設計\n")
    (insert "[x] タスク A1-2\n")
    (insert "## プロジェクト B\n")
    (insert "[ ] タスク B1\n")
    
    (goto-char (point-min))
    ;; With include-children = t
    (let ((range (altodo--find-heading-range "プロジェクト A" t)))
      (should range)
      ;; Range should include child headings
      (goto-char (car range))
      (forward-line 2)  ; Skip to "### 要件定義"
      (should (< (point) (cdr range))))
    
    ;; With include-children = nil
    (let ((range (altodo--find-heading-range "プロジェクト A" nil)))
      (should range)
      ;; Range should stop at first child heading
      (goto-char (car range))
      (forward-line 2)  ; Skip to "### 要件定義"
      (should (>= (point) (cdr range))))))

(ert-deftest heading-test-find-heading-range-not-found ()
  "Test altodo--find-heading-range when heading not found."
  (with-temp-buffer
    (insert "## プロジェクト A\n")
    (insert "[ ] タスク A1\n")
    
    (goto-char (point-min))
    (let ((range (altodo--find-heading-range "存在しない見出し")))
      (should (null range)))))

;;; Tests for line in heading range

(ert-deftest heading-test-line-in-heading-range-p ()
  "Test altodo--line-in-heading-range-p function."
  (with-temp-buffer
    (insert "## プロジェクト A\n")
    (insert "[ ] タスク A1\n")
    (insert "[ ] タスク A2\n")
    (insert "## プロジェクト B\n")
    (insert "[ ] タスク B1\n")
    
    ;; Line in range
    (goto-char (point-min))
    (forward-line 1)  ; "[ ] タスク A1"
    (should (altodo--line-in-heading-range-p "プロジェクト A"))
    
    ;; Line in range
    (forward-line 1)  ; "[ ] タスク A2"
    (should (altodo--line-in-heading-range-p "プロジェクト A"))
    
    ;; Line not in range
    (forward-line 2)  ; "[ ] タスク B1"
    (should (null (altodo--line-in-heading-range-p "プロジェクト A")))))

;;; Tests for heading range with filter options

(ert-deftest heading-test-line-in-heading-range-with-filter-all ()
  "Test altodo--line-in-heading-range-with-filter-p with 'all option."
  (with-temp-buffer
    (insert "## プロジェクト A\n")
    (insert "説明文\n")
    (insert "[ ] タスク A1\n")
    (insert "## プロジェクト B\n")
    
    ;; Body text should be shown with 'all
    (goto-char (point-min))
    (forward-line 1)  ; "説明文"
    (should (altodo--line-in-heading-range-with-filter-p "プロジェクト A" t 'all))
    
    ;; Task line should be shown with 'all
    (forward-line 1)  ; "[ ] タスク A1"
    (should (altodo--line-in-heading-range-with-filter-p "プロジェクト A" t 'all))))

(ert-deftest heading-test-line-in-heading-range-with-filter-all-without-heading ()
  "Test altodo--line-in-heading-range-with-filter-p with 'all-without-heading-line option."
  (with-temp-buffer
    (insert "## プロジェクト A\n")
    (insert "説明文\n")
    (insert "[ ] タスク A1\n")
    (insert "## プロジェクト B\n")
    
    ;; Heading line should NOT be shown
    (goto-char (point-min))
    (should (null (altodo--line-in-heading-range-with-filter-p "プロジェクト A" t 'all-without-heading-line)))
    
    ;; Body text should be shown
    (forward-line 1)
    (should (altodo--line-in-heading-range-with-filter-p "プロジェクト A" t 'all-without-heading-line))
    
    ;; Task line should be shown
    (forward-line 1)
    (should (altodo--line-in-heading-range-with-filter-p "プロジェクト A" t 'all-without-heading-line))))

(ert-deftest heading-test-line-in-heading-range-with-filter-only-tasks ()
  "Test altodo--line-in-heading-range-with-filter-p with 'only-tasks option."
  (with-temp-buffer
    (insert "## プロジェクト A\n")
    (insert "説明文\n")
    (insert "[ ] タスク A1\n")
    (insert "## プロジェクト B\n")
    
    ;; Heading line should NOT be shown with 'only-tasks
    (goto-char (point-min))
    (should (null (altodo--line-in-heading-range-with-filter-p "プロジェクト A" t 'only-tasks)))
    
    ;; Body text should NOT be shown with 'only-tasks
    (forward-line 1)
    (should (null (altodo--line-in-heading-range-with-filter-p "プロジェクト A" t 'only-tasks)))
    
    ;; Task line should be shown with 'only-tasks
    (forward-line 1)
    (should (altodo--line-in-heading-range-with-filter-p "プロジェクト A" t 'only-tasks))))

(ert-deftest heading-test-line-in-heading-range-with-filter-only-tasks-without-heading ()
  "Test altodo--line-in-heading-range-with-filter-p with 'only-tasks-without-heading-line option."
  (with-temp-buffer
    (insert "## プロジェクト A\n")
    (insert "説明文\n")
    (insert "[ ] タスク A1\n")
    (insert "## プロジェクト B\n")
    
    ;; Heading line should NOT be shown
    (goto-char (point-min))
    (should (null (altodo--line-in-heading-range-with-filter-p "プロジェクト A" t 'only-tasks-without-heading-line)))
    
    ;; Body text should NOT be shown
    (forward-line 1)
    (should (null (altodo--line-in-heading-range-with-filter-p "プロジェクト A" t 'only-tasks-without-heading-line)))
    
    ;; Task line should be shown
    (forward-line 1)
    (should (altodo--line-in-heading-range-with-filter-p "プロジェクト A" t 'only-tasks-without-heading-line))))

;;; Tests for complex scenarios

(ert-deftest heading-test-nested-headings-include-children-true ()
  "Test nested headings with include-children = t."
  (with-temp-buffer
    (insert "## プロジェクト A\n")
    (insert "[ ] タスク A1\n")
    (insert "### 要件定義\n")
    (insert "[x] タスク A1-1\n")
    (insert "### 基本設計\n")
    (insert "[x] タスク A1-2\n")
    (insert "## プロジェクト B\n")
    (insert "[ ] タスク B1\n")
    
    (goto-char (point-min))
    ;; All lines under プロジェクト A should be in range
    (forward-line 1)  ; [ ] タスク A1
    (should (altodo--line-in-heading-range-p "プロジェクト A" t))
    
    (forward-line 1)  ; ### 要件定義
    (should (altodo--line-in-heading-range-p "プロジェクト A" t))
    
    (forward-line 1)  ; [x] タスク A1-1
    (should (altodo--line-in-heading-range-p "プロジェクト A" t))
    
    (forward-line 1)  ; ### 基本設計
    (should (altodo--line-in-heading-range-p "プロジェクト A" t))
    
    (forward-line 1)  ; [x] タスク A1-2
    (should (altodo--line-in-heading-range-p "プロジェクト A" t))
    
    ;; Line under プロジェクト B should NOT be in range
    (forward-line 1)  ; ## プロジェクト B
    (should (null (altodo--line-in-heading-range-p "プロジェクト A" t)))))

(ert-deftest heading-test-nested-headings-include-children-false ()
  "Test nested headings with include-children = nil."
  (with-temp-buffer
    (insert "## プロジェクト A\n")
    (insert "[ ] タスク A1\n")
    (insert "### 要件定義\n")
    (insert "[x] タスク A1-1\n")
    (insert "## プロジェクト B\n")
    
    (goto-char (point-min))
    ;; Task under プロジェクト A should be in range
    (forward-line 1)  ; [ ] タスク A1
    (should (altodo--line-in-heading-range-p "プロジェクト A" nil))
    
    ;; Child heading should NOT be in range
    (forward-line 1)  ; ### 要件定義
    (should (null (altodo--line-in-heading-range-p "プロジェクト A" nil)))))

(ert-deftest heading-test-regex-matching ()
  "Test heading matching with regex patterns."
  (with-temp-buffer
    (insert "## プロジェクト A\n")
    (insert "[ ] タスク A1\n")
    (insert "## プロジェクト B\n")
    (insert "[ ] タスク B1\n")
    
    (goto-char (point-min))
    ;; Exact match
    (forward-line 1)
    (should (altodo--line-in-heading-range-p "プロジェクト A"))
    
    ;; Regex match
    (should (altodo--line-in-heading-range-p "プロジェクト.*"))
    
    ;; Regex match with anchor (note: $ is added by find-heading-range)
    (should (altodo--line-in-heading-range-p "プロジェクト A"))
    
    ;; No match
    (should (null (altodo--line-in-heading-range-p "存在しない")))))

(ert-deftest heading-test-dsl-compile-heading ()
  "Test DSL compilation for heading pattern."
  (with-temp-buffer
    (insert "## プロジェクト A\n")
    (insert "[ ] タスク A1\n")
    (insert "## プロジェクト B\n")
    (insert "[ ] タスク B1\n")
    
    ;; Compile heading pattern (as string, not s-expr)
    (let ((pred (altodo--compile-simple-pattern "heading:プロジェクト A")))
      (should (functionp pred))
      
      ;; Test predicate on task under プロジェクト A
      (goto-char (point-min))
      (forward-line 1)  ; "[ ] タスク A1"
      (should (funcall pred))
      
      ;; Test predicate on task under プロジェクト B
      (forward-line 2)  ; "[ ] タスク B1"
      (should (null (funcall pred))))))

(ert-deftest heading-test-dsl-compile-heading-with-options ()
  "Test DSL compilation for heading pattern with options."
  (with-temp-buffer
    (insert "## プロジェクト A\n")
    (insert "説明\n")
    (insert "[ ] タスク A1\n")
    
    ;; Compile heading pattern (as string)
    (let ((pred (altodo--compile-simple-pattern "heading:プロジェクト A")))
      (should (functionp pred))
      
      ;; Body text should NOT be shown (default: only-tasks)
      (goto-char (point-min))
      (forward-line 1)  ; "説明"
      (should (null (funcall pred)))
      
      ;; Task line should be shown
      (forward-line 1)  ; "[ ] タスク A1"
      (should (funcall pred)))))

(provide 'heading-filter-test)
;;; heading-filter-test.el ends here
