;;; id-generation-test.el --- Tests for ID generation functions

(require 'ert)
(load-file "altodo.el")

(ert-deftest test-generate-uuidv7 ()
  (let ((result (altodo--generate-uuidv7)))
    (should (stringp result))))

(ert-deftest test-generate-custom-short-id ()
  (let ((result (altodo--generate-custom-short-id)))
    (should (stringp result))))

(ert-deftest test-generate-short-id-sortable ()
  (let ((result (altodo--generate-short-id-sortable)))
    (should (stringp result))))

(ert-deftest test-generate-short-id-random ()
  (let ((result (altodo--generate-short-id-random)))
    (should (stringp result))))

(ert-deftest test-generate-tiny-id-sortable ()
  (let ((result (altodo--generate-tiny-id-sortable)))
    (should (stringp result))))

(ert-deftest test-generate-tiny-id-random ()
  (let ((result (altodo--generate-tiny-id-random)))
    (should (stringp result))))

(provide 'id-generation-test)
