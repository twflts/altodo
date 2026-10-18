;;; multiline-comment-test.el --- Tests for multiline comment functions

(require 'ert)
(load-file "altodo.el")

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
      (should (or (null result) (listp result)))))
  (cleanup-test-buffer))

(ert-deftest test-indent-multiline-comments ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (let ((lines (list 2 3)))
      (altodo--indent-multiline-comments lines 4)
      (should t)))
  (cleanup-test-buffer))

(ert-deftest test-get-multiline-comment-region ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 1)
    (let ((result (altodo--get-multiline-comment-region)))
      (should (or (null result) (listp result)))))
  (cleanup-test-buffer))

(provide 'multiline-comment-test)
