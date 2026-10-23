;;; other-test.el --- Tests for other functions

(require 'ert)
(require 'altodo)

(defvar test-buffer nil)

(defun setup-test-buffer ()
  (setq test-buffer (get-buffer-create "*altodo-other-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task 1\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-call-parent-command ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    ;; No binding in the parent keymap: nothing happens and nil is returned.
    (should-not (altodo--call-parent-command (kbd "C-a"))))
  (cleanup-test-buffer))

(ert-deftest test-outline-level ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (let ((result (altodo--outline-level)))
      (should (numberp result))))
  (cleanup-test-buffer))

(ert-deftest test-multiline-comment-indent-ok-p ()
  "The lines above decide whether a line of a given indentation is a comment."
  (with-temp-buffer
    (insert "[ ] task\n    note\n")
    (altodo-mode)
    (goto-char (point-max))
    (forward-line -1)
    (should (altodo--multiline-comment-indent-ok-p 4))
    (should-not (altodo--multiline-comment-indent-ok-p 0))
    (should-not (altodo--multiline-comment-indent-ok-p 8))))

(ert-deftest test-set-task-state ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo--set-task-state altodo-state-done)
    (should (looking-at "\\[x\\]")))
  (cleanup-test-buffer))

(provide 'other-test)
