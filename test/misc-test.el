;;; misc-test.el --- Tests for altodo miscellaneous functions

;;; Commentary:
;; Tests for miscellaneous functions

;;; Code:

(require 'ert)
(require 'altodo)

(defvar test-buffer nil)

(defun setup-test-buffer ()
  "Create a test buffer with sample tasks."
  (setq test-buffer (get-buffer-create "*altodo-misc-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task 1\n")
    (insert "[x] Task 2\n")
    (insert "=== Comment ===\n")
    (insert "Comment text\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  "Clean up test buffer."
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-outline-level-zero ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (should (= (altodo--outline-level) 1)))
  (cleanup-test-buffer))

(ert-deftest test-multiline-comment-p-on-task ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (should-not (altodo--multiline-comment-p)))
  (cleanup-test-buffer))

(provide 'misc-test)
;;; misc-test.el ends here
