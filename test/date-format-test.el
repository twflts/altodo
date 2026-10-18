;;; date-format-test.el --- Tests for altodo-date-format handling  -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for `altodo-date-format': regex generation, parsing, normalization
;; and date conditions with formats other than YYYY-MM-DD.

;;; Code:

(require 'ert)
(require 'altodo)

(defconst date-format-test--cases
  '(("%Y-%m-%d" "2026-03-01" 1 2 3)
    ("%Y/%m/%d" "2026/03/01" 1 2 3)
    ("%d-%m-%Y" "01-03-2026" 3 2 1)
    ("%m/%d/%Y" "03/01/2026" 3 1 2)
    ("%Y年%m月%d日" "2026年03月01日" 1 2 3))
  "Each element is (FORMAT SAMPLE YEAR-IDX MONTH-IDX DAY-IDX).
SAMPLE is 2026-03-01 written in FORMAT.")

(ert-deftest date-format-test-group-indices ()
  "Group numbers follow the order of the specifiers in the format."
  (dolist (case date-format-test--cases)
    (pcase-let ((`(,format ,_sample ,year ,month ,day) case))
      (let ((info (altodo--format-to-regex format)))
        (should (equal (nthcdr 2 info) (list year month day)))))))

(ert-deftest date-format-test-parse-date ()
  "A date written in each format parses to the same time value."
  (let ((expected (altodo--parse-date "2026-03-01")))
    (should expected)
    (dolist (case date-format-test--cases)
      (let ((altodo-date-format (car case)))
        (should (equal (altodo--parse-date (nth 1 case)) expected))))))

(ert-deftest date-format-test-match-regex-has-no-capture-groups ()
  "The regex for font-lock matching must not add capture groups."
  (dolist (case date-format-test--cases)
    (let ((altodo-date-format (car case)))
      (should (= (regexp-opt-depth (altodo--date-regex-match)) 0)))))

(ert-deftest date-format-test-literal-is-quoted ()
  "A dot in the format is a literal dot, not any character."
  (let ((altodo-date-format "%Y.%m.%d"))
    (should (altodo--parse-date "2026.03.01"))
    (should-not (altodo--parse-date "2026x03x01"))))

(ert-deftest date-format-test-missing-specifier ()
  "A format without a day specifier makes parsing return nil."
  (let ((altodo-date-format "%Y/%m"))
    (should-not (altodo--parse-date "2026/03"))))

(ert-deftest date-format-test-default-is-iso ()
  "The default format (nil) is YYYY-MM-DD."
  (let ((altodo-date-format nil))
    (should (equal (nthcdr 2 (altodo--date-regex-info)) '(1 2 3)))
    (should (altodo--parse-date "2026-03-01"))))

(ert-deftest date-format-test-normalize-date-string ()
  "A date in any format is normalized to YYYY-MM-DD."
  (dolist (case date-format-test--cases)
    (let ((altodo-date-format (car case)))
      (should (equal (altodo--normalize-date-string (nth 1 case))
                     "2026-03-01")))))

(ert-deftest date-format-test-parse-conditions ()
  "Dates in due-date and start-date conditions are normalized."
  (let ((altodo-date-format "%d-%m-%Y"))
    (should (equal (altodo--parse-due-date-condition "before:01-03-2026")
                   '(before "2026-03-01")))
    (should (equal (altodo--parse-due-date-condition "after:01-03-2026")
                   '(after "2026-03-01")))
    (should (equal (altodo--parse-due-date-condition
                    "between:01-01-2026:31-12-2026")
                   '(between "2026-01-01" "2026-12-31")))
    (should (equal (altodo--parse-due-date-condition "01-03-2026")
                   "2026-03-01"))
    (should (equal (altodo--parse-start-date-condition "before:01-03-2026")
                   '(before "2026-03-01")))
    (should (equal (altodo--parse-start-date-condition "01-03-2026")
                   "2026-03-01"))))

(ert-deftest date-format-test-invalid-condition-date ()
  "A date that does not match the format is an error."
  (let ((altodo-date-format "%Y/%m/%d"))
    (should-error (altodo--parse-due-date-condition "before:2026-03-01"))))

(ert-deftest date-format-test-due-date-matches ()
  "due-date conditions work on a line written in a custom format."
  (let ((altodo-date-format "%Y/%m/%d"))
    (with-temp-buffer
      (insert "[ ] task -> 2026/02/01\n")
      (goto-char (point-min))
      (should (equal (altodo--line-due-date-value) "2026-02-01"))
      (should (altodo--due-date-matches-p
               (altodo--parse-due-date-condition "before:2026/03/01")))
      (should-not (altodo--due-date-matches-p
                   (altodo--parse-due-date-condition "after:2026/03/01")))
      (should (altodo--due-date-matches-p
               (altodo--parse-due-date-condition "2026/02/01")))
      (should (altodo--due-date-matches-p
               (altodo--parse-due-date-condition
                "between:2026/01/01:2026/12/31"))))))

(ert-deftest date-format-test-start-date-matches ()
  "start-date conditions work on a line written in a custom format."
  (let ((altodo-date-format "%Y/%m/%d"))
    (with-temp-buffer
      (insert "[ ] task 2026/02/01 ->\n")
      (goto-char (point-min))
      (should (equal (altodo--line-start-date-value) "2026-02-01"))
      (should (altodo--start-date-matches-p
               (altodo--parse-start-date-condition "before:2026/03/01")))
      (should-not (altodo--start-date-matches-p
                   (altodo--parse-start-date-condition "after:2026/03/01"))))))

(ert-deftest date-format-test-font-lock-matchers ()
  "The font-lock matchers find dates written in a custom format."
  (let ((altodo-date-format "%Y/%m/%d"))
    (with-temp-buffer
      (insert "[ ] task 2026/02/01 -> 2026/03/01\n")
      (goto-char (point-min))
      (should (altodo--start-date-matcher (point-max)))
      (should (equal (match-string 1) "2026/02/01"))
      (goto-char (point-min))
      (should (altodo--due-date-matcher (point-max)))
      (should (equal (match-string 1) "2026/03/01")))))

(provide 'date-format-test)
;;; date-format-test.el ends here
