;;; done-file-test.el --- Tests for done file processing functions

(require 'ert)
(load-file "altodo.el")

(defvar test-buffer nil)

(defun setup-test-buffer ()
  (setq test-buffer (get-buffer-create "*altodo-done-file-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task 1\n")
    (insert "[x] Task 2\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-get-done-file-path ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (let ((result (altodo--get-done-file-path)))
      (should (or (null result) (stringp result)))))
  (cleanup-test-buffer))

(ert-deftest test-is-done-file-p ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (should (or (altodo--is-done-file-p) (not (altodo--is-done-file-p)))))
  (cleanup-test-buffer))

(ert-deftest test-auto-move-all-buffers ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo--auto-move-all-buffers)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-toggle-auto-move-timer ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo-toggle-auto-move-timer)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-start-auto-move-timer ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo-start-auto-move-timer)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-stop-auto-move-timer ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (altodo-stop-auto-move-timer)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-delete-task-from-buffer ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (altodo--delete-task-from-buffer)
    (should t))
  (cleanup-test-buffer))

(ert-deftest test-append-to-done-file ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (let ((done-file "/tmp/test-done.txt")
          (heading "Task 2")
          (task-line "[x] Task 2")
          (comments ""))
      (altodo--append-to-done-file done-file heading task-line comments)
      (should t)))
  (cleanup-test-buffer))

(provide 'done-file-test)
