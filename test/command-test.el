;;; command-test.el --- Tests for altodo user commands

;;; Commentary:
;; Tests for interactive user commands

;;; Code:

(require 'ert)
(require 'altodo)

(defvar test-buffer nil)

(defun setup-test-buffer ()
  "Create a test buffer with sample tasks."
  (setq test-buffer (get-buffer-create "*altodo-test*"))
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

(ert-deftest test-toggle-task-state-open-to-done ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo-toggle-task-state)
    (should (looking-at "\\[x\\]")))
  (cleanup-test-buffer))

(ert-deftest test-set-task-done ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo-set-task-done)
    (should (looking-at "\\[x\\]")))
  (cleanup-test-buffer))

(ert-deftest test-set-task-open ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 1)
    (altodo-set-task-open)
    (should (looking-at "\\[ \\]")))
  (cleanup-test-buffer))

(ert-deftest test-task-p-on-task ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (should (altodo--task-p)))
  (cleanup-test-buffer))

(ert-deftest test-get-current-indent-no-indent ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (should (= (altodo--get-current-indent) 0)))
  (cleanup-test-buffer))

(ert-deftest test-normalize-indent-zero ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (should (= (altodo--normalize-indent 0) 0)))
  (cleanup-test-buffer))


(ert-deftest test-has-star-flag-p-with-star ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (should (altodo--has-star-flag-p "+ Task")))
  (cleanup-test-buffer))


(provide 'command-test)
;;; command-test.el ends here
