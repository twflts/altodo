;;; user-command-remaining-test.el --- Tests for remaining user commands

(require 'ert)
(require 'altodo)

(defvar test-buffer nil)

(defun setup-test-buffer ()
  (setq test-buffer (get-buffer-create "*altodo-user-cmd-rem-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task 1\n")
    (insert "[@] Task 2\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-set-task-progress ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo-set-task-progress)
    (should (looking-at "\\[@\\]")))
  (cleanup-test-buffer))

(ert-deftest test-set-task-waiting ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo-set-task-waiting)
    (should (looking-at "\\[w\\]")))
  (cleanup-test-buffer))

(ert-deftest test-set-task-cancelled ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo-set-task-cancelled)
    (should (looking-at "\\[~\\]")))
  (cleanup-test-buffer))

(ert-deftest test-toggle-comment ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo-toggle-comment)
    (beginning-of-line)
    (should (looking-at altodo-comment-regex)))
  (cleanup-test-buffer))

(provide 'user-command-remaining-test)
