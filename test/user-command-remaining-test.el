;;; user-command-remaining-test.el --- Tests for remaining user commands

(require 'ert)
(load-file "altodo.el")

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

(ert-deftest test-indent-increase ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo-indent-increase)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-indent-decrease ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo-indent-decrease)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-indent-line ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo-indent-line)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-enter-internal ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (end-of-line)
    (altodo-enter-internal)
    (should t))
  (cleanup-test-buffer))

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

(ert-deftest test-set-priority-1 ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo-set-priority-1)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-set-priority-2 ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo-set-priority-2)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-set-priority-3 ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo-set-priority-3)
    (should t))
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
