;;; debug-seq-tasks-last-child-test.el --- Debug seq-tasks last child dependency

(require 'ert)
(require 'altodo)

(ert-deftest debug-seq-tasks-last-child-completed ()
  "Debug seq-tasks parent depends on last child."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent #seq-tasks\n")
    (insert "    [ ] Child 1\n")
    (insert "    [ ] Child 2\n")
    (insert "    [x] Child 3 (last)\n")
    (font-lock-fontify-buffer)
    
    (message "=== DEBUG: seq-tasks last child completed ===")
    
    ;; Check parent line (line 1)
    (goto-line 1)
    (message "Line 1 (parent):")
    (message "  get-seq-tasks-status: %s" (altodo--get-seq-tasks-status))
    (message "  line-seq-tasks-blocked-p: %s" (altodo--line-seq-tasks-blocked-p))
    
    ;; Check face at position 5 (after "[ ] ")
    (let ((face-at-5 (get-text-property 5 'face)))
      (message "  Face at position 5: %s" face-at-5))))

(ert-deftest debug-seq-tasks-last-child-open ()
  "Debug seq-tasks parent depends on last child (open)."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent #seq-tasks\n")
    (insert "    [x] Child 1\n")
    (insert "    [x] Child 2\n")
    (insert "    [ ] Child 3 (last)\n")
    (font-lock-fontify-buffer)
    
    (message "=== DEBUG: seq-tasks last child open ===")
    
    ;; Check parent line (line 1)
    (goto-line 1)
    (message "Line 1 (parent):")
    (message "  get-seq-tasks-status: %s" (altodo--get-seq-tasks-status))
    (message "  line-seq-tasks-blocked-p: %s" (altodo--line-seq-tasks-blocked-p))
    
    ;; Check face at position 5 (after "[ ] ")
    (let ((face-at-5 (get-text-property 5 'face)))
      (message "  Face at position 5: %s" face-at-5))))

(provide 'debug-seq-tasks-last-child-test)
;;; debug-seq-tasks-last-child-test.el ends here
