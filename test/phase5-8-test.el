;;; phase5-8-test.el --- Tests for seq-tasks implementation

(require 'ert)
(require 'altodo)

;;; Basic Helper Tests

(ert-deftest phase5-8-has-seq-tasks-tag ()
  "Test altodo--has-seq-tasks-tag function."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task with #seq-tasks tag")
    (beginning-of-line)
    (should (altodo--has-seq-tasks-tag))
    
    (erase-buffer)
    (insert "[ ] Task without tag")
    (beginning-of-line)
    (should-not (altodo--has-seq-tasks-tag))))

(ert-deftest phase5-8-get-seq-tasks-children ()
  "Test altodo--get-seq-tasks-children function."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent #seq-tasks\n")
    (insert "    [ ] Child 1\n")
    (insert "    [ ] Child 2\n")
    (insert "[ ] Sibling\n")
    (goto-line 1)
    (let ((children (altodo--get-seq-tasks-children)))
      (should (= (length children) 2)))))

(ert-deftest phase5-8-get-seq-tasks-status-ready ()
  "Test seq-tasks status is ready when all children completed."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent #seq-tasks\n")
    (insert "    [x] Child 1\n")
    (insert "    [x] Child 2\n")
    (goto-line 1)
    (should (eq (altodo--get-seq-tasks-status) 'ready))))

(ert-deftest phase5-8-get-seq-tasks-status-blocked ()
  "Test seq-tasks status is blocked when first child not completed."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent #seq-tasks\n")
    (insert "    [ ] Child 1\n")
    (insert "    [ ] Child 2\n")
    (goto-line 1)
    (should (eq (altodo--get-seq-tasks-status) 'blocked))))

(ert-deftest phase5-8-get-seq-tasks-status-completed ()
  "Test seq-tasks status is completed when parent completed."
  (with-temp-buffer
    (altodo-mode)
    (insert "[x] Parent #seq-tasks\n")
    (insert "    [ ] Child 1\n")
    (goto-line 1)
    (should (eq (altodo--get-seq-tasks-status) 'completed))))

(ert-deftest phase5-8-line-seq-tasks-ready-p ()
  "Test altodo--line-seq-tasks-ready-p filter."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent #seq-tasks\n")
    (insert "    [x] Child 1\n")
    (goto-line 1)
    (should (altodo--line-seq-tasks-ready-p))))

(ert-deftest phase5-8-line-seq-tasks-blocked-p ()
  "Test altodo--line-seq-tasks-blocked-p filter."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent #seq-tasks\n")
    (insert "    [ ] Child 1\n")
    (goto-line 1)
    (should (altodo--line-seq-tasks-blocked-p))))

(ert-deftest phase5-8-line-seq-tasks-all-p ()
  "Test altodo--line-seq-tasks-all-p filter."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent #seq-tasks\n")
    (insert "    [ ] Child 1\n")
    (goto-line 1)
    (should (altodo--line-seq-tasks-all-p))))

;;; Complex Tests

(ert-deftest phase5-8-nested-seq-tasks ()
  "Test nested seq-tasks structures."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Root #seq-tasks\n")
    (insert "    [ ] Parent #seq-tasks\n")
    (insert "        [ ] Child 1\n")
    (insert "        [ ] Child 2\n")
    (insert "    [ ] Sibling\n")
    (goto-line 2)
    (should (eq (altodo--get-seq-tasks-status) 'blocked))))

(ert-deftest phase5-8-multiple-parents ()
  "Test task with multiple parent seq-tasks."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent1 #seq-tasks\n")
    (insert "    [ ] Task\n")
    (insert "[ ] Parent2 #seq-tasks\n")
    (insert "    [ ] Task\n")
    (goto-line 2)
    (let ((parent (altodo--get-seq-tasks-parent)))
      (should parent))))

(ert-deftest phase5-8-mixed-states ()
  "Test seq-tasks with mixed task states."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent #seq-tasks\n")
    (insert "    [x] Child 1\n")
    (insert "    [@] Child 2\n")
    (insert "    [w] Child 3\n")
    (goto-line 1)
    (should (eq (altodo--get-seq-tasks-status) 'blocked))))

(ert-deftest phase5-8-no-children ()
  "Test seq-tasks with no children."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent #seq-tasks\n")
    (goto-line 1)
    (should (eq (altodo--get-seq-tasks-status) 'ready))))

(ert-deftest phase5-8-cancelled-state ()
  "Test seq-tasks with cancelled state."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent #seq-tasks\n")
    (insert "    [~] Child 1\n")
    (insert "    [ ] Child 2\n")
    (goto-line 1)
    (should (eq (altodo--get-seq-tasks-status) 'blocked))))

(ert-deftest phase5-8-parent-cancelled ()
  "Test seq-tasks when parent is cancelled."
  (with-temp-buffer
    (altodo-mode)
    (insert "[~] Parent #seq-tasks\n")
    (insert "    [ ] Child 1\n")
    (goto-line 1)
    (should (eq (altodo--get-seq-tasks-status) 'completed))))

(ert-deftest phase5-8-deep-nesting ()
  "Test deeply nested seq-tasks."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] L1 #seq-tasks\n")
    (insert "    [ ] L2 #seq-tasks\n")
    (insert "        [ ] L3 #seq-tasks\n")
    (insert "            [ ] L4\n")
    (goto-line 3)
    (should (eq (altodo--get-seq-tasks-status) 'blocked))))

(ert-deftest phase5-8-filter-ready ()
  "Test filtering ready seq-tasks."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Ready #seq-tasks\n")
    (insert "    [x] Child\n")
    (insert "[ ] Blocked #seq-tasks\n")
    (insert "    [ ] Child\n")
    (goto-line 1)
    (should (altodo--line-seq-tasks-ready-p))
    (goto-line 3)
    (should-not (altodo--line-seq-tasks-ready-p))))

(ert-deftest phase5-8-filter-blocked ()
  "Test filtering blocked seq-tasks."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Ready #seq-tasks\n")
    (insert "    [x] Child\n")
    (insert "[ ] Blocked #seq-tasks\n")
    (insert "    [ ] Child\n")
    (goto-line 1)
    (should-not (altodo--line-seq-tasks-blocked-p))
    (goto-line 3)
    (should (altodo--line-seq-tasks-blocked-p))))

(ert-deftest phase5-8-filter-all ()
  "Test filtering all seq-tasks."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task #seq-tasks\n")
    (insert "    [ ] Child\n")
    (insert "[ ] Normal task\n")
    (goto-line 1)
    (should (altodo--line-seq-tasks-all-p))
    (goto-line 3)
    (should-not (altodo--line-seq-tasks-all-p))))

;;; Cancelled State Tests

(ert-deftest phase5-8-cancelled-parent-status ()
  "Test cancelled parent status."
  (with-temp-buffer
    (altodo-mode)
    (insert "[~] Parent #seq-tasks\n")
    (insert "    [ ] Child\n")
    (goto-line 1)
    (should (eq (altodo--get-seq-tasks-status) 'completed))))

(ert-deftest phase5-8-cancelled-child-ready ()
  "Test cancelled child makes parent blocked."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent #seq-tasks\n")
    (insert "    [~] Child 1\n")
    (insert "    [ ] Child 2\n")
    (goto-line 1)
    (should (eq (altodo--get-seq-tasks-status) 'blocked))))

(ert-deftest phase5-8-cancelled-filter ()
  "Test cancelled state in filters."
  (with-temp-buffer
    (altodo-mode)
    (insert "[~] Parent #seq-tasks\n")
    (insert "    [ ] Child\n")
    (goto-line 1)
    (should (altodo--line-seq-tasks-all-p))))

(provide 'phase5-8-test)
;;; phase5-8-test.el ends here
