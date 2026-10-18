;;; date-range-test.el --- Tests for this-week and this-month conditions  -*- lexical-binding: t; -*-

;;; Commentary:
;; `this-week' follows `altodo-week-start-day', and `this-month' includes
;; the last day of the month, for both due-date and start-date conditions.

;;; Code:

(require 'ert)
(require 'altodo)

(defun date-range-test--noon (year month day)
  "Return the time value of YEAR-MONTH-DAY at 12:00."
  (encode-time (list 0 0 12 day month year nil nil nil)))

(defun date-range-test--last-matching-offset (today condition)
  "Return the last offset in days from TODAY that matches CONDITION.
TODAY is (YEAR MONTH DAY).  Both due-date and start-date lines are
checked, and the offset must be the same for both.  Return nil if
the two differ."
  (cl-letf (((symbol-function 'current-time)
             (lambda () (apply #'date-range-test--noon today))))
    (let (results)
      (dolist (kind '(due start))
        (let ((last -1))
          (dotimes (offset 45)
            (let ((date (format-time-string
                         "%Y-%m-%d"
                         (time-add (apply #'date-range-test--noon today)
                                   (* offset 24 60 60)))))
              (with-temp-buffer
                (insert (if (eq kind 'due)
                            (format "[ ] a -> %s\n" date)
                          (format "[ ] a %s ->\n" date)))
                (goto-char (point-min))
                (when (if (eq kind 'due)
                          (altodo--due-date-matches-p condition)
                        (altodo--start-date-matches-p condition))
                  (setq last offset)))))
          (push last results)))
      (and (= (car results) (cadr results)) (car results)))))

(ert-deftest date-range-test-this-week ()
  "this-week ends on the last day of the week for each start day."
  ;; 2026-10-21 is Wednesday (3), 2026-10-18 Sunday (0),
  ;; 2026-10-19 Monday (1), 2026-10-24 Saturday (6).
  (dolist (today '((2026 10 21) (2026 10 18) (2026 10 19) (2026 10 24)))
    (let ((wday (nth 6 (decode-time (apply #'date-range-test--noon today)))))
      (dolist (week-start '(0 1 2 6))
        (let ((altodo-week-start-day week-start))
          (should (equal (date-range-test--last-matching-offset
                          today 'this-week)
                         (mod (- (+ week-start 6) wday) 7))))))))

(ert-deftest date-range-test-this-month ()
  "this-month ends on the last day of the month."
  ;; (TODAY . EXPECTED-LAST-OFFSET)
  (dolist (case '(((2026 10 18) . 13)
                  ((2028 2 20) . 9)
                  ((2026 2 28) . 0)
                  ((2026 12 30) . 1)
                  ((2026 1 31) . 0)
                  ((2026 4 1) . 29)))
    (should (equal (date-range-test--last-matching-offset
                    (car case) 'this-month)
                   (cdr case)))))

(ert-deftest date-range-test-days-to-week-end ()
  "altodo--days-to-week-end counts from today to the end of the week."
  (cl-letf (((symbol-function 'current-time)
             (lambda () (date-range-test--noon 2026 10 21))))
    (let ((altodo-week-start-day 1))
      (should (= (altodo--days-to-week-end) 4)))
    (let ((altodo-week-start-day 0))
      (should (= (altodo--days-to-week-end) 3)))
    (let ((altodo-week-start-day nil))
      (should (= (altodo--days-to-week-end) 4)))))

(provide 'date-range-test)
;;; date-range-test.el ends here
