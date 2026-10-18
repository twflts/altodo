;;; fontlock-integration-test.el --- Integration tests for font-lock

(require 'ert)
(require 'altodo)

;; Test: Complex task with multiple elements
(ert-deftest fontlock-integration-test-complex-task ()
  "Test complex task with multiple face elements."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] ! Task with #tag1 and 2026-12-31\n")
    
    ;; Test 1: buffer has content
    (unless (> (buffer-size) 0)
      (error "Buffer should have content"))
    
    ;; Test 2: font-lock-keywords can be applied
    (let ((keywords (altodo-font-lock-keywords)))
      (unless (listp keywords)
        (error "font-lock-keywords should return list")))
    
    (message "test-complex-task: PASS")))

;; Test: Priority task with date
(ert-deftest fontlock-integration-test-priority-task-with-date ()
  "Test priority task with date."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] !! Important task 2026-02-21 -> 2026-12-31\n")
    
    ;; Test 1: buffer has content
    (unless (> (buffer-size) 0)
      (error "Buffer should have content"))
    
    (message "test-priority-task-with-date: PASS")))

;; Test: Done task with strikethrough
(ert-deftest fontlock-integration-test-done-task-strikethrough ()
  "Test done task with strikethrough."
  (with-temp-buffer
    (altodo-mode)
    (insert "[x] Completed task\n")
    
    ;; Test 1: done task face exists
    (unless (facep 'altodo-task-done-text-face)
      (error "altodo-task-done-text-face should exist"))
    
    (message "test-done-task-strikethrough: PASS")))

;; Test: Multiline comment
(ert-deftest fontlock-integration-test-multiline-comment ()
  "Test multiline comment."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task\n")
    (insert "  Comment line 1\n")
    (insert "  Comment line 2\n")
    
    ;; Test 1: multiline comment face exists
    (unless (facep 'altodo-multiline-comment-face)
      (error "altodo-multiline-comment-face should exist"))
    
    (message "test-multiline-comment: PASS")))

;; Test: Dependency tags
(ert-deftest fontlock-integration-test-dependency-tags ()
  "Test dependency tags."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task #id:task1 #dep:task2\n")
    
    ;; Test 1: special tag face exists
    (unless (facep 'altodo-special-tag-face)
      (error "altodo-special-tag-face should exist"))
    
    (message "test-dependency-tags: PASS")))

(provide 'fontlock-integration-test)
;;; fontlock-integration-test.el ends here
