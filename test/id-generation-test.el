;;; id-generation-test.el --- Tests for ID generation functions  -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'altodo)

(defun id-generation-test--base62-p (id max-length)
  "Return non-nil if ID is a non-empty Base62 string of up to MAX-LENGTH."
  (and (stringp id)
       (string-match-p "\\`[0-9A-Za-z]+\\'" id)
       (<= (length id) max-length)))

(ert-deftest id-generation-integer-to-base62 ()
  "Digits are 0-9, A-Z, a-z; zero is \"0\"."
  (should (equal (altodo--integer-to-base62 0) "0"))
  (should (equal (altodo--integer-to-base62 9) "9"))
  (should (equal (altodo--integer-to-base62 10) "A"))
  (should (equal (altodo--integer-to-base62 36) "a"))
  (should (equal (altodo--integer-to-base62 61) "z"))
  (should (equal (altodo--integer-to-base62 62) "10"))
  (should (equal (altodo--integer-to-base62 (* 62 62)) "100")))

(ert-deftest id-generation-uuid-format ()
  "A generated UUID is a version 7 UUID."
  (let ((uuid (altodo--generate-uuidv7)))
    (should (string-match-p
             "\\`[0-9a-f]\\{8\\}-[0-9a-f]\\{4\\}-7[0-9a-f]\\{3\\}-[0-9a-f]\\{4\\}-[0-9a-f]\\{12\\}\\'"
             uuid))))

(ert-deftest id-generation-short-ids-are-base62 ()
  "Short IDs are Base62 strings of up to 16 characters."
  (dolist (generator '(altodo--generate-short-id-sortable
                       altodo--generate-short-id-random))
    (dotimes (_ 20)
      (should (id-generation-test--base62-p (funcall generator) 16)))))

(ert-deftest id-generation-tiny-ids-are-base62 ()
  "Tiny IDs are Base62 strings of up to 10 characters."
  (dolist (generator '(altodo--generate-tiny-id-sortable
                       altodo--generate-tiny-id-random))
    (dotimes (_ 20)
      (should (id-generation-test--base62-p (funcall generator) 10)))))

(ert-deftest id-generation-sortable-ids-sort-by-time ()
  "A sortable ID made later sorts after an earlier one."
  (cl-letf (((symbol-function 'current-time) (lambda () '(0 1000 0 0))))
    (let ((early (altodo--generate-tiny-id-sortable)))
      (cl-letf (((symbol-function 'current-time) (lambda () '(0 2000 0 0))))
        (should (string< early (altodo--generate-tiny-id-sortable)))))))

(ert-deftest id-generation-generate-id-formats ()
  "`altodo--generate-id' follows `altodo-insert-id-format'."
  (dolist (case '((uuid . 36) (base62 . 22) (short . 16) (short-random . 16)
                  (tiny . 10) (tiny-random . 10)))
    (let ((altodo-insert-id-format (car case)))
      (should (<= (length (altodo--generate-id)) (cdr case))))))

(provide 'id-generation-test)
;;; id-generation-test.el ends here
