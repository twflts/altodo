;;; debug-parent-test.el --- Debug parent task status

(require 'ert)
(require 'altodo)

(ert-deftest debug-parent-all-completed ()
  "Debug parent when all children completed."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent #seq-tasks\n")
    (insert "    [x] Task 1\n")
    (insert "    [x] Task 2\n")
    (font-lock-fontify-buffer)
    
    (message "=== DEBUG: parent all completed ===")
    
    ;; Line 1 (parent)
    (goto-line 1)
    (message "Line 1 (parent):")
    (let ((children (altodo--get-seq-tasks-children)))
      (message "  children: %s" children))
    (message "  get-seq-tasks-status: %s" (altodo--get-seq-tasks-status))
    (message "  line-seq-tasks-blocked-p: %s" (altodo--line-seq-tasks-blocked-p))
    
    ;; Check face
    (let ((face-at-5 (get-text-property 5 'face)))
      (message "  Face at position 5: %s" face-at-5))))

(ert-deftest debug-parent-last-completed ()
  "Debug parent when last child completed."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Parent #seq-tasks\n")
    (insert "    [ ] Task 1\n")
    (insert "    [x] Task 2\n")
    (font-lock-fontify-buffer)
    
    (message "=== DEBUG: parent last completed ===")
    
    ;; Line 1 (parent)
    (goto-line 1)
    (message "Line 1 (parent):")
    (let ((children (altodo--get-seq-tasks-children)))
      (message "  children: %s" children))
    (message "  get-seq-tasks-status: %s" (altodo--get-seq-tasks-status))
    (message "  line-seq-tasks-blocked-p: %s" (altodo--line-seq-tasks-blocked-p))
    
    ;; Check face
    (let ((face-at-5 (get-text-property 5 'face)))
      (message "  Face at position 5: %s" face-at-5))))

(provide 'debug-parent-test)
;;; debug-parent-test.el ends here
