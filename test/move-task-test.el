;;; move-task-test.el --- Tests for altodo move task functions

;;; Commentary:
;; Tests for move task-related functions

;;; Code:

(require 'ert)
(require 'altodo)

(defvar test-buffer nil)
(defvar done-file nil)

(defun setup-test-buffer ()
  "Create a test buffer with sample tasks."
  (setq test-buffer (get-buffer-create "*altodo-move-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task 1\n")
    (insert "[x] Task 2\n")
    (insert "[@] Task 3\n")
    (insert "[~] Task 4\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  "Clean up test buffer."
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-is-done-or-cancelled-task-done ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 1)
    (should (altodo--is-done-or-cancelled-task)))
  (cleanup-test-buffer))

(ert-deftest test-is-done-or-cancelled-task-cancelled ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 3)
    (should (altodo--is-done-or-cancelled-task)))
  (cleanup-test-buffer))

(ert-deftest test-is-done-or-cancelled-task-open ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (should-not (altodo--is-done-or-cancelled-task)))
  (cleanup-test-buffer))

(ert-deftest test-is-done-or-cancelled-task-progress ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 2)
    (should-not (altodo--is-done-or-cancelled-task)))
  (cleanup-test-buffer))

(ert-deftest test-extract-task-line ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (let ((line (altodo--extract-task-line)))
      (should (stringp line))))
  (cleanup-test-buffer))

(provide 'move-task-test)
;;; move-task-test.el ends here
