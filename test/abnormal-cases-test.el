;;; abnormal-cases-test.el --- Tests for the abnormal cases of the design review  -*- lexical-binding: t; -*-

;;; Commentary:
;; T20261018-36: invalid dates, a failing filter predicate, `#id' matching,
;; an invalid auto-move interval, and an invalid .altodo-locals.el.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

;;; Dates

(ert-deftest abnormal-cases-date-that-does-not-exist-is-nil ()
  "A date that does not exist is not a date."
  (dolist (date '("2026-02-30" "2026-13-01" "2026-00-10" "2026-04-31"
                  "2026-01-00" "2025-02-29" "0000-01-01"))
    (should-not (altodo--parse-date date))))

(ert-deftest abnormal-cases-date-that-exists-is-parsed ()
  "Existing dates, including the end of month and leap days, are parsed."
  (dolist (date '("2026-02-28" "2024-02-29" "2000-02-29" "2026-12-31"
                  "2026-04-30" "0001-01-01" "9999-12-31"))
    (should (altodo--parse-date date))))

(ert-deftest abnormal-cases-invalid-date-matches-no-filter ()
  "A line with a date that does not exist matches no date condition."
  (altodo-test-with-today 2026 3 3
    (dolist (condition '(overdue today tomorrow this-week this-month))
      (altodo-test-with-buffer "[ ] a -> 2026-02-30\n"
        (should-not (altodo--due-date-matches-p condition))))
    (dolist (condition '(passed today not-yet this-week this-month))
      (altodo-test-with-buffer "[ ] a 2026-02-30 ->\n"
        (should-not (altodo--start-date-matches-p condition))))))

(ert-deftest abnormal-cases-invalid-date-is-not-overdue-face ()
  "A date that does not exist gets the plain date face."
  (altodo-test-with-today 2026 3 3
    (should (eq (altodo--determine-due-date-face "2026-02-30")
                'altodo-date-face))
    (should (eq (altodo--determine-start-date-face "2026-02-30")
                'altodo-date-face))))

(ert-deftest abnormal-cases-invalid-date-condition-is-rejected ()
  "A date condition with a date that does not exist is an error."
  (should-error (altodo--parse-due-date-condition "2026-02-30"))
  (should-error (altodo--parse-due-date-condition "before:2026-13-01")))

(ert-deftest abnormal-cases-relative-conditions-with-custom-date-format ()
  "Relative conditions use the real date when `altodo-date-format' is custom."
  (altodo-test-with-today 2026 3 3
    (let ((altodo-date-format "%Y/%m/%d"))
      (altodo-test-with-buffer "[ ] a -> 2099/01/01\n"
        (should-not (altodo--due-date-matches-p 'today))
        (should-not (altodo--due-date-matches-p 'overdue))
        (should-not (altodo--due-date-matches-p 'this-week)))
      (altodo-test-with-buffer "[ ] a -> 2026/03/03\n"
        (should (altodo--due-date-matches-p 'today)))
      (altodo-test-with-buffer "[ ] a -> 2026/03/01\n"
        (should (altodo--due-date-matches-p 'overdue)))
      (altodo-test-with-buffer "[ ] a 2026/03/01 ->\n"
        (should (altodo--start-date-matches-p 'passed))))))

;;; Filter

(ert-deftest abnormal-cases-failing-predicate-clears-the-filter ()
  "A predicate that fails halfway leaves no hidden lines."
  (altodo-test-with-buffer "[ ] a\n[x] b\n[ ] c\n"
    (let ((calls 0))
      (should-error
       (altodo--filter-lines
        (lambda ()
          (setq calls (1+ calls))
          (if (= calls 2) (error "Boom") t))))
      (should-not altodo--filter-overlays)
      (should-not (cl-some (lambda (overlay)
                             (overlay-get overlay 'invisible))
                           (overlays-in (point-min) (point-max)))))))

;;; #id

(ert-deftest abnormal-cases-id-prefix-with-hyphen-is-not-a-match ()
  "`#id:T1' does not match `#id:T1-2'."
  (altodo-test-with-buffer "[ ] x #id:T1-2\n[x] y #id:T1\n[ ] z #dep:T1\n"
    (should (equal (altodo--find-task-by-id "T1") "x"))
    (should (= (altodo--find-line-with-tag "id" "T1") 2))
    (goto-char (point-min))
    (forward-line 2)
    (should (eq (altodo--check-all-deps-completed
                 (altodo--get-task-deps (point)))
                'ready))))

(ert-deftest abnormal-cases-id-at-end-of-line-matches ()
  "An id at the end of the line, or before a space, matches."
  (altodo-test-with-buffer "[x] y #id:T1\n[ ] z #id:T2 #dep:T1\n"
    (should (= (altodo--find-line-with-tag "id" "T1") 1))
    (should (= (altodo--find-line-with-tag "id" "T2") 2))))

(ert-deftest abnormal-cases-duplicate-id-uses-the-first ()
  "With a duplicate `#id', the first one is used."
  (altodo-test-with-buffer "[x] a #id:A\n[ ] b #id:A\n[ ] c #dep:A\n"
    (should (equal (altodo--find-task-by-id "A") "x"))
    (should (= (altodo--find-line-with-tag "id" "A") 1))))

(ert-deftest abnormal-cases-self-dependency-is-circular ()
  "A task that depends on itself is circular."
  (altodo-test-with-buffer "[ ] a #id:A #dep:A\n"
    (should (eq (altodo--check-all-deps-completed
                 (altodo--get-task-deps (point)))
                'circular))))

;;; Auto-move interval

(ert-deftest abnormal-cases-invalid-interval-does-not-start-the-timer ()
  "A value other than a positive number is refused before a timer is set."
  (dolist (value '(0 -5 nil "abc"))
    (let ((altodo-auto-move-interval value)
          (altodo--auto-move-timer nil))
      (should-error (altodo-start-auto-move-timer) :type 'user-error)
      (should-not altodo--auto-move-timer))))

;;; .altodo-locals.el

(defun abnormal-cases-test--patterns (content)
  "Return the warnings and the patterns for a locals file with CONTENT."
  (altodo-test-with-temp-dir dir
    (with-temp-file (expand-file-name ".altodo-locals.el" dir) (insert content))
    (let ((altodo--locals-warnings nil)
          (warnings nil))
      (cl-letf (((symbol-function 'display-warning)
                 (lambda (_type message &rest _) (push message warnings))))
        (with-temp-buffer
          (setq buffer-file-name (expand-file-name "t.altodo" dir))
          (let ((first (altodo--get-filter-patterns))
                (second (altodo--get-filter-patterns)))
            (list (nreverse warnings) first second)))))))

(ert-deftest abnormal-cases-locals-syntax-error-warns-once ()
  "A syntax error gives defaults, and one warning for repeated reads."
  (let ((result (abnormal-cases-test--patterns "((altodo-filter-patterns . (")))
    (should (= (length (nth 0 result)) 1))
    (should (string-match-p "cannot read" (car (nth 0 result))))
    (should-not (nth 1 result))))

(ert-deftest abnormal-cases-locals-not-an-alist-is-ignored ()
  "Content that is not an alist is ignored with a warning."
  (dolist (content '("\"text\"" "42" "(1 2 3)"))
    (let ((result (abnormal-cases-test--patterns content)))
      (should (= (length (nth 0 result)) 1))
      (should (string-match-p "alist" (car (nth 0 result))))
      (should-not (nth 1 result)))))

(ert-deftest abnormal-cases-locals-invalid-entries-are-skipped ()
  "Entries without a string :title are skipped; the others are kept."
  (let ((result (abnormal-cases-test--patterns
                 "((altodo-filter-patterns . ((:title \"ok\" :type search-simple :pattern \"open\")
   (:type search-simple :pattern \"open\")
   \"oops\"
   5
   (:title 3 :type search-simple))))")))
    (should (= (length (nth 0 result)) 1))
    (should (string-match-p "ignored 4 invalid entries" (car (nth 0 result))))
    (should (equal (mapcar (lambda (entry) (plist-get entry :title))
                           (nth 1 result))
                   '("ok")))))

(ert-deftest abnormal-cases-locals-valid-file-gives-no-warning ()
  "A valid file gives no warning."
  (let ((result (abnormal-cases-test--patterns
                 "((altodo-filter-patterns . ((:title \"Group\" :type group-header)
   (:title \"Note\"))))")))
    (should-not (nth 0 result))
    (should (= (length (nth 1 result)) 2))))

(provide 'abnormal-cases-test)
;;; abnormal-cases-test.el ends here
