;;; indent-function-test.el --- Tests for indent functions

(require 'ert)
(require 'altodo)

(ert-deftest test-normalize-irregular-indent ()
  (should (= (altodo--normalize-irregular-indent 3 4) 0)))

(ert-deftest test-smart-indent ()
  (let ((result (altodo--smart-indent 1 0)))
    (should (numberp result))))

(ert-deftest test-cycle-indent ()
  (let ((result (altodo--cycle-indent 0)))
    (should (or (null result) (numberp result)))))

(ert-deftest test-initial-indent ()
  (let ((result (altodo--initial-indent 0)))
    (should (numberp result))))

(ert-deftest test-get-previous-task-indent ()
  (let ((buf (get-buffer-create "*test*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert "[ ] Task 1\n")
      (insert "    [ ] Task 2\n")
      (altodo-mode)
      (forward-line 1)
      (let ((result (altodo--get-previous-task-indent)))
        (should (or (null result) (numberp result)))))))

(provide 'indent-function-test)
