;;; fontlock-facespec-test.el --- Tests for font-lock facespec

(require 'ert)
(require 'altodo)

;; Test: Static face application
(ert-deftest fontlock-facespec-test-static-face ()
  "Test static face application."
  ;; Test 1: altodo-task-bracket-face exists
  (unless (facep 'altodo-task-bracket-face)
    (error "altodo-task-bracket-face should exist"))
  
  ;; Test 2: altodo-task-open-text-face exists
  (unless (facep 'altodo-task-open-text-face)
    (error "altodo-task-open-text-face should exist"))
  
  (message "test-static-face: PASS"))

;; Test: Dynamic face (lambda)
(ert-deftest fontlock-facespec-test-dynamic-face-state ()
  "Test dynamic face for task states."
  ;; Test 1: get-state-face returns correct face for done
  (let ((result (altodo--get-state-face altodo-state-done)))
    (unless (eq result 'altodo-task-done-face)
      (error "get-state-face(done) should return 'altodo-task-done-face', got %s" result)))
  
  ;; Test 2: get-state-face returns correct face for open
  (let ((result (altodo--get-state-face altodo-state-open)))
    (unless (eq result 'altodo-task-open-face)
      (error "get-state-face(open) should return 'altodo-task-open-face', got %s" result)))
  
  (message "test-dynamic-face-state: PASS"))

;; Test: Dynamic face (date)
(ert-deftest fontlock-facespec-test-dynamic-face-date ()
  "Test dynamic face for dates."
  ;; Test 1: determine-start-date-face returns correct face for past
  (let ((result (altodo--determine-start-date-face "2020-01-01")))
    (unless (eq result 'altodo-date-start-active-face)
      (error "determine-start-date-face('2020-01-01') should return 'altodo-date-start-active-face', got %s" result)))
  
  ;; Test 2: determine-due-date-face returns correct face for overdue
  (let ((result (altodo--determine-due-date-face "2020-01-01")))
    (unless (eq result 'altodo-date-due-overdue-face)
      (error "determine-due-date-face('2020-01-01') should return 'altodo-date-due-overdue-face', got %s" result)))
  
  (message "test-dynamic-face-date: PASS"))

(provide 'fontlock-facespec-test)
;;; fontlock-facespec-test.el ends here
