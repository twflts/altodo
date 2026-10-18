;;; multiline-comment-test.el --- Tests for multiline comment functions

(require 'ert)
(require 'altodo)

(defvar test-buffer nil)

(defun setup-test-buffer ()
  (setq test-buffer (get-buffer-create "*altodo-multiline-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task 1\n")
    (insert "=== Comment ===\n")
    (insert "Comment line 1\n")
    (insert "Comment line 2\n")
    (insert "[ ] Task 2\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-get-multiline-comment-lines ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 1)
    (let ((result (altodo--get-multiline-comment-lines)))
      (should (listp result))))
  (cleanup-test-buffer))

(ert-deftest test-indent-multiline-comments ()
  (with-temp-buffer
    (insert "[ ] Task\n    comment 1\n    comment 2\n[ ] Next\n")
    (altodo-mode)
    (altodo--indent-multiline-comments (list 2 3) 4)
    (should (equal (buffer-substring-no-properties (point-min) (point-max))
                   "[ ] Task\n        comment 1\n        comment 2\n[ ] Next\n"))))

(ert-deftest test-get-multiline-comment-lines-listing ()
  "The lines after a task that belong to its multi-line comment are listed."
  (with-temp-buffer
    (insert "[ ] Task\n    comment 1\n    comment 2\n[ ] Next\n")
    (altodo-mode)
    (goto-char (point-min))
    (should (equal (altodo--get-multiline-comment-lines) '(2 3)))
    (forward-line 3)
    (should-not (altodo--get-multiline-comment-lines))))

(ert-deftest test-get-multiline-comment-region ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 1)
    (let ((result (altodo--get-multiline-comment-region)))
      (should (or (null result) (listp result)))))
  (cleanup-test-buffer))

(provide 'multiline-comment-test)
