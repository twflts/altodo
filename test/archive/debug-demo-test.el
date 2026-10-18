;;; debug-demo-test.el --- Debug demo file issues

(require 'ert)
(require 'altodo)

(ert-deftest debug-demo-line-15 ()
  "Debug line 15: 子タスク 1-2."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] 親タスク 1 #seq-tasks\n")
    (insert "    [ ] 子タスク 1-1（依存なし）\n")
    (insert "        [ ] 孫タスク 1-1-1（子タスク 1-1 に依存）\n")
    (insert "        [ ] 孫タスク 1-1-2（子タスク 1-1 に依存）\n")
    (insert "    [ ] 子タスク 1-2（子タスク 1-1 の完了に依存）\n")
    (font-lock-fontify-buffer)
    
    (message "=== DEBUG: line 15 (子タスク 1-2) ===")
    
    ;; Line 5 (子タスク 1-2)
    (goto-line 5)
    (message "Line 5 (子タスク 1-2):")
    (message "  has-seq-tasks-tag: %s" (altodo--has-seq-tasks-tag))
    (message "  get-seq-tasks-status: %s" (altodo--get-seq-tasks-status))
    (message "  line-seq-tasks-blocked-p: %s" (altodo--line-seq-tasks-blocked-p))
    
    ;; Check parent
    (let ((parent (altodo--get-seq-tasks-parent)))
      (message "  parent: %s" parent))
    
    ;; Check face
    (let ((face-at-9 (get-text-property 9 'face)))
      (message "  Face at position 9: %s" face-at-9))))

(ert-deftest debug-demo-line-29 ()
  "Debug line 29: タスク 2 (ready)."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] 親タスク #seq-tasks\n")
    (insert "    [x] タスク 1（完了）\n")
    (insert "    [ ] タスク 2（ready - タスク 1 が完了）\n")
    (insert "    [ ] タスク 3（blocked - タスク 2 が未完了）\n")
    (font-lock-fontify-buffer)
    
    (message "=== DEBUG: line 29 (タスク 2) ===")
    
    ;; Line 1 (parent)
    (goto-line 1)
    (message "Line 1 (parent):")
    (let ((children (altodo--get-seq-tasks-children)))
      (message "  children: %s" children))
    (message "  get-seq-tasks-status: %s" (altodo--get-seq-tasks-status))
    
    ;; Line 3 (タスク 2)
    (goto-line 3)
    (message "Line 3 (タスク 2):")
    (message "  has-seq-tasks-tag: %s" (altodo--has-seq-tasks-tag))
    (message "  line-seq-tasks-blocked-p: %s" (altodo--line-seq-tasks-blocked-p))
    
    ;; Check face
    (let ((face-at-9 (get-text-property 9 'face)))
      (message "  Face at position 9: %s" face-at-9))))

(provide 'debug-demo-test)
;;; debug-demo-test.el ends here
