;;; user-command-advanced-test.el --- Tests for advanced user commands

(require 'ert)
(require 'altodo)

(defvar test-buffer nil)

(defun setup-test-buffer ()
  (setq test-buffer (get-buffer-create "*altodo-user-cmd-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task 1\n")
    (insert "[x] Task 2\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-insert-id ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo-insert-id)
    (end-of-line)
    (should (looking-back "#id:[a-zA-Z0-9]+")))
  (cleanup-test-buffer))

(ert-deftest test-add-subtask ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo-add-subtask)
    (should (> (line-number-at-pos) 1)))
  (cleanup-test-buffer))

(provide 'user-command-advanced-test)
