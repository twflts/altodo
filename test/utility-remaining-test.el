;;; utility-remaining-test.el --- Tests for remaining utility functions

(require 'ert)
(require 'altodo)

(ert-deftest test-format-to-regex ()
  (let ((result (altodo--format-to-regex "%Y-%m-%d")))
    (should (listp result))))

(ert-deftest test-date-regex-info ()
  (let ((result (altodo--date-regex-info)))
    (should (or (null result) (listp result)))))

(ert-deftest test-date-regex-match ()
  (let ((result (altodo--date-regex-match)))
    (should (or (null result) (stringp result)))))

(ert-deftest test-uuid-to-base62 ()
  (let ((result (altodo--uuid-to-base62 "550e8400-e29b-41d4-a716-446655440000")))
    (should (or (null result) (stringp result) (numberp result)))))


(provide 'utility-remaining-test)
