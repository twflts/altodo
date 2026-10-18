;;; date-dst-test.el --- Tests for dates in a time zone with summer time  -*- lexical-binding: t; -*-

;;; Commentary:
;; T20261018-51: a day of 23 or 25 hours (the switch of summer time) must
;; still count as one day, and midnight must stay 00:00 in summer time.
;; The zone America/New_York switches on 2026-03-08 (23 hours) and
;; 2026-11-01 (25 hours).

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defmacro date-dst-test--in-new-york (&rest body)
  "Run BODY with the time zone America/New_York, then restore the zone."
  (declare (indent 0))
  `(unwind-protect
       (progn (set-time-zone-rule "America/New_York")
              ,@body)
     (set-time-zone-rule nil)))

(ert-deftest date-dst-test-parse-date-midnight-in-summer ()
  "A date in summer time is parsed as 00:00, not 01:00."
  (date-dst-test--in-new-york
    (should (equal (format-time-string "%F %T" (altodo--parse-date "2026-07-15"))
                   "2026-07-15 00:00:00"))
    (should (equal (format-time-string "%F %T" (altodo--parse-date "2026-01-15"))
                   "2026-01-15 00:00:00"))))

(ert-deftest date-dst-test-today-start-in-summer ()
  "`altodo--today-start' is 00:00 of today in summer time."
  (date-dst-test--in-new-york
    (altodo-test-with-today 2026 7 15
      (should (equal (format-time-string "%F %T" (altodo--today-start))
                     "2026-07-15 00:00:00")))))

(ert-deftest date-dst-test-days-diff-on-short-day ()
  "On the day of 23 hours, tomorrow is one day away."
  (date-dst-test--in-new-york
    (altodo-test-with-today 2026 3 8
      (should (= (altodo--days-diff (altodo--parse-date "2026-03-08")) 0))
      (should (= (altodo--days-diff (altodo--parse-date "2026-03-09")) 1))
      (should (= (altodo--days-diff (altodo--parse-date "2026-03-07")) -1)))))

(ert-deftest date-dst-test-days-diff-on-long-day ()
  "On the day of 25 hours, tomorrow is one day away."
  (date-dst-test--in-new-york
    (altodo-test-with-today 2026 11 1
      (should (= (altodo--days-diff (altodo--parse-date "2026-11-01")) 0))
      (should (= (altodo--days-diff (altodo--parse-date "2026-11-02")) 1))
      (should (= (altodo--days-diff (altodo--parse-date "2026-10-31")) -1)))))

(ert-deftest date-dst-test-days-diff-across-switch ()
  "The difference over the switch is a whole number of days."
  (date-dst-test--in-new-york
    (altodo-test-with-today 2026 3 7
      (should (= (altodo--days-diff (altodo--parse-date "2026-03-09")) 2))
      (should (= (altodo--days-diff (altodo--parse-date "2026-04-07")) 31)))))

(ert-deftest date-dst-test-tomorrow-condition-on-short-day ()
  "The `tomorrow' condition matches on the day of 23 hours."
  (date-dst-test--in-new-york
    (altodo-test-with-today 2026 3 8
      (altodo-test-with-buffer "[ ] a -> 2026-03-09\n"
        (should (altodo--due-date-matches-p 'tomorrow)))
      (altodo-test-with-buffer "[ ] a -> 2026-03-08\n"
        (should (altodo--due-date-matches-p 'today))))))

(provide 'date-dst-test)
;;; date-dst-test.el ends here
