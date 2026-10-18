;;; debug-simple-test.el --- Simple debug test

(require 'ert)
(require 'altodo)

(ert-deftest debug-simple-blocked ()
  "Simple blocked test."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent #seq-tasks\n")
    (insert "    [ ] Task 1\n")
    (insert "    [ ] Task 2\n")
    (font-lock-fontify-buffer)
    
    (message "=== DEBUG: simple blocked ===")
    
    ;; Line 2 (Task 1)
    (goto-line 2)
    (message "Line 2 (Task 1):")
    (message "  is-seq-tasks-child-blocked-p: %s" (altodo--is-seq-tasks-child-blocked-p))
    
    ;; Line 3 (Task 2)
    (goto-line 3)
    (message "Line 3 (Task 2):")
    (message "  is-seq-tasks-child-blocked-p: %s" (altodo--is-seq-tasks-child-blocked-p))))

(provide 'debug-simple-test)
;;; debug-simple-test.el ends here
