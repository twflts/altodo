;;; debug-seq-tasks-test.el --- Debug seq-tasks face application

(require 'ert)
(require 'altodo)

(ert-deftest debug-seq-tasks-parent-blocked ()
  "Debug seq-tasks parent with open child."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent #seq-tasks\n")
    (insert "    [ ] Child\n")
    (font-lock-fontify-buffer)
    
    (message "=== DEBUG: seq-tasks parent blocked ===")
    
    ;; Check parent line (line 1)
    (goto-line 1)
    (message "Line 1 (parent):")
    (message "  get-seq-tasks-status: %s" (altodo--get-seq-tasks-status))
    (message "  line-seq-tasks-blocked-p: %s" (altodo--line-seq-tasks-blocked-p))
    
    ;; Check face at position 5 (after "[ ] ")
    (let ((face-at-5 (get-text-property 5 'face)))
      (message "  Face at position 5: %s" face-at-5))
    
    ;; Check child line (line 2)
    (goto-line 2)
    (message "Line 2 (child):")
    (message "  line-seq-tasks-blocked-p: %s" (altodo--line-seq-tasks-blocked-p))
    
    ;; Check face at position 9 (after "    [ ] ")
    (let ((face-at-9 (get-text-property 9 'face)))
      (message "  Face at position 9: %s" face-at-9))))

(provide 'debug-seq-tasks-test)
;;; debug-seq-tasks-test.el ends here
