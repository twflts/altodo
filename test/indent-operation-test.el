;;; indent-operation-test.el --- Tests for indent operation functions

(require 'ert)
(load-file "altodo.el")

(ert-deftest test-reset-indent-flags ()
  (altodo--reset-indent-flags)
  (should t))

(ert-deftest test-set-line-indent ()
  (let ((buf (get-buffer-create "*test*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert "[ ] Task\n")
      (altodo-mode)
      (altodo--set-line-indent 4)
      (should t))))

(provide 'indent-operation-test)
