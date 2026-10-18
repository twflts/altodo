;;; other-test.el --- Tests for other functions

(require 'ert)
(load-file "altodo.el")

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
    (altodo--call-parent-command "C-a")
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-debug-log ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo--debug-log "Test message")
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-outline-level ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (let ((result (altodo--outline-level)))
      (should (numberp result))))
  (cleanup-test-buffer))

(ert-deftest test-has-task-or-comment-above ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 1)
    (let ((result (altodo--has-task-or-comment-above)))
      (should (or (null result) (eq result t)))))
  (cleanup-test-buffer))

(ert-deftest test-set-task-state ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo--set-task-state altodo-state-done)
    (should (looking-at "\\[x\\]")))
  (cleanup-test-buffer))

(provide 'other-test)
