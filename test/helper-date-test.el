;;; helper-date-test.el --- Tests for date helper functions

(require 'package)
(package-initialize)
(load-file "altodo.el")

;; Test: altodo--parse-date
(defun test-parse-date ()
  "Test altodo--parse-date."
  ;; Test 1: ISO 8601 format (returns time value)
  (let ((result (altodo--parse-date "2026-02-21")))
    (unless (and result (listp result))
      (error "parse-date('2026-02-21') should return time value, got %s" result)))
  
  ;; Test 2: Invalid format
  (let ((result (altodo--parse-date "invalid")))
    (when result
      (error "parse-date('invalid') should return nil, got %s" result)))
  
  ;; Test 3: nil input
  (let ((result (altodo--parse-date nil)))
    (when result
      (error "parse-date(nil) should return nil, got %s" result)))
  
  (message "test-parse-date: PASS"))

;; Test: altodo--today-start
(defun test-today-start ()
  "Test altodo--today-start."
  ;; Test 1: returns time value (list)
  (let ((result (altodo--today-start)))
    (unless (listp result)
      (error "today-start() should return time value, got %s" result)))
  
  ;; Test 2: can be used with time-to-seconds
  (let ((result (altodo--today-start)))
    (unless (numberp (time-to-seconds result))
      (error "today-start() should return valid time value, got %s" result)))
  
  (message "test-today-start: PASS"))

;; Test: altodo--days-diff
(defun test-days-diff ()
  "Test altodo--days-diff."
  ;; Test 1: same date (today)
  (let ((result (altodo--days-diff (altodo--today-start))))
    (unless (= (round result) 0)
      (error "days-diff(today) should return ~0, got %f" result)))
  
  ;; Test 2: future date (tomorrow)
  (let* ((today (altodo--today-start))
         (tomorrow (time-add today (days-to-time 1)))
         (result (altodo--days-diff tomorrow)))
    (unless (= (round result) 1)
      (error "days-diff(tomorrow) should return ~1, got %f" result)))
  
  ;; Test 3: past date (yesterday)
  (let* ((today (altodo--today-start))
         (yesterday (time-subtract today (days-to-time 1)))
         (result (altodo--days-diff yesterday)))
    (unless (= (round result) -1)
      (error "days-diff(yesterday) should return ~-1, got %f" result)))
  
  (message "test-days-diff: PASS"))

;; Test: altodo--determine-start-date-face
(defun test-determine-start-date-face ()
  "Test altodo--determine-start-date-face."
  ;; Test 1: past date (started)
  (let ((result (altodo--determine-start-date-face "2020-01-01")))
    (unless (eq result 'altodo-date-start-active-face)
      (error "determine-start-date-face('2020-01-01') should return 'altodo-date-start-active-face', got %s" result)))
  
  ;; Test 2: today (started)
  (let* ((today (altodo--today-start))
         (today-str (format-time-string "%Y-%m-%d" today))
         (result (altodo--determine-start-date-face today-str)))
    (unless (eq result 'altodo-date-start-active-face)
      (error "determine-start-date-face(today) should return 'altodo-date-start-active-face', got %s" result)))
  
  ;; Test 3: future date (not started)
  (let ((result (altodo--determine-start-date-face "2030-12-31")))
    (unless (eq result 'altodo-date-face)
      (error "determine-start-date-face('2030-12-31') should return 'altodo-date-face', got %s" result)))
  
  (message "test-determine-start-date-face: PASS"))

;; Test: altodo--determine-due-date-face
(defun test-determine-due-date-face ()
  "Test altodo--determine-due-date-face."
  ;; Test 1: far past (overdue)
  (let ((result (altodo--determine-due-date-face "2020-01-01")))
    (unless (eq result 'altodo-date-due-overdue-face)
      (error "determine-due-date-face('2020-01-01') should return 'altodo-date-due-overdue-face', got %s" result)))
  
  ;; Test 2: today (due today)
  (let* ((today (altodo--today-start))
         (today-str (format-time-string "%Y-%m-%d" today))
         (result (altodo--determine-due-date-face today-str)))
    (unless (eq result 'altodo-date-due-today-face)
      (error "determine-due-date-face(today) should return 'altodo-date-due-today-face', got %s" result)))
  
  ;; Test 3: future date (not due)
  (let ((result (altodo--determine-due-date-face "2030-12-31")))
    (unless (eq result 'altodo-date-face)
      (error "determine-due-date-face('2030-12-31') should return 'altodo-date-face', got %s" result)))
  
  (message "test-determine-due-date-face: PASS"))

(defun run-all-tests ()
  "Run all date helper tests."
  (message "=== Running date helper tests ===")
  (test-parse-date)
  (test-today-start)
  (test-days-diff)
  (test-determine-start-date-face)
  (test-determine-due-date-face)
  (message "=== All tests passed ==="))

(run-all-tests)
