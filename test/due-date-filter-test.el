;;; due-date-filter-test.el --- Tests for due date filter

;;; Commentary:
;; Tests for due date filter functionality

;;; Code:

(require 'ert)
(require 'altodo (expand-file-name "altodo.el"))

;;; Helper Functions

(defmacro due-date-test--with-buffer (content &rest body)
  "Execute BODY in a temporary buffer with CONTENT."
  `(with-temp-buffer
     (insert ,content)
     (goto-char (point-min))
     ,@body))

;;; Tests for altodo--line-due-date-p




;;; Tests for altodo--line-due-date-value

(ert-deftest due-date-test-line-due-date-value-with-due-date ()
  "Test altodo--line-due-date-value with due date."
  (due-date-test--with-buffer
   "[ ] Task -> 2026-12-31\n"
   (should (string= (altodo--line-due-date-value) "2026-12-31"))))

(ert-deftest due-date-test-line-due-date-value-without-due-date ()
  "Test altodo--line-due-date-value without due date."
  (due-date-test--with-buffer
   "[ ] Task\n"
   (should-not (altodo--line-due-date-value))))

(ert-deftest due-date-test-line-due-date-value-with-start-and-due ()
  "Test altodo--line-due-date-value with start and due date."
  (due-date-test--with-buffer
   "[ ] Task 2026-01-01 -> 2026-12-31\n"
   (should (string= (altodo--line-due-date-value) "2026-12-31"))))

;;; Tests for altodo--parse-due-date-condition

(ert-deftest due-date-test-parse-condition-overdue ()
  "Test parsing 'overdue' condition."
  (should (eq (altodo--parse-due-date-condition "overdue") 'overdue)))

(ert-deftest due-date-test-parse-condition-today ()
  "Test parsing 'today' condition."
  (should (eq (altodo--parse-due-date-condition "today") 'today)))

(ert-deftest due-date-test-parse-condition-tomorrow ()
  "Test parsing 'tomorrow' condition."
  (should (eq (altodo--parse-due-date-condition "tomorrow") 'tomorrow)))

(ert-deftest due-date-test-parse-condition-this-week ()
  "Test parsing 'this-week' condition."
  (should (eq (altodo--parse-due-date-condition "this-week") 'this-week)))

(ert-deftest due-date-test-parse-condition-this-month ()
  "Test parsing 'this-month' condition."
  (should (eq (altodo--parse-due-date-condition "this-month") 'this-month)))

(ert-deftest due-date-test-parse-condition-absolute-date ()
  "Test parsing absolute date condition."
  (should (string= (altodo--parse-due-date-condition "2026-12-31") "2026-12-31")))

(ert-deftest due-date-test-parse-condition-before ()
  "Test parsing 'before' condition."
  (should (equal (altodo--parse-due-date-condition "before:2026-12-31")
                 '(before "2026-12-31"))))

(ert-deftest due-date-test-parse-condition-after ()
  "Test parsing 'after' condition."
  (should (equal (altodo--parse-due-date-condition "after:2026-01-01")
                 '(after "2026-01-01"))))

(ert-deftest due-date-test-parse-condition-between ()
  "Test parsing 'between' condition."
  (should (equal (altodo--parse-due-date-condition "between:2026-01-01:2026-12-31")
                 '(between "2026-01-01" "2026-12-31"))))

(ert-deftest due-date-test-parse-condition-within ()
  "Test parsing 'within' condition."
  (should (equal (altodo--parse-due-date-condition "within:7")
                 '(within 7))))

(ert-deftest due-date-test-parse-condition-past ()
  "Test parsing 'past' condition."
  (should (equal (altodo--parse-due-date-condition "past:3")
                 '(past 3))))

(ert-deftest due-date-test-parse-condition-invalid ()
  "Test parsing invalid condition."
  (should-error (altodo--parse-due-date-condition "invalid")))

;;; Tests for altodo--due-date-matches-p

(ert-deftest due-date-test-matches-today ()
  "Test matching today's due date."
  (let* ((today (format-time-string "%Y-%m-%d" (current-time)))
         (content (format "[ ] Task -> %s\n" today)))
    (due-date-test--with-buffer
     content
     (should (altodo--due-date-matches-p 'today)))))

(ert-deftest due-date-test-matches-absolute-date ()
  "Test matching absolute date."
  (due-date-test--with-buffer
   "[ ] Task -> 2026-12-31\n"
   (should (altodo--due-date-matches-p "2026-12-31"))))

(ert-deftest due-date-test-no-match-different-date ()
  "Test no match with different date."
  (due-date-test--with-buffer
   "[ ] Task -> 2026-12-31\n"
   (should-not (altodo--due-date-matches-p "2026-01-01"))))

(ert-deftest due-date-test-matches-without-due-date ()
  "Test matching without due date returns nil."
  (due-date-test--with-buffer
   "[ ] Task\n"
   (should-not (altodo--due-date-matches-p 'today))))

;;; Tests for DSL Integration

(ert-deftest due-date-test-dsl-compile-overdue ()
  "Test DSL compilation for overdue condition."
  (let ((predicate (altodo--compile-simple-pattern "due-date:overdue")))
    (should (functionp predicate))))

(ert-deftest due-date-test-dsl-compile-today ()
  "Test DSL compilation for today condition."
  (let ((predicate (altodo--compile-simple-pattern "due-date:today")))
    (should (functionp predicate))))

(ert-deftest due-date-test-dsl-compile-absolute-date ()
  "Test DSL compilation for absolute date."
  (let ((predicate (altodo--compile-simple-pattern "due-date:2026-12-31")))
    (should (functionp predicate))))

;; ========================================
;; Abnormal condition tests
;; ========================================

(ert-deftest due-date-test-no-due-date ()
  "Test behavior when line has no due date."
  (due-date-test--with-buffer
   "[ ] Task without due date\n"
   (should-not (altodo--line-due-date-value))
   (should-not (altodo--due-date-matches-p 'today))
   (should-not (altodo--due-date-matches-p "2026-01-01"))))

(ert-deftest due-date-test-only-start-date ()
  "Test behavior when line has only start date (no due date)."
  (due-date-test--with-buffer
   "[ ] Task 2026-01-01 ->\n"
   (should-not (altodo--line-due-date-value))))

(ert-deftest due-date-test-invalid-condition ()
  "Test parsing invalid condition."
  (should-error (altodo--parse-due-date-condition "invalid-condition")))

(ert-deftest due-date-test-invalid-date-format ()
  "Test parsing invalid date format."
  (should-error (altodo--parse-due-date-condition "before:invalid-date")))

(ert-deftest due-date-test-empty-line ()
  "Test behavior on empty line."
  (due-date-test--with-buffer
   "\n"
   (should-not (altodo--line-due-date-value))))

(ert-deftest due-date-test-comment-line ()
  "Test behavior on comment line."
  (due-date-test--with-buffer
   "/// Comment line\n"
   (should-not (altodo--line-due-date-value))))

(ert-deftest due-date-test-matches-nil-condition ()
  "Test matching with nil condition."
  (due-date-test--with-buffer
   "[ ] Task -> 2026-12-31\n"
   (should-not (altodo--due-date-matches-p nil))))

(ert-deftest due-date-test-matches-unknown-symbol ()
  "Test matching with unknown symbol."
  (due-date-test--with-buffer
   "[ ] Task -> 2026-12-31\n"
   (should-not (altodo--due-date-matches-p 'unknown-symbol))))

;;; Run Tests

(provide 'due-date-filter-test)
;;; due-date-filter-test.el ends here
