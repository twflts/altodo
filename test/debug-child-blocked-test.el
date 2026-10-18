;;; debug-child-blocked-test.el --- Debug child blocked detection

(require 'ert)
(require 'altodo)

(ert-deftest debug-child-blocked ()
  "Debug child blocked detection."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] 親タスク #seq-tasks\n")
    (insert "    [x] タスク 1（完了）\n")
    (insert "    [ ] タスク 2（ready - タスク 1 が完了）\n")
    (insert "    [ ] タスク 3（blocked - タスク 2 が未完了）\n")
    (font-lock-fontify-buffer)
    
    (message "=== DEBUG: child blocked detection ===")
    
    ;; Line 1 (parent)
    (goto-line 1)
    (message "Line 1 (parent):")
    (message "  line-seq-tasks-blocked-p: %s" (altodo--line-seq-tasks-blocked-p))
    
    ;; Line 3 (タスク 2)
    (goto-line 3)
    (message "Line 3 (タスク 2):")
    (message "  line-number-at-pos: %d" (line-number-at-pos))
    (message "  line-seq-tasks-blocked-p: %s" (altodo--line-seq-tasks-blocked-p))
    (message "  is-seq-tasks-child-blocked-p: %s" (altodo--is-seq-tasks-child-blocked-p))
    
    ;; Line 4 (タスク 3)
    (goto-line 4)
    (message "Line 4 (タスク 3):")
    (message "  line-number-at-pos: %d" (line-number-at-pos))
    (message "  line-seq-tasks-blocked-p: %s" (altodo--line-seq-tasks-blocked-p))
    (message "  is-seq-tasks-child-blocked-p: %s" (altodo--is-seq-tasks-child-blocked-p))))

(provide 'debug-child-blocked-test)
;;; debug-child-blocked-test.el ends here
