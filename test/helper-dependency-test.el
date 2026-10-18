;;; helper-dependency-test.el --- Tests for dependency helper functions

(require 'package)
(package-initialize)
(load-file "altodo.el")

;; Test: altodo--check-circular-dependency
(defun test-check-circular-dependency ()
  "Test altodo--check-circular-dependency."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task A #id:a #dep:b\n")
    (insert "[ ] Task B #id:b #dep:a\n")
    (insert "[ ] Task C #id:c\n")
    
    ;; Test 1: circular dependency detected (using catch)
    (let ((result (catch 'circular
                    (altodo--check-circular-dependency "a")
                    'ready)))
      (unless (eq result 'circular)
        (error "check-circular-dependency('a') should return 'circular', got %s" result)))
    
    ;; Test 2: no circular dependency
    (let ((result (catch 'circular
                    (altodo--check-circular-dependency "c")
                    'ready)))
      (unless (eq result 'ready)
        (error "check-circular-dependency('c') should return 'ready', got %s" result)))
    
    (message "test-check-circular-dependency: PASS")))

;; Test: altodo--check-all-deps-completed
(defun test-check-all-deps-completed ()
  "Test altodo--check-all-deps-completed."
  (with-temp-buffer
    (altodo-mode)
    (insert "[x] Task A #id:a\n")
    (insert "[x] Task B #id:b\n")
    (insert "[ ] Task C #id:c #dep:a #dep:b\n")
    (insert "[ ] Task D #id:d #dep:e\n")
    
    ;; Test 1: all deps completed
    (let ((result (altodo--check-all-deps-completed '("a" "b"))))
      (unless (eq result 'ready)
        (error "check-all-deps-completed(('a' 'b')) should return 'ready', got %s" result)))
    
    ;; Test 2: not all deps completed (e is not found, so ignored)
    (let ((result (altodo--check-all-deps-completed '("a" "e"))))
      (unless (eq result 'ready)
        (error "check-all-deps-completed(('a' 'e')) should return 'ready' (e not found), got %s" result)))
    
    ;; Test 3: empty deps
    (let ((result (altodo--check-all-deps-completed nil)))
      (unless (eq result 'ready)
        (error "check-all-deps-completed(nil) should return 'ready', got %s" result)))
    
    ;; Test 4: incomplete dep
    (let ((result (altodo--check-all-deps-completed '("a" "c"))))
      (unless (eq result 'blocked)
        (error "check-all-deps-completed(('a' 'c')) should return 'blocked', got %s" result)))
    
    (message "test-check-all-deps-completed: PASS")))

(defun run-all-tests ()
  "Run all dependency helper tests."
  (message "=== Running dependency helper tests ===")
  (test-check-circular-dependency)
  (test-check-all-deps-completed)
  (message "=== All tests passed ==="))

(run-all-tests)
