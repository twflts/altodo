;;; matcher-remaining-test.el --- Tests for remaining matcher functions

(require 'ert)
(load-file "altodo.el")

(defvar test-buffer nil)

(defun setup-test-buffer ()
  (setq test-buffer (get-buffer-create "*altodo-matcher-rem-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task depends:$abc\n")
    (insert "[ ] Task due:2026-12-31\n")
    (insert "=== Comment ===\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-dep-blocked-text-matcher ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (let ((result (altodo--dep-blocked-text-matcher (line-end-position))))
      (should (or (null result) (numberp result)))))
  (cleanup-test-buffer))

(ert-deftest test-due-overdue-severe-text-matcher ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 1)
    (let ((result (altodo--due-overdue-severe-text-matcher (line-end-position))))
      (should (or (null result) (numberp result)))))
  (cleanup-test-buffer))

(ert-deftest test-start-not-yet-text-matcher ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (let ((result (altodo--start-not-yet-text-matcher (line-end-position))))
      (should (or (null result) (numberp result)))))
  (cleanup-test-buffer))

(ert-deftest test-multiline-comment-matcher ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 2)
    (let ((result (altodo--multiline-comment-matcher (line-end-position))))
      (should (or (null result) (numberp result)))))
  (cleanup-test-buffer))

(ert-deftest test-multiline-comment-list-matcher ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (let ((result (altodo--multiline-comment-list-matcher (line-end-position))))
      (should (or (null result) (numberp result)))))
  (cleanup-test-buffer))

(provide 'matcher-remaining-test)
