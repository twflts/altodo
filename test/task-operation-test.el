;;; task-operation-test.el --- Tests for task operation functions

(require 'ert)
(load-file "altodo.el")

(defvar test-buffer nil)

(defun setup-test-buffer ()
  (setq test-buffer (get-buffer-create "*altodo-task-op-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task 1\n")
    (insert "[x] Task 2\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-add-task ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo-add-task)
    (should (> (line-number-at-pos) 1)))
  (cleanup-test-buffer))

(provide 'task-operation-test)
