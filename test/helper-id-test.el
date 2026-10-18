;;; helper-id-test.el --- Tests for ID helper functions

(require 'ert)
(require 'altodo)

;; Test: altodo--generate-id
(ert-deftest helper-id-test-generate-id ()
  "Test altodo--generate-id."
  ;; Test 1: returns string
  (let ((result (altodo--generate-id)))
    (unless (stringp result)
      (error "generate-id() should return string, got %s" (type-of result))))
  
  ;; Test 2: returns non-empty string
  (let ((result (altodo--generate-id)))
    (unless (> (length result) 0)
      (error "generate-id() should return non-empty string, got %s" result)))
  
  ;; Test 3: generates unique IDs
  (let ((id1 (altodo--generate-id))
        (id2 (altodo--generate-id)))
    (unless (not (string= id1 id2))
      (error "generate-id() should generate unique IDs, got %s and %s" id1 id2)))
  
  (message "test-generate-id: PASS"))

;; Test: altodo--find-task-by-id
(ert-deftest helper-id-test-find-task-by-id ()
  "Test altodo--find-task-by-id."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task 1 #id:abc123\n")
    (insert "[ ] Task 2 #id:def456\n")
    (insert "[ ] Task 3\n")
    
    ;; Test 1: find existing task
    (let ((result (altodo--find-task-by-id "abc123")))
      (unless (string= result altodo-state-open)
        (error "find-task-by-id('abc123') should return state, got %s" result)))
    
    ;; Test 2: find another task
    (let ((result (altodo--find-task-by-id "def456")))
      (unless (string= result altodo-state-open)
        (error "find-task-by-id('def456') should return state, got %s" result)))
    
    ;; Test 3: task not found
    (let ((result (altodo--find-task-by-id "notfound")))
      (when result
        (error "find-task-by-id('notfound') should return nil, got %s" result)))
    
    (message "test-find-task-by-id: PASS")))

;; Test: altodo--get-task-id
(ert-deftest helper-id-test-get-task-id ()
  "Test altodo--get-task-id."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task with ID #id:xyz789\n")
    (insert "[ ] Task without ID\n")
    
    ;; Test 1: get ID from task with ID
    (goto-char (point-min))
    (let ((result (altodo--get-task-id (point))))
      (unless (string= result "xyz789")
        (error "get-task-id() should return 'xyz789', got %s" result)))
    
    ;; Test 2: get ID from task without ID
    (forward-line 1)
    (let ((result (altodo--get-task-id (point))))
      (when result
        (error "get-task-id() should return nil, got %s" result)))
    
    (message "test-get-task-id: PASS")))

;; Test: altodo--get-task-deps
(ert-deftest helper-id-test-get-task-deps ()
  "Test altodo--get-task-deps."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task with deps #dep:id1 #dep:id2\n")
    (insert "[ ] Task without deps\n")
    
    ;; Test 1: get deps from task with deps
    (goto-char (point-min))
    (let ((result (altodo--get-task-deps (point))))
      (unless (and (listp result) (= (length result) 2))
        (error "get-task-deps() should return list of 2 elements, got %s" result)))
    
    ;; Test 2: get deps from task without deps
    (forward-line 1)
    (let ((result (altodo--get-task-deps (point))))
      (unless (null result)
        (error "get-task-deps() should return nil, got %s" result)))
    
    (message "test-get-task-deps: PASS")))

(provide 'helper-id-test)
;;; helper-id-test.el ends here
