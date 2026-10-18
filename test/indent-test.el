;;; indent-test.el --- Tests for altodo indent functions

;;; Commentary:
;; Tests for indent-related functions

;;; Code:

(require 'ert)
(require 'altodo)

(defvar test-buffer nil)

(defun setup-test-buffer ()
  "Create a test buffer with sample tasks."
  (setq test-buffer (get-buffer-create "*altodo-indent-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task 1\n")
    (insert "    [ ] Task 1.1\n")
    (insert "        [ ] Task 1.1.1\n")
    (insert "[ ] Task 2\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  "Clean up test buffer."
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest test-get-line-indent-zero ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (goto-char (point-min))
    (should (= (altodo--get-line-indent (point-min)) 0)))
  (cleanup-test-buffer))

(ert-deftest test-get-line-indent-four ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 1)
    (should (= (altodo--get-line-indent (point-at-bol)) 4)))
  (cleanup-test-buffer))

(ert-deftest test-get-line-indent-eight ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 2)
    (should (= (altodo--get-line-indent (point-at-bol)) 8)))
  (cleanup-test-buffer))

(ert-deftest test-normalize-indent-four ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (should (= (altodo--normalize-indent 4) 4)))
  (cleanup-test-buffer))

(ert-deftest test-normalize-indent-eight ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (should (= (altodo--normalize-indent 8) 8)))
  (cleanup-test-buffer))

(ert-deftest test-normalize-indent-invalid-three ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (should (= (altodo--normalize-indent 3) 4)))
  (cleanup-test-buffer))

(ert-deftest test-normalize-indent-invalid-five ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (should (= (altodo--normalize-indent 5) 8)))
  (cleanup-test-buffer))

(ert-deftest test-previous-line-empty-p-false ()
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-mode)
    (forward-line 1)
    (should-not (altodo--previous-line-empty-p)))
  (cleanup-test-buffer))

(provide 'indent-test)
;;; indent-test.el ends here
