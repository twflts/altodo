;;; done-cancelled-face-test.el --- Tests for the strikethrough faces of done and cancelled tasks

(require 'ert)
(require 'altodo)

(ert-deftest debug-strikethrough-done ()
  "Debug strikethrough face for [x]."
  (with-temp-buffer
    (altodo-mode)
    (insert "[x] Completed task\n")
    (font-lock-fontify-buffer)
    
    ;; Check if face is applied at position 5
    (let ((face-at-5 (get-text-property 5 'face)))
      (should (or (eq face-at-5 'altodo-task-done-text-face)
                  (and (listp face-at-5) (memq 'altodo-task-done-text-face face-at-5))
                  (message "FAIL: [x] face at 5: %s" face-at-5))))))

(ert-deftest debug-strikethrough-cancelled ()
  "Debug strikethrough face for [~]."
  (with-temp-buffer
    (altodo-mode)
    (insert "[~] Cancelled task\n")
    (font-lock-fontify-buffer)
    
    ;; Check if face is applied at position 5
    (let ((face-at-5 (get-text-property 5 'face)))
      (should (or (eq face-at-5 'altodo-task-cancelled-text-face)
                  (and (listp face-at-5) (memq 'altodo-task-cancelled-text-face face-at-5))
                  (message "FAIL: [~] face at 5: %s" face-at-5))))))

(ert-deftest debug-open-task ()
  "Debug face for [ ]."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Open task\n")
    (font-lock-fontify-buffer)
    
    ;; Check if face is applied at position 5
    (let ((face-at-5 (get-text-property 5 'face)))
      (should (or (not (or (eq face-at-5 'altodo-task-done-text-face)
                           (eq face-at-5 'altodo-task-cancelled-text-face)))
                  (message "FAIL: [ ] should not have strikethrough face: %s" face-at-5))))))

(provide 'done-cancelled-face-test)
;;; done-cancelled-face-test.el ends here
