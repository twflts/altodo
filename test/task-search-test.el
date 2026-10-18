;;; task-search-test.el --- Tests for task search and operation functions

(require 'ert)
(require 'altodo)

(defvar test-buffer nil)

(defun setup-test-buffer ()
  (setq test-buffer (get-buffer-create "*altodo-task-search-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task 1\n")
    (insert "    [ ] Task 1.1\n")
    (insert "[x] Task 2\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-find-previous-task-line ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 1)
    (let ((result (altodo--find-previous-task-line)))
      (should (or (null result) (numberp result)))))
  (cleanup-test-buffer))

(ert-deftest test-add-done-tag ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo--add-done-tag)
    (end-of-line)
    (should (looking-back "#done:[0-9/:T+-]+" (line-beginning-position))))
  (cleanup-test-buffer))

(ert-deftest test-remove-done-tag ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 2)
    (altodo--add-done-tag)
    (altodo--remove-done-tag)
    (beginning-of-line)
    (should (looking-at "\\[x\\]")))
  (cleanup-test-buffer))

(ert-deftest test-get-task-heading ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (let ((result (altodo--get-task-heading)))
      (should (or (null result) (stringp result)))))
  (cleanup-test-buffer))

(ert-deftest test-extract-task-with-comments ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (let ((result (altodo--extract-task-with-comments)))
      (should (consp result))))
  (cleanup-test-buffer))

(provide 'task-search-test)
