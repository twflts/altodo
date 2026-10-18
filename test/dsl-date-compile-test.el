;;; dsl-date-compile-test.el --- Tests for compiling date patterns  -*- lexical-binding: t; -*-

;;; Commentary:
;; due-date and start-date conditions are parsed once, when the pattern
;; is compiled, and an invalid condition does not raise errors per line.

;;; Code:

(require 'ert)
(require 'altodo)

(defun dsl-date-compile-test--compile (pattern)
  "Compile PATTERN and return (PREDICATE . MESSAGES)."
  (let (messages)
    (cl-letf (((symbol-function 'message)
               (lambda (format-string &rest args)
                 (push (apply #'format format-string args) messages))))
      (cons (altodo--compile-simple-pattern pattern) messages))))

(ert-deftest dsl-date-compile-test-invalid-due-condition ()
  "An invalid due-date condition is reported once, at compile time."
  (let* ((result (dsl-date-compile-test--compile "due-date:before:notadate"))
         (predicate (car result)))
    (should (= (length (cdr result)) 1))
    (should (string-match-p "Failed to compile pattern" (cadr result)))
    (with-temp-buffer
      (insert "[ ] a -> 2026-01-01\n[ ] b\n[ ] c -> 2026-02-01\n")
      (goto-char (point-min))
      (while (not (eobp))
        (should-not (funcall predicate))
        (forward-line 1)))))

(ert-deftest dsl-date-compile-test-invalid-start-condition ()
  "An invalid start-date condition is reported once, at compile time."
  (let* ((result (dsl-date-compile-test--compile "start-date:after:2026-13"))
         (predicate (car result)))
    (should (= (length (cdr result)) 1))
    (with-temp-buffer
      (insert "[ ] a 2026-01-01 ->\n")
      (goto-char (point-min))
      (should-not (funcall predicate)))))

(ert-deftest dsl-date-compile-test-parsed-once ()
  "The condition is parsed at compile time, not for each line."
  (let ((calls 0)
        (original (symbol-function 'altodo--parse-due-date-condition)))
    (cl-letf (((symbol-function 'altodo--parse-due-date-condition)
               (lambda (condition-str)
                 (setq calls (1+ calls))
                 (funcall original condition-str))))
      (let ((predicate (car (dsl-date-compile-test--compile
                             "due-date:before:2026-03-01"))))
        (should (= calls 1))
        (with-temp-buffer
          (dotimes (_ 50) (insert "[ ] task -> 2026-02-01\n"))
          (goto-char (point-min))
          (while (not (eobp))
            (should (funcall predicate))
            (forward-line 1)))
        (should (= calls 1))))))

(ert-deftest dsl-date-compile-test-valid-patterns ()
  "Valid due-date and start-date patterns match as before."
  (with-temp-buffer
    (insert "[ ] a 2026-01-01 -> 2026-02-01\n[ ] b\n")
    (goto-char (point-min))
    (let ((due (car (dsl-date-compile-test--compile
                     "due-date:between:2026-01-01:2026-12-31")))
          (start (car (dsl-date-compile-test--compile
                       "start-date:before:2026-06-01"))))
      (should (funcall due))
      (should (funcall start))
      (forward-line 1)
      (should-not (funcall due))
      (should-not (funcall start)))))

(provide 'dsl-date-compile-test)
;;; dsl-date-compile-test.el ends here
