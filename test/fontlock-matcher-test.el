;;; fontlock-matcher-test.el --- Tests for font-lock matcher functions

(require 'ert)
(require 'altodo)

;; Test: altodo--start-date-matcher
(ert-deftest fontlock-matcher-test-start-date-matcher ()
  "Test altodo--start-date-matcher."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task 2026-02-21 -> Start date\n")
    (insert "[ ] Task without date\n")
    
    ;; Test 1: match start date
    (goto-char (point-min))
    (let ((result (altodo--start-date-matcher (line-end-position))))
      (unless result
        (error "start-date-matcher should match '2026-02-21 ->', got nil")))
    
    ;; Test 2: no match on line without date
    (forward-line 1)
    (let ((result (altodo--start-date-matcher (line-end-position))))
      (when result
        (error "start-date-matcher should not match line without date, got %s" result)))
    
    (message "test-start-date-matcher: PASS")))

;; Test: altodo--due-date-matcher
(ert-deftest fontlock-matcher-test-due-date-matcher ()
  "Test altodo--due-date-matcher."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task -> 2026-12-31 Due date\n")
    (insert "[ ] Task without date\n")
    
    ;; Test 1: match due date
    (goto-char (point-min))
    (let ((result (altodo--due-date-matcher (line-end-position))))
      (unless result
        (error "due-date-matcher should match '-> 2026-12-31', got nil")))
    
    ;; Test 2: no match on line without date
    (forward-line 1)
    (let ((result (altodo--due-date-matcher (line-end-position))))
      (when result
        (error "due-date-matcher should not match line without date, got %s" result)))
    
    (message "test-due-date-matcher: PASS")))

;; Test: altodo--tag-matcher
(ert-deftest fontlock-matcher-test-tag-matcher ()
  "Test altodo--tag-matcher."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task with #tag1 tag\n")
    (insert "[ ] Task without tag\n")
    
    ;; Test 1: match tag
    (goto-char (point-min))
    (let ((result (altodo--tag-matcher (line-end-position))))
      (unless result
        (error "tag-matcher should match '#tag1', got nil")))
    
    ;; Test 2: no match on line without tag
    (forward-line 1)
    (let ((result (altodo--tag-matcher (line-end-position))))
      (when result
        (error "tag-matcher should not match line without tag, got %s" result)))
    
    (message "test-tag-matcher: PASS")))

;; Test: altodo--person-tag-matcher
(ert-deftest fontlock-matcher-test-person-tag-matcher ()
  "Test altodo--person-tag-matcher."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task with @person tag\n")
    (insert "[ ] Task with @work tag\n")
    
    ;; Test 1: match @person tag
    (goto-char (point-min))
    (let ((result (altodo--person-tag-matcher (line-end-position))))
      (unless result
        (error "person-tag-matcher should match '@person', got nil")))
    
    ;; Test 2: match @work tag (person-tag-matcher matches all @ tags)
    (forward-line 1)
    (let ((result (altodo--person-tag-matcher (line-end-position))))
      (unless result
        (error "person-tag-matcher should match '@work', got nil")))
    
    (message "test-person-tag-matcher: PASS")))

;; Test: altodo--multiline-comment-matcher-new
(ert-deftest fontlock-matcher-test-multiline-comment-matcher-new ()
  "Test altodo--multiline-comment-matcher-new."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task\n")
    (insert "  Comment line 1\n")
    (insert "  Comment line 2\n")
    (insert "[ ] Next task\n")
    
    ;; Test 1: matcher exists and is callable
    (let ((result (functionp 'altodo--multiline-comment-matcher-new)))
      (unless result
        (error "multiline-comment-matcher-new should be a function, got %s" result)))
    
    (message "test-multiline-comment-matcher-new: PASS")))

(provide 'fontlock-matcher-test)
;;; fontlock-matcher-test.el ends here
