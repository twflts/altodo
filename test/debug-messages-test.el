;;; debug-messages-test.el --- Debug with messages output

(require 'ert)
(require 'altodo)

(ert-deftest debug-messages-strikethrough-done ()
  "Debug strikethrough face for [x] with messages."
  (with-temp-buffer
    (altodo-mode)
    (insert "[x] Completed task\n")
    (font-lock-fontify-buffer)
    
    ;; Output debug info to messages
    (message "=== DEBUG: [x] Completed task ===")
    (message "Buffer content: %S" (buffer-string))
    
    ;; Check specific position
    (let ((face-at-5 (get-text-property 5 'face)))
      (message "Face at position 5: %s" face-at-5)
      (should (or (eq face-at-5 'altodo-task-done-text-face)
                  (and (listp face-at-5) (memq 'altodo-task-done-text-face face-at-5)))))))

(ert-deftest debug-messages-seq-tasks ()
  "Debug seq-tasks blocked with messages."
  (with-temp-buffer
    (altodo-mode)
    (insert "[x] Task #seq-tasks\n")
    (insert "    [ ] Child\n")
    (font-lock-fontify-buffer)
    
    ;; Output debug info to messages
    (message "=== DEBUG: seq-tasks ===")
    (message "Buffer content: %S" (buffer-string))
    
    ;; Check line 1
    (goto-line 1)
    (let ((has-tag (altodo--has-seq-tasks-tag)))
      (message "Line 1 has seq-tasks tag: %s" has-tag))
    
    ;; Check status
    (let ((status (altodo--get-seq-tasks-status)))
      (message "Line 1 seq-tasks status: %s" status))))

(provide 'debug-messages-test)
;;; debug-messages-test.el ends here
