;;; filter-function-test.el --- Tests for altodo filter functions

;;; Commentary:
;; Tests for filter-related functions

;;; Code:

(require 'ert)
(require 'altodo)

(defvar test-buffer nil)

(defun setup-test-buffer ()
  "Create a test buffer with sample tasks."
  (setq test-buffer (get-buffer-create "*altodo-filter-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task 1\n")
    (insert "[x] Task 2\n")
    (insert "[@] Task 3\n")
    (insert "[w] Task 4\n")
    (insert "[~] Task 5\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  "Clean up test buffer."
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-line-done-p-on-done ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 1)
    (should (altodo--line-done-p)))
  (cleanup-test-buffer))

(ert-deftest test-line-done-p-on-open ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (should-not (altodo--line-done-p)))
  (cleanup-test-buffer))

(ert-deftest test-line-progress-p-on-progress ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 2)
    (should (altodo--line-progress-p)))
  (cleanup-test-buffer))

(ert-deftest test-line-progress-p-on-open ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (should-not (altodo--line-progress-p)))
  (cleanup-test-buffer))

(ert-deftest test-line-open-p-on-open ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (should (altodo--line-open-p)))
  (cleanup-test-buffer))

(ert-deftest test-line-open-p-on-done ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 1)
    (should-not (altodo--line-open-p)))
  (cleanup-test-buffer))

(ert-deftest test-line-has-tag-p-with-tag ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (end-of-line)
    (insert " #person")
    (beginning-of-line)
    (should (altodo--line-has-tag-p "person"))
    ;; A "@person" is a person tag, not a "#tag".
    (end-of-line)
    (insert " @bob")
    (beginning-of-line)
    (should (altodo--line-has-person-p "bob"))
    (should-not (altodo--line-has-tag-p "bob")))
  (cleanup-test-buffer))

(ert-deftest test-line-has-tag-p-without-tag ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (should-not (altodo--line-has-tag-p "person")))
  (cleanup-test-buffer))

(ert-deftest test-line-has-priority-p-without-priority ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (should-not (altodo--line-has-priority-p)))
  (cleanup-test-buffer))

(ert-deftest test-line-has-star-p-without-star ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (should-not (altodo--line-has-star-p)))
  (cleanup-test-buffer))

(provide 'filter-function-test)
;;; filter-function-test.el ends here
