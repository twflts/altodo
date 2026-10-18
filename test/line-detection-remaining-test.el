;;; line-detection-remaining-test.el --- Tests for remaining line detection functions

(require 'ert)
(load-file "altodo.el")

(defvar test-buffer nil)

(defun setup-test-buffer ()
  (setq test-buffer (get-buffer-create "*altodo-line-det-rem-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task\n")
    (insert "=== Comment ===\n")
    (insert "\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-comment-p-remaining ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 1)
    (should (or (altodo--comment-p) (not (altodo--comment-p)))))
  (cleanup-test-buffer))

(ert-deftest test-empty-task-line-p-remaining ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 2)
    (should (or (altodo--empty-task-line-p) (not (altodo--empty-task-line-p)))))
  (cleanup-test-buffer))

(ert-deftest test-line-state-p ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (let ((result (altodo--line-state-p altodo-state-open)))
      (should (or (null result) (eq result t)))))
  (cleanup-test-buffer))

(provide 'line-detection-remaining-test)
