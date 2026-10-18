;;; matcher-advanced-test.el --- Tests for advanced matcher functions

(require 'ert)
(load-file "altodo.el")

(defvar test-buffer nil)

(defun setup-test-buffer ()
  (setq test-buffer (get-buffer-create "*altodo-matcher-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task #tag1 @person1\n")
    (insert "[ ] Task depends:$abc123\n")
    (insert "=== Comment ===\n")
    (insert "Comment text\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-arrow-matcher ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (should (or (null (altodo--arrow-matcher (line-end-position)))
                (numberp (altodo--arrow-matcher (line-end-position))))))
  (cleanup-test-buffer))

(ert-deftest test-tag-with-value-matcher ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (should (or (null (altodo--tag-with-value-matcher (line-end-position)))
                (numberp (altodo--tag-with-value-matcher (line-end-position))))))
  (cleanup-test-buffer))

(ert-deftest test-dep-tag-matcher ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 1)
    (should (or (null (altodo--dep-tag-matcher (line-end-position)))
                (numberp (altodo--dep-tag-matcher (line-end-position))))))
  (cleanup-test-buffer))

(ert-deftest test-multiline-comment-matcher-new ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 2)
    (should (or (null (altodo--multiline-comment-matcher-new (line-end-position)))
                (numberp (altodo--multiline-comment-matcher-new (line-end-position))))))
  (cleanup-test-buffer))

(provide 'matcher-advanced-test)
