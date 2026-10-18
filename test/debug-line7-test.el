;;; debug-line7-test.el --- Debug line 7 of demo file

(require 'ert)
(require 'altodo)

(ert-deftest debug-line7 ()
  "Debug line 7: parent with all children completed."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] 親タスク #seq-tasks\n")
    (insert "    [x] タスク 1（依存なし、すぐに実施可能） #done:2026-02-28T23:18:14+09:00\n")
    (insert "    [x] タスク 2（タスク 1 の完了に依存） #done:2026-02-28T23:18:14+09:00\n")
    (insert "    [x] タスク 3（タスク 2 の完了に依存） #done:2026-02-28T23:18:12+09:00\n")
    (font-lock-fontify-buffer)
    
    (message "=== DEBUG: line 7 ===")
    
    ;; Line 1 (parent)
    (goto-line 1)
    (message "Line 1 (parent):")
    (let ((children (altodo--get-seq-tasks-children)))
      (message "  children: %s" children)
      (message "  children count: %d" (length children)))
    (message "  get-seq-tasks-status: %s" (altodo--get-seq-tasks-status))
    (message "  line-seq-tasks-blocked-p: %s" (altodo--line-seq-tasks-blocked-p))
    
    ;; Check face
    (let ((face-at-5 (get-text-property 5 'face)))
      (message "  Face at position 5: %s" face-at-5))))

(provide 'debug-line7-test)
;;; debug-line7-test.el ends here
