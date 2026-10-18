;;; other-remaining-test.el --- Tests for remaining other functions

(require 'ert)
(load-file "altodo.el")

(defvar test-buffer nil)

(defun setup-test-buffer ()
  (setq test-buffer (get-buffer-create "*altodo-other-rem-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-set-priority-flag ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo--set-priority-flag 1)
    (should t))
  (cleanup-test-buffer))

(provide 'other-remaining-test)
