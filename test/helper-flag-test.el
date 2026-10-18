;;; helper-flag-test.el --- Tests for flag helper functions

(require 'package)
(package-initialize)
(load-file "altodo.el")

;; Test: altodo--has-star-flag-p
(defun test-has-star-flag-p ()
  "Test altodo--has-star-flag-p."
  ;; Test 1: with star flag
  (unless (altodo--has-star-flag-p "+ Task")
    (error "has-star-flag-p('+ Task') should return t"))
  
  ;; Test 2: with multiple stars
  (unless (altodo--has-star-flag-p "++ Task")
    (error "has-star-flag-p('++ Task') should return t"))
  
  ;; Test 3: with leading spaces
  (unless (altodo--has-star-flag-p "  + Task")
    (error "has-star-flag-p('  + Task') should return t"))
  
  ;; Test 4: without star flag
  (when (altodo--has-star-flag-p "Task")
    (error "has-star-flag-p('Task') should return nil"))
  
  ;; Test 5: with priority flag instead
  (when (altodo--has-star-flag-p "! Task")
    (error "has-star-flag-p('! Task') should return nil"))
  
  (message "test-has-star-flag-p: PASS"))

;; Test: altodo--remove-priority-from-string
(defun test-remove-priority-from-string ()
  "Test altodo--remove-priority-from-string."
  ;; Test 1: single priority
  (let ((result (altodo--remove-priority-from-string "! Task")))
    (unless (string= result "Task")
      (error "remove-priority('! Task') should return 'Task', got %s" result)))
  
  ;; Test 2: double priority
  (let ((result (altodo--remove-priority-from-string "!! Task")))
    (unless (string= result "Task")
      (error "remove-priority('!! Task') should return 'Task', got %s" result)))
  
  ;; Test 3: with leading spaces
  (let ((result (altodo--remove-priority-from-string "  ! Task")))
    (unless (string= result "Task")
      (error "remove-priority('  ! Task') should return 'Task', got %s" result)))
  
  ;; Test 4: no priority
  (let ((result (altodo--remove-priority-from-string "Task")))
    (unless (string= result "Task")
      (error "remove-priority('Task') should return 'Task', got %s" result)))
  
  ;; Test 5: star flag (should not remove)
  (let ((result (altodo--remove-priority-from-string "+ Task")))
    (unless (string= result "+ Task")
      (error "remove-priority('+ Task') should return '+ Task', got %s" result)))
  
  (message "test-remove-priority-from-string: PASS"))

;; Test: altodo--remove-star-from-string
(defun test-remove-star-from-string ()
  "Test altodo--remove-star-from-string."
  ;; Test 1: single star
  (let ((result (altodo--remove-star-from-string "+ Task")))
    (unless (string= result " Task")
      (error "remove-star('+ Task') should return ' Task', got %s" result)))
  
  ;; Test 2: double star (removes first +, keeps second)
  (let ((result (altodo--remove-star-from-string "++ Task")))
    (unless (string= result " + Task")
      (error "remove-star('++ Task') should return ' + Task', got %s" result)))
  
  ;; Test 3: with leading spaces
  (let ((result (altodo--remove-star-from-string "  + Task")))
    (unless (string= result " Task")
      (error "remove-star('  + Task') should return ' Task', got %s" result)))
  
  ;; Test 4: no star
  (let ((result (altodo--remove-star-from-string "Task")))
    (unless (string= result "Task")
      (error "remove-star('Task') should return 'Task', got %s" result)))
  
  ;; Test 5: priority flag (should not remove)
  (let ((result (altodo--remove-star-from-string "! Task")))
    (unless (string= result "! Task")
      (error "remove-star('! Task') should return '! Task', got %s" result)))
  
  (message "test-remove-star-from-string: PASS"))

;; Test: altodo--get-flag-text-face
(defun test-get-flag-text-face ()
  "Test altodo--get-flag-text-face."
  ;; Test 1: star flag with open state (returns list)
  (let ((result (altodo--get-flag-text-face altodo-flag-star altodo-state-open)))
    (unless (and (listp result) (member 'altodo-star-text-face result))
      (error "get-flag-text-face(star, open) should contain 'altodo-star-text-face', got %s" result)))
  
  ;; Test 2: priority flag with open state (returns list)
  (let ((result (altodo--get-flag-text-face altodo-flag-priority altodo-state-open)))
    (unless (and (listp result) (member 'altodo-priority-text-face result))
      (error "get-flag-text-face(priority, open) should contain 'altodo-priority-text-face', got %s" result)))
  
  ;; Test 3: star flag with done state (returns list)
  (let ((result (altodo--get-flag-text-face altodo-flag-star altodo-state-done)))
    (unless (and (listp result) (member 'altodo-star-text-face result))
      (error "get-flag-text-face(star, done) should contain 'altodo-star-text-face', got %s" result)))
  
  ;; Test 4: priority flag with done state (returns list)
  (let ((result (altodo--get-flag-text-face altodo-flag-priority altodo-state-done)))
    (unless (and (listp result) (member 'altodo-priority-text-face result))
      (error "get-flag-text-face(priority, done) should contain 'altodo-priority-text-face', got %s" result)))
  
  ;; Test 5: unknown flag (returns base face only)
  (let ((result (altodo--get-flag-text-face "?" altodo-state-open)))
    (unless (eq result 'altodo-task-open-text-face)
      (error "get-flag-text-face(?, open) should return 'altodo-task-open-text-face', got %s" result)))
  
  (message "test-get-flag-text-face: PASS"))

(defun run-all-tests ()
  "Run all flag helper tests."
  (message "=== Running flag helper tests ===")
  (test-has-star-flag-p)
  (test-remove-priority-from-string)
  (test-remove-star-from-string)
  (test-get-flag-text-face)
  (message "=== All tests passed ==="))

(run-all-tests)
