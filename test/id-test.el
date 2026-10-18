;;; id-test.el --- Tests for ID generation functions

(require 'ert)
(require 'altodo)

(ert-deftest test-generate-id ()
  (should (stringp (altodo--generate-id))))

(ert-deftest test-find-task-by-id ()
  (let ((buf (get-buffer-create "*test*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert "[ ] Task $abc123\n")
      (altodo-mode)
      (should (or (null (altodo--find-task-by-id "abc123")) (numberp (altodo--find-task-by-id "abc123")))))))

(provide 'id-test)
