;;; parent-task-regexp-test.el --- Tests for parent task regexp filter -*- lexical-binding: t; -*-

(require 'ert)
(load-file "altodo.el")

;;; Helper Functions Tests

(ert-deftest test-parent-task-matches-simple ()
  "Test parent task matches simple pattern."
  (with-temp-buffer
    (insert "[ ] Parent task\n")
    (insert "    [ ] Child task\n")
    (goto-char (point-min))
    (forward-line 1)
    (should (altodo--line-parent-task-matches-regexp-p "Parent"))))

(ert-deftest test-parent-task-matches-regexp ()
  "Test parent task matches regexp pattern."
  (with-temp-buffer
    (insert "[ ] プロジェクト A\n")
    (insert "    [ ] 実装タスク\n")
    (goto-char (point-min))
    (forward-line 1)
    (should (altodo--line-parent-task-matches-regexp-p "プロジェクト"))
    (should (altodo--line-parent-task-matches-regexp-p ".*A$"))))

(ert-deftest test-parent-task-no-match ()
  "Test parent task does not match."
  (with-temp-buffer
    (insert "[ ] Parent task\n")
    (insert "    [ ] Child task\n")
    (goto-char (point-min))
    (forward-line 1)
    (should-not (altodo--line-parent-task-matches-regexp-p "NoMatch"))))

(ert-deftest test-parent-task-top-level ()
  "Test top-level task has no parent."
  (with-temp-buffer
    (insert "[ ] Top level task\n")
    (goto-char (point-min))
    (should-not (altodo--line-parent-task-matches-regexp-p "Parent"))))

(ert-deftest test-parent-task-multiline-comment ()
  "Test parent task with multiline comment."
  (with-temp-buffer
    (insert "[ ] Parent task\n")
    (insert "    Multiline comment\n")
    (insert "    [ ] Child task\n")
    (goto-char (point-min))
    (forward-line 2)
    (should (altodo--line-parent-task-matches-regexp-p "Parent"))))

(ert-deftest test-root-parent-task-matches ()
  "Test root parent task matches."
  (with-temp-buffer
    (insert "[ ] Root task\n")
    (insert "    [ ] Child task\n")
    (insert "        [ ] Grandchild task\n")
    (goto-char (point-min))
    (forward-line 2)
    (should (altodo--line-root-parent-task-matches-regexp-p "Root"))))

(ert-deftest test-root-parent-task-no-match ()
  "Test root parent task does not match."
  (with-temp-buffer
    (insert "[ ] Root task\n")
    (insert "    [ ] Child task\n")
    (goto-char (point-min))
    (forward-line 1)
    (should-not (altodo--line-root-parent-task-matches-regexp-p "NoMatch"))))

(ert-deftest test-root-parent-task-top-level ()
  "Test top-level task has no root parent."
  (with-temp-buffer
    (insert "[ ] Top level task\n")
    (goto-char (point-min))
    (should-not (altodo--line-root-parent-task-matches-regexp-p "Root"))))

(ert-deftest test-root-parent-task-nested ()
  "Test root parent task with deep nesting."
  (with-temp-buffer
    (insert "[ ] Root task\n")
    (insert "    [ ] Level 1\n")
    (insert "        [ ] Level 2\n")
    (insert "            [ ] Level 3\n")
    (goto-char (point-min))
    (forward-line 3)
    (should (altodo--line-root-parent-task-matches-regexp-p "Root"))))

(ert-deftest test-parent-task-multiple-siblings ()
  "Test parent task with multiple siblings."
  (with-temp-buffer
    (insert "[ ] Parent A\n")
    (insert "    [ ] Child A1\n")
    (insert "    [ ] Child A2\n")
    (insert "[ ] Parent B\n")
    (insert "    [ ] Child B1\n")
    (goto-char (point-min))
    (forward-line 1)
    (should (altodo--line-parent-task-matches-regexp-p "Parent A"))
    (forward-line 1)
    (should (altodo--line-parent-task-matches-regexp-p "Parent A"))
    (forward-line 2)
    (should (altodo--line-parent-task-matches-regexp-p "Parent B"))))

;;; DSL Integration Tests

(ert-deftest test-dsl-arg-types-includes-parent-task-regexp ()
  "Test that parent-task-regexp is in DSL arg types."
  (should (member "parent-task-regexp" altodo--dsl-arg-types))
  (should (member "root-task-regexp" altodo--dsl-arg-types)))

(ert-deftest test-compile-parent-task-regexp ()
  "Test compiling parent-task-regexp pattern."
  (let ((pred (altodo--compile-simple-pattern "parent-task-regexp:Parent")))
    (with-temp-buffer
      (insert "[ ] Parent task\n")
      (insert "    [ ] Child task\n")
      (goto-char (point-min))
      (forward-line 1)
      (should (funcall pred)))))

(ert-deftest test-compile-root-task-regexp ()
  "Test compiling root-task-regexp pattern."
  (let ((pred (altodo--compile-simple-pattern "root-task-regexp:Root")))
    (with-temp-buffer
      (insert "[ ] Root task\n")
      (insert "    [ ] Child task\n")
      (goto-char (point-min))
      (forward-line 1)
      (should (funcall pred)))))

(ert-deftest test-compile-parent-task-regexp-no-match ()
  "Test compiling parent-task-regexp with no match."
  (let ((pred (altodo--compile-simple-pattern "parent-task-regexp:NoMatch")))
    (with-temp-buffer
      (insert "[ ] Parent task\n")
      (insert "    [ ] Child task\n")
      (goto-char (point-min))
      (forward-line 1)
      (should-not (funcall pred)))))

;;; Filter Execution Tests

(ert-deftest test-filter-parent-task-regexp ()
  "Test filter execution with parent-task-regexp."
  (with-temp-buffer
    (insert "[ ] Project A\n")
    (insert "    [ ] Task 1\n")
    (insert "    [ ] Task 2\n")
    (insert "[ ] Project B\n")
    (insert "    [ ] Task 3\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "parent-task-regexp:Project A")))
      (altodo--filter-lines pred)
      ;; Project A and its children should be visible
      (goto-char (point-min))
      (should-not (invisible-p (point)))  ; Project A visible
      (forward-line 1)
      (should-not (invisible-p (point)))  ; Task 1 visible
      (forward-line 1)
      (should-not (invisible-p (point)))  ; Task 2 visible
      (forward-line 1)
      (should (invisible-p (point)))  ; Project B hidden
      (forward-line 1)
      (should (invisible-p (point))))))  ; Task 3 hidden

(ert-deftest test-filter-root-task-regexp ()
  "Test filter execution with root-task-regexp."
  (with-temp-buffer
    (insert "[ ] Root A\n")
    (insert "    [ ] Child A1\n")
    (insert "        [ ] Grandchild A1\n")
    (insert "[ ] Root B\n")
    (insert "    [ ] Child B1\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "root-task-regexp:Root A")))
      (altodo--filter-lines pred)
      ;; Root A and all descendants should be visible
      (goto-char (point-min))
      (should-not (invisible-p (point)))  ; Root A visible
      (forward-line 1)
      (should-not (invisible-p (point)))  ; Child A1 visible
      (forward-line 1)
      (should-not (invisible-p (point)))  ; Grandchild A1 visible
      (forward-line 1)
      (should (invisible-p (point)))  ; Root B hidden
      (forward-line 1)
      (should (invisible-p (point))))))  ; Child B1 hidden

(ert-deftest test-filter-parent-task-regexp-with-and ()
  "Test filter with parent-task-regexp AND condition."
  (with-temp-buffer
    (insert "[ ] Project A\n")
    (insert "    [x] Done task\n")
    (insert "    [ ] Open task\n")
    (insert "[ ] Project B\n")
    (insert "    [x] Done task\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "and:parent-task-regexp:Project A,done")))
      (altodo--filter-lines pred)
      ;; Only done tasks under Project A should be visible (Project A hidden because not done)
      (goto-char (point-min))
      (should (invisible-p (point)))  ; Project A hidden (not done)
      (forward-line 1)
      (should-not (invisible-p (point)))  ; Done task visible
      (forward-line 1)
      (should (invisible-p (point)))  ; Open task hidden
      (forward-line 1)
      (should (invisible-p (point)))  ; Project B hidden
      (forward-line 1)
      (should (invisible-p (point))))))  ; Done task hidden

;;; Complex Conditions Tests

(ert-deftest test-complex-nested-hierarchy ()
  "Test complex nested hierarchy with multiple levels."
  (with-temp-buffer
    (insert "[ ] Root Project\n")
    (insert "    [ ] Phase 1\n")
    (insert "        [ ] Task 1-1\n")
    (insert "        [ ] Task 1-2\n")
    (insert "    [ ] Phase 2\n")
    (insert "        [ ] Task 2-1\n")
    (goto-char (point-min))
    ;; Test Task 1-1 parent
    (forward-line 2)
    (should (altodo--line-parent-task-matches-regexp-p "Phase 1"))
    (should-not (altodo--line-parent-task-matches-regexp-p "Phase 2"))
    ;; Test Task 1-1 root
    (should (altodo--line-root-parent-task-matches-regexp-p "Root"))
    ;; Test Task 2-1 parent
    (goto-char (point-min))
    (forward-line 5)
    (should (altodo--line-parent-task-matches-regexp-p "Phase 2"))
    (should-not (altodo--line-parent-task-matches-regexp-p "Phase 1"))))

(ert-deftest test-complex-mixed-states ()
  "Test parent task regexp with mixed task states."
  (with-temp-buffer
    (insert "[ ] Open Parent\n")
    (insert "    [x] Done Child\n")
    (insert "    [@] Progress Child\n")
    (insert "    [ ] Open Child\n")
    (goto-char (point-min))
    (forward-line 1)
    (should (altodo--line-parent-task-matches-regexp-p "Open"))
    (forward-line 1)
    (should (altodo--line-parent-task-matches-regexp-p "Open"))
    (forward-line 1)
    (should (altodo--line-parent-task-matches-regexp-p "Open"))))

(ert-deftest test-complex-with-tags ()
  "Test parent task regexp with tags."
  (with-temp-buffer
    (insert "[ ] Parent #project:alpha\n")
    (insert "    [ ] Child #priority:high\n")
    (goto-char (point-min))
    (forward-line 1)
    (should (altodo--line-parent-task-matches-regexp-p "Parent"))
    (should (altodo--line-parent-task-matches-regexp-p "#project"))))

(ert-deftest test-complex-or-condition ()
  "Test parent task regexp with OR condition."
  (with-temp-buffer
    (insert "[ ] Project A\n")
    (insert "    [ ] Task A1\n")
    (insert "[ ] Project B\n")
    (insert "    [ ] Task B1\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "or:parent-task-regexp:Project A,parent-task-regexp:Project B")))
      (altodo--filter-lines pred)
      ;; Project A, Task A1, Project B, Task B1 should all be visible
      (goto-char (point-min))
      (should-not (invisible-p (point)))  ; Project A visible
      (forward-line 1)
      (should-not (invisible-p (point)))  ; Task A1 visible
      (forward-line 1)
      (should-not (invisible-p (point)))  ; Project B visible
      (forward-line 1)
      (should-not (invisible-p (point))))))  ; Task B1 visible

(ert-deftest test-complex-root-with-and ()
  "Test root task regexp with AND condition."
  (with-temp-buffer
    (insert "[ ] Root A\n")
    (insert "    [x] Done task\n")
    (insert "    [ ] Open task\n")
    (insert "[ ] Root B\n")
    (insert "    [x] Done task\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "and:root-task-regexp:Root A,done")))
      (altodo--filter-lines pred)
      ;; Only done tasks under Root A should be visible (Root A hidden because not done)
      (goto-char (point-min))
      (should (invisible-p (point)))  ; Root A hidden (not done)
      (forward-line 1)
      (should-not (invisible-p (point)))  ; Done task visible
      (forward-line 1)
      (should (invisible-p (point)))  ; Open task hidden
      (forward-line 1)
      (should (invisible-p (point)))  ; Root B hidden
      (forward-line 1)
      (should (invisible-p (point))))))  ; Done task hidden

(ert-deftest test-complex-parent-with-priority ()
  "Test parent task regexp with priority flag."
  (with-temp-buffer
    (insert "[ ] Important Project\n")
    (insert "    [ ] ! High priority task\n")
    (insert "    [ ] Normal task\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "and:parent-task-regexp:Important,priority")))
      (altodo--filter-lines pred)
      ;; Only priority tasks under Important Project should be visible
      (goto-char (point-min))
      (should (invisible-p (point)))  ; Important Project hidden
      (forward-line 1)
      (should-not (invisible-p (point)))  ; High priority task visible
      (forward-line 1)
      (should (invisible-p (point))))))  ; Normal task hidden

(ert-deftest test-complex-deep-nesting-5-levels ()
  "Test deep nesting with 5 levels."
  (with-temp-buffer
    (insert "[ ] Level 0\n")
    (insert "    [ ] Level 1\n")
    (insert "        [ ] Level 2\n")
    (insert "            [ ] Level 3\n")
    (insert "                [ ] Level 4\n")
    (goto-char (point-min))
    (forward-line 4)
    (should (altodo--line-root-parent-task-matches-regexp-p "Level 0"))
    (should-not (altodo--line-root-parent-task-matches-regexp-p "Level 1"))))

(ert-deftest test-complex-multiple-roots ()
  "Test multiple root tasks."
  (with-temp-buffer
    (insert "[ ] Root 1\n")
    (insert "    [ ] Child 1\n")
    (insert "[ ] Root 2\n")
    (insert "    [ ] Child 2\n")
    (insert "[ ] Root 3\n")
    (insert "    [ ] Child 3\n")
    (goto-char (point-min))
    (forward-line 1)
    (should (altodo--line-root-parent-task-matches-regexp-p "Root 1"))
    (forward-line 2)
    (should (altodo--line-root-parent-task-matches-regexp-p "Root 2"))
    (forward-line 2)
    (should (altodo--line-root-parent-task-matches-regexp-p "Root 3"))))

(ert-deftest test-complex-parent-with-multiline-comments ()
  "Test parent task with multiline comments between parent and child."
  (with-temp-buffer
    (insert "[ ] Parent Task\n")
    (insert "    Multiline comment line 1\n")
    (insert "    Multiline comment line 2\n")
    (insert "    [ ] Child Task\n")
    (goto-char (point-min))
    (forward-line 3)
    (should (altodo--line-parent-task-matches-regexp-p "Parent"))))

(ert-deftest test-complex-not-condition ()
  "Test parent task regexp with NOT condition."
  (with-temp-buffer
    (insert "[ ] Project A\n")
    (insert "    [ ] Task A1\n")
    (insert "[ ] Project B\n")
    (insert "    [ ] Task B1\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "not:parent-task-regexp:Project A")))
      (altodo--filter-lines pred)
      ;; Project A and Task A1 should be hidden, Project B and Task B1 should be visible
      (goto-char (point-min))
      (should (invisible-p (point)))  ; Project A hidden (matches regexp)
      (forward-line 1)
      (should (invisible-p (point)))  ; Task A1 hidden
      (forward-line 1)
      (should-not (invisible-p (point)))  ; Project B visible
      (forward-line 1)
      (should-not (invisible-p (point))))))  ; Task B1 visible

;; Advanced complex condition tests
(ert-deftest test-advanced-nested-and-or ()
  "Test nested AND/OR with parent-task-regexp and tags."
  (with-temp-buffer
    (insert "[ ] Backend #team:backend\n")
    (insert "    [x] API done #priority:high\n")
    (insert "    [ ] DB open #priority:low\n")
    (insert "[ ] Frontend #team:frontend\n")
    (insert "    [x] UI done #priority:high\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "and:or:parent-task-regexp:Backend,parent-task-regexp:Frontend,done,tag:priority")))
      (altodo--filter-lines pred)
      ;; Only done tasks with priority tag under Backend or Frontend (parents visible, DB open visible because has priority tag)
      (goto-char (point-min))
      (should-not (invisible-p (point)))  ; Backend visible (matches OR)
      (forward-line 1)
      (should-not (invisible-p (point)))  ; API done visible
      (forward-line 1)
      (should-not (invisible-p (point)))  ; DB open visible (has priority tag)
      (forward-line 1)
      (should-not (invisible-p (point)))  ; Frontend visible (matches OR)
      (forward-line 1)
      (should-not (invisible-p (point))))))  ; UI done visible

(ert-deftest test-advanced-root-with-multiple-levels ()
  "Test root-task-regexp with deeply nested hierarchy."
  (with-temp-buffer
    (insert "[ ] Root Alpha\n")
    (insert "    [ ] Level 1\n")
    (insert "        [ ] Level 2\n")
    (insert "            [x] Level 3 done\n")
    (insert "[ ] Root Beta\n")
    (insert "    [ ] Level 1\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "and:root-task-regexp:Alpha,done")))
      (altodo--filter-lines pred)
      ;; Only done tasks under Root Alpha
      (goto-char (point-min))
      (should (invisible-p (point)))  ; Root Alpha hidden
      (forward-line 1)
      (should (invisible-p (point)))  ; Level 1 hidden
      (forward-line 1)
      (should (invisible-p (point)))  ; Level 2 hidden
      (forward-line 1)
      (should-not (invisible-p (point)))  ; Level 3 done visible
      (forward-line 1)
      (should (invisible-p (point)))  ; Root Beta hidden
      (forward-line 1)
      (should (invisible-p (point))))))  ; Level 1 hidden

(ert-deftest test-advanced-parent-with-tag-value ()
  "Test parent-task-regexp with tag-value filter."
  (with-temp-buffer
    (insert "[ ] Sprint #sprint:5\n")
    (insert "    [ ] Task A #points:3\n")
    (insert "    [ ] Task B #points:8\n")
    (insert "[ ] Sprint #sprint:6\n")
    (insert "    [ ] Task C #points:5\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "and:parent-task-regexp:Sprint,tag-value:points (> 2)")))
      (altodo--filter-lines pred)
      ;; Only tasks with points > 2 under Sprint (any sprint)
      (goto-char (point-min))
      (should (invisible-p (point)))  ; Sprint 5 hidden (no points tag)
      (forward-line 1)
      (should-not (invisible-p (point)))  ; Task A visible (points:3)
      (forward-line 1)
      (should-not (invisible-p (point)))  ; Task B visible (points:8)
      (forward-line 1)
      (should (invisible-p (point)))  ; Sprint 6 hidden (no points tag)
      (forward-line 1)
      (should-not (invisible-p (point))))))  ; Task C visible (points:5)

(ert-deftest test-advanced-not-with-and ()
  "Test NOT with AND condition on parent-task-regexp."
  (with-temp-buffer
    (insert "[ ] Project X\n")
    (insert "    [x] Done task\n")
    (insert "    [ ] Open task\n")
    (insert "[ ] Project Y\n")
    (insert "    [x] Done task\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "and:not:parent-task-regexp:Project X,done")))
      (altodo--filter-lines pred)
      ;; Only done tasks NOT under Project X (Project Y visible because matches NOT condition)
      (goto-char (point-min))
      (should (invisible-p (point)))  ; Project X hidden
      (forward-line 1)
      (should (invisible-p (point)))  ; Done task hidden
      (forward-line 1)
      (should (invisible-p (point)))  ; Open task hidden
      (forward-line 1)
      (should-not (invisible-p (point)))  ; Project Y visible (matches NOT condition)
      (forward-line 1)
      (should-not (invisible-p (point))))))  ; Done task visible

(ert-deftest test-advanced-multiple-parent-regexp ()
  "Test multiple parent-task-regexp in OR condition."
  (with-temp-buffer
    (insert "[ ] Alpha Project\n")
    (insert "    [ ] Task 1\n")
    (insert "[ ] Beta Project\n")
    (insert "    [ ] Task 2\n")
    (insert "[ ] Gamma Project\n")
    (insert "    [ ] Task 3\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "or:parent-task-regexp:Alpha,parent-task-regexp:Gamma")))
      (altodo--filter-lines pred)
      ;; Tasks under Alpha or Gamma should be visible
      (goto-char (point-min))
      (should-not (invisible-p (point)))  ; Alpha visible
      (forward-line 1)
      (should-not (invisible-p (point)))  ; Task 1 visible
      (forward-line 1)
      (should (invisible-p (point)))  ; Beta hidden
      (forward-line 1)
      (should (invisible-p (point)))  ; Task 2 hidden
      (forward-line 1)
      (should-not (invisible-p (point)))  ; Gamma visible
      (forward-line 1)
      (should-not (invisible-p (point))))))  ; Task 3 visible

(ert-deftest test-advanced-root-with-priority-and-tags ()
  "Test root-task-regexp with priority and multiple tags."
  (with-temp-buffer
    (insert "[ ] Root Project #type:feature\n")
    (insert "    [ ] ! High priority #status:review\n")
    (insert "    [ ] Normal task #status:todo\n")
    (insert "[ ] Other Root #type:bugfix\n")
    (insert "    [ ] ! Bug fix #status:review\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "and:root-task-regexp:Root Project,priority,tag:status")))
      (altodo--filter-lines pred)
      ;; Only priority tasks with status tag under Root Project
      (goto-char (point-min))
      (should (invisible-p (point)))  ; Root Project hidden
      (forward-line 1)
      (should-not (invisible-p (point)))  ; High priority visible
      (forward-line 1)
      (should (invisible-p (point)))  ; Normal task hidden
      (forward-line 1)
      (should (invisible-p (point)))  ; Other Root hidden
      (forward-line 1)
      (should (invisible-p (point))))))  ; Bug fix hidden

(provide 'parent-task-regexp-test)
;;; parent-task-regexp-test.el ends here
