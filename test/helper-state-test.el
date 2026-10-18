;;; helper-state-test.el --- Tests for state helper functions

(require 'package)
(package-initialize)
(load-file "altodo.el")

;; Test: altodo--normalize-state
(defun test-normalize-state ()
  "Test altodo--normalize-state."
  ;; Test 1: nil input
  (let ((result (altodo--normalize-state nil)))
    (unless (string= result altodo-state-open)
      (error "normalize-state(nil) should return altodo-state-open, got %s" result)))
  
  ;; Test 2: space input
  (let ((result (altodo--normalize-state " ")))
    (unless (string= result altodo-state-open)
      (error "normalize-state(' ') should return altodo-state-open, got %s" result)))
  
  ;; Test 3: empty string
  (let ((result (altodo--normalize-state "")))
    (unless (string= result altodo-state-open)
      (error "normalize-state('') should return altodo-state-open, got %s" result)))
  
  ;; Test 4: done state
  (let ((result (altodo--normalize-state "x")))
    (unless (string= result "x")
      (error "normalize-state('x') should return 'x', got %s" result)))
  
  ;; Test 5: progress state
  (let ((result (altodo--normalize-state "@")))
    (unless (string= result "@")
      (error "normalize-state('@') should return '@', got %s" result)))
  
  (message "test-normalize-state: PASS"))

;; Test: altodo--task-is-completed
(defun test-task-is-completed ()
  "Test altodo--task-is-completed."
  ;; Test 1: done state
  (unless (altodo--task-is-completed altodo-state-done)
    (error "task-is-completed(done) should return t"))
  
  ;; Test 2: cancelled state
  (unless (altodo--task-is-completed altodo-state-cancelled)
    (error "task-is-completed(cancelled) should return t"))
  
  ;; Test 3: open state
  (when (altodo--task-is-completed altodo-state-open)
    (error "task-is-completed(open) should return nil"))
  
  ;; Test 4: progress state
  (when (altodo--task-is-completed altodo-state-progress)
    (error "task-is-completed(progress) should return nil"))
  
  ;; Test 5: waiting state
  (when (altodo--task-is-completed altodo-state-waiting)
    (error "task-is-completed(waiting) should return nil"))
  
  (message "test-task-is-completed: PASS"))

;; Test: altodo--get-state-face
(defun test-get-state-face ()
  "Test altodo--get-state-face."
  ;; Test 1: done state
  (let ((result (altodo--get-state-face altodo-state-done)))
    (unless (eq result 'altodo-task-done-face)
      (error "get-state-face(done) should return 'altodo-task-done-face', got %s" result)))
  
  ;; Test 2: progress state
  (let ((result (altodo--get-state-face altodo-state-progress)))
    (unless (eq result 'altodo--task-progress-face)
      (error "get-state-face(progress) should return 'altodo--task-progress-face', got %s" result)))
  
  ;; Test 3: waiting state
  (let ((result (altodo--get-state-face altodo-state-waiting)))
    (unless (eq result 'altodo-task-waiting-face)
      (error "get-state-face(waiting) should return 'altodo-task-waiting-face', got %s" result)))
  
  ;; Test 4: cancelled state
  (let ((result (altodo--get-state-face altodo-state-cancelled)))
    (unless (eq result 'altodo-task-cancelled-face)
      (error "get-state-face(cancelled) should return 'altodo-task-cancelled-face', got %s" result)))
  
  ;; Test 5: open state
  (let ((result (altodo--get-state-face altodo-state-open)))
    (unless (eq result 'altodo-task-open-face)
      (error "get-state-face(open) should return 'altodo-task-open-face', got %s" result)))
  
  (message "test-get-state-face: PASS"))

;; Test: altodo--get-state-text-face
(defun test-get-state-text-face ()
  "Test altodo--get-state-text-face."
  ;; Test 1: done state
  (let ((result (altodo--get-state-text-face altodo-state-done)))
    (unless (eq result 'altodo-task-done-text-face)
      (error "get-state-text-face(done) should return 'altodo-task-done-text-face', got %s" result)))
  
  ;; Test 2: progress state
  (let ((result (altodo--get-state-text-face altodo-state-progress)))
    (unless (eq result 'altodo--task-progress-text-face)
      (error "get-state-text-face(progress) should return 'altodo--task-progress-text-face', got %s" result)))
  
  ;; Test 3: waiting state
  (let ((result (altodo--get-state-text-face altodo-state-waiting)))
    (unless (eq result 'altodo-task-waiting-text-face)
      (error "get-state-text-face(waiting) should return 'altodo-task-waiting-text-face', got %s" result)))
  
  ;; Test 4: cancelled state
  (let ((result (altodo--get-state-text-face altodo-state-cancelled)))
    (unless (eq result 'altodo-task-cancelled-text-face)
      (error "get-state-text-face(cancelled) should return 'altodo-task-cancelled-text-face', got %s" result)))
  
  ;; Test 5: open state
  (let ((result (altodo--get-state-text-face altodo-state-open)))
    (unless (eq result 'altodo-task-open-text-face)
      (error "get-state-text-face(open) should return 'altodo-task-open-text-face', got %s" result)))
  
  (message "test-get-state-text-face: PASS"))

(defun run-all-tests ()
  "Run all state helper tests."
  (message "=== Running state helper tests ===")
  (test-normalize-state)
  (test-task-is-completed)
  (test-get-state-face)
  (test-get-state-text-face)
  (message "=== All tests passed ==="))

(run-all-tests)
