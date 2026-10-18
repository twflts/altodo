;;; start-date-filter-test.el --- Tests for start date filter -*- lexical-binding: t; -*-

(require 'ert)
(require 'altodo)

;; Test helper macro
(defmacro start-date-test--with-buffer (content &rest body)
  "Execute BODY in a temp buffer with CONTENT."
  `(with-temp-buffer
     (insert ,content)
     (goto-char (point-min))
     ,@body))

;; ========================================
;; Helper function tests
;; ========================================

(ert-deftest start-date-test-line-start-date-p ()
  "Test altodo--line-start-date-p."
  (start-date-test--with-buffer
   "[ ] Task 2026-01-01 ->\n"
   (should (altodo--line-start-date-p)))
  
  (start-date-test--with-buffer
   "[ ] Task 2026-01-01 -> 2026-12-31\n"
   (should (altodo--line-start-date-p)))
  
  (start-date-test--with-buffer
   "[ ] Task -> 2026-12-31\n"
   (should-not (altodo--line-start-date-p)))
  
  (start-date-test--with-buffer
   "[ ] Task\n"
   (should-not (altodo--line-start-date-p))))

(ert-deftest start-date-test-line-start-date-value ()
  "Test altodo--line-start-date-value."
  (start-date-test--with-buffer
   "[ ] Task 2026-01-15 ->\n"
   (should (string= (altodo--line-start-date-value) "2026-01-15")))
  
  (start-date-test--with-buffer
   "[ ] Task 2026-01-15 -> 2026-12-31\n"
   (should (string= (altodo--line-start-date-value) "2026-01-15")))
  
  (start-date-test--with-buffer
   "[ ] Task -> 2026-12-31\n"
   (should-not (altodo--line-start-date-value)))
  
  (start-date-test--with-buffer
   "[ ] Task\n"
   (should-not (altodo--line-start-date-value))))

;; ========================================
;; Condition parser tests
;; ========================================

(ert-deftest start-date-test-parse-condition-relative ()
  "Test parsing relative date conditions."
  (should (eq (altodo--parse-start-date-condition "passed") 'passed))
  (should (eq (altodo--parse-start-date-condition "today") 'today))
  (should (eq (altodo--parse-start-date-condition "not-yet") 'not-yet))
  (should (eq (altodo--parse-start-date-condition "this-week") 'this-week))
  (should (eq (altodo--parse-start-date-condition "this-month") 'this-month)))

(ert-deftest start-date-test-parse-condition-absolute ()
  "Test parsing absolute date conditions."
  (should (string= (altodo--parse-start-date-condition "2026-12-31") "2026-12-31")))

(ert-deftest start-date-test-parse-condition-before ()
  "Test parsing before condition."
  (should (equal (altodo--parse-start-date-condition "before:2026-12-31")
                 '(before "2026-12-31"))))

(ert-deftest start-date-test-parse-condition-after ()
  "Test parsing after condition."
  (should (equal (altodo--parse-start-date-condition "after:2026-01-01")
                 '(after "2026-01-01"))))

(ert-deftest start-date-test-parse-condition-between ()
  "Test parsing between condition."
  (should (equal (altodo--parse-start-date-condition "between:2026-01-01:2026-12-31")
                 '(between "2026-01-01" "2026-12-31"))))

(ert-deftest start-date-test-parse-condition-within ()
  "Test parsing within condition."
  (should (equal (altodo--parse-start-date-condition "within:7")
                 '(within 7))))

(ert-deftest start-date-test-parse-condition-past ()
  "Test parsing past condition."
  (should (equal (altodo--parse-start-date-condition "past:3")
                 '(past 3))))

;; ========================================
;; Date matching tests
;; ========================================

(ert-deftest start-date-test-matches-absolute ()
  "Test absolute date matching."
  (start-date-test--with-buffer
   "[ ] Task 2026-12-31 ->\n"
   (should (altodo--start-date-matches-p "2026-12-31"))
   (should-not (altodo--start-date-matches-p "2026-01-01"))))

(ert-deftest start-date-test-matches-before ()
  "Test before condition."
  (start-date-test--with-buffer
   "[ ] Task 2026-01-15 ->\n"
   (should (altodo--start-date-matches-p '(before "2026-12-31")))
   (should-not (altodo--start-date-matches-p '(before "2026-01-01")))))

(ert-deftest start-date-test-matches-after ()
  "Test after condition."
  (start-date-test--with-buffer
   "[ ] Task 2026-12-31 ->\n"
   (should (altodo--start-date-matches-p '(after "2026-01-01")))
   (should-not (altodo--start-date-matches-p '(after "2027-01-01")))))

(ert-deftest start-date-test-matches-between ()
  "Test between condition."
  (start-date-test--with-buffer
   "[ ] Task 2026-06-15 ->\n"
   (should (altodo--start-date-matches-p '(between "2026-01-01" "2026-12-31")))
   (should-not (altodo--start-date-matches-p '(between "2027-01-01" "2027-12-31")))))

(ert-deftest start-date-test-matches-within ()
  "Test within condition."
  (start-date-test--with-buffer
   "[ ] Task 2026-12-31 ->\n"
   (should (altodo--start-date-matches-p '(within 365)))
   (should-not (altodo--start-date-matches-p '(within 1)))))

(ert-deftest start-date-test-matches-past ()
  "Test past condition."
  (start-date-test--with-buffer
   "[ ] Task 2025-01-01 ->\n"
   (should (altodo--start-date-matches-p '(past 365)))
   (should-not (altodo--start-date-matches-p '(past 1000)))))

;; ========================================
;; DSL integration tests
;; ========================================

(ert-deftest start-date-test-dsl-arg-types ()
  "Test that start-date is in DSL arg types."
  (should (member "start-date" altodo--dsl-arg-types)))

(ert-deftest start-date-test-dsl-compile-passed ()
  "Test DSL compilation for passed condition."
  (let ((pred (altodo--compile-simple-pattern "start-date:passed")))
    (should (functionp pred))
    (start-date-test--with-buffer
     "[ ] Task 2025-01-01 ->\n"
     (should (funcall pred)))))

(ert-deftest start-date-test-dsl-compile-today ()
  "Test DSL compilation for today condition."
  (let ((pred (altodo--compile-simple-pattern "start-date:today")))
    (should (functionp pred))))

(ert-deftest start-date-test-dsl-compile-not-yet ()
  "Test DSL compilation for not-yet condition."
  (let ((pred (altodo--compile-simple-pattern "start-date:not-yet")))
    (should (functionp pred))
    (start-date-test--with-buffer
     "[ ] Task 2027-12-31 ->\n"
     (should (funcall pred)))))

(ert-deftest start-date-test-dsl-compile-absolute ()
  "Test DSL compilation for absolute date."
  (let ((pred (altodo--compile-simple-pattern "start-date:2026-12-31")))
    (should (functionp pred))
    (start-date-test--with-buffer
     "[ ] Task 2026-12-31 ->\n"
     (should (funcall pred)))))

(ert-deftest start-date-test-dsl-compile-before ()
  "Test DSL compilation for before condition."
  (let ((pred (altodo--compile-simple-pattern "start-date:before:2027-01-01")))
    (should (functionp pred))
    (start-date-test--with-buffer
     "[ ] Task 2026-12-31 ->\n"
     (should (funcall pred)))))

(ert-deftest start-date-test-dsl-compile-after ()
  "Test DSL compilation for after condition."
  (let ((pred (altodo--compile-simple-pattern "start-date:after:2026-01-01")))
    (should (functionp pred))
    (start-date-test--with-buffer
     "[ ] Task 2026-12-31 ->\n"
     (should (funcall pred)))))

(ert-deftest start-date-test-dsl-compile-within ()
  "Test DSL compilation for within condition."
  (let ((pred (altodo--compile-simple-pattern "start-date:within:365")))
    (should (functionp pred))
    (start-date-test--with-buffer
     "[ ] Task 2026-12-31 ->\n"
     (should (funcall pred)))))

;; ========================================
;; Abnormal condition tests
;; ========================================

(ert-deftest start-date-test-no-start-date ()
  "Test behavior when line has no start date."
  (start-date-test--with-buffer
   "[ ] Task without start date\n"
   (should-not (altodo--line-start-date-p))
   (should-not (altodo--line-start-date-value))
   (should-not (altodo--start-date-matches-p 'today))
   (should-not (altodo--start-date-matches-p "2026-01-01"))))

(ert-deftest start-date-test-only-due-date ()
  "Test behavior when line has only due date (no start date)."
  (start-date-test--with-buffer
   "[ ] Task -> 2026-12-31\n"
   (should-not (altodo--line-start-date-p))
   (should-not (altodo--line-start-date-value))))

(ert-deftest start-date-test-invalid-condition ()
  "Test parsing invalid condition."
  (should-error (altodo--parse-start-date-condition "invalid-condition")))

(ert-deftest start-date-test-invalid-date-format ()
  "Test parsing invalid date format."
  (should-error (altodo--parse-start-date-condition "before:invalid-date")))

(ert-deftest start-date-test-empty-line ()
  "Test behavior on empty line."
  (start-date-test--with-buffer
   "\n"
   (should-not (altodo--line-start-date-p))
   (should-not (altodo--line-start-date-value))))

(ert-deftest start-date-test-comment-line ()
  "Test behavior on comment line."
  (start-date-test--with-buffer
   "/// Comment line\n"
   (should-not (altodo--line-start-date-p))
   (should-not (altodo--line-start-date-value))))

(ert-deftest start-date-test-matches-nil-condition ()
  "Test matching with nil condition."
  (start-date-test--with-buffer
   "[ ] Task 2026-01-01 ->\n"
   (should-not (altodo--start-date-matches-p nil))))

(ert-deftest start-date-test-matches-unknown-symbol ()
  "Test matching with unknown symbol."
  (start-date-test--with-buffer
   "[ ] Task 2026-01-01 ->\n"
   (should-not (altodo--start-date-matches-p 'unknown-symbol))))

;;; start-date-filter-test.el ends here
