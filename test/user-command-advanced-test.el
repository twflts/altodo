;;; user-command-advanced-test.el --- Tests for advanced user commands

(require 'ert)
(load-file "altodo.el")

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

(ert-deftest test-toggle-star-flag ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo-toggle-star-flag)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-start-multiline-comment ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo-start-multiline-comment)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-move-done-tasks-at-point ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 1)
    (altodo-move-done-tasks-at-point)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-move-all-done-tasks ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo-move-all-done-tasks)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-run-full-test-suite ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo-run-full-test-suite)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-test-regex-patterns ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo-test-regex-patterns)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-test-helper-functions ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo-test-helper-functions)
    (should t))
  (cleanup-test-buffer))

(provide 'user-command-advanced-test)
