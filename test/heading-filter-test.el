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


;;; Tests for heading range detection

;;; Tests for line in heading range


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
