;;; debug-filter-test.el --- Debug filter functions

(require 'ert)
(require 'altodo)

(ert-deftest debug-filter-ready ()
  "Debug filter ready."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Ready #seq-tasks\n")
    (insert "    [x] Child\n")
    (insert "[ ] Blocked #seq-tasks\n")
    (insert "    [ ] Child\n")
    
    (message "=== DEBUG: filter ready ===")
    
    ;; Line 1
    (goto-line 1)
    (message "Line 1:")
    (message "  task-p: %s" (altodo--task-p))
    (message "  has-seq-tasks-tag: %s" (altodo--has-seq-tasks-tag))
    
    ;; Check children
    (let ((children (altodo--get-seq-tasks-children)))
      (message "  children: %s" children)
      (message "  children count: %d" (length children)))
    
    (message "  get-seq-tasks-status: %s" (altodo--get-seq-tasks-status))
    (message "  line-seq-tasks-ready-p: %s" (altodo--line-seq-tasks-ready-p))))

(provide 'debug-filter-test)
;;; debug-filter-test.el ends here
