;;; input-test.el --- Tests for input functions

(require 'ert)
(load-file "altodo.el")

(defvar test-buffer nil)

(defun setup-test-buffer ()
  (setq test-buffer (get-buffer-create "*altodo-input-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task 1\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-enter-on-task ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (end-of-line)
    (altodo-enter)
    (should (> (line-number-at-pos) 1)))
  (cleanup-test-buffer))

(provide 'input-test)
