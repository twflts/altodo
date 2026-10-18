;;; debug-test.el --- Tests for debug functions

(require 'ert)
(load-file "altodo.el")

(defvar test-buffer nil)

(defun setup-test-buffer ()
  (setq test-buffer (get-buffer-create "*altodo-debug-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task 1\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-debug-enable ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo-debug-enable)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-debug-disable ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo-debug-disable)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-debug-add-function ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo-debug-add-function 'altodo-toggle-task-state)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-debug-remove-function ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo-debug-remove-function 'altodo-toggle-task-state)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-debug-clear-log ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo-debug-clear-log)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-debug-view-log ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo-debug-view-log)
    (should t))
  (cleanup-test-buffer))

(provide 'debug-test)
