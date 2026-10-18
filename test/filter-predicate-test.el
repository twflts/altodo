;;; filter-predicate-test.el --- Tests for filter predicate functions

(require 'ert)
(require 'altodo)

(ert-deftest filter-predicate-test-line-done-p ()
  "Test altodo--line-done-p."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Open task\n")
    (insert "[x] Done task\n")
    (insert "[@] Progress task\n")
    
    ;; Line 1: not done
    (goto-char (point-min))
    (when (altodo--line-done-p)
      (error "Line 1 should not be done"))
    
    ;; Line 2: done
    (forward-line 1)
    (unless (altodo--line-done-p)
      (error "Line 2 should be done"))
    
    ;; Line 3: not done
    (forward-line 1)
    (when (altodo--line-done-p)
      (error "Line 3 should not be done"))
    
    (message "test-line-done-p: PASS")))

(ert-deftest filter-predicate-test-line-progress-p ()
  "Test altodo--line-progress-p."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Open task\n")
    (insert "[@] Progress task\n")
    (insert "[x] Done task\n")
    
    ;; Line 1: not progress
    (goto-char (point-min))
    (when (altodo--line-progress-p)
      (error "Line 1 should not be progress"))
    
    ;; Line 2: progress
    (forward-line 1)
    (unless (altodo--line-progress-p)
      (error "Line 2 should be progress"))
    
    ;; Line 3: not progress
    (forward-line 1)
    (when (altodo--line-progress-p)
      (error "Line 3 should not be progress"))
    
    (message "test-line-progress-p: PASS")))

(ert-deftest filter-predicate-test-line-open-p ()
  "Test altodo--line-open-p."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Open task\n")
    (insert "[x] Done task\n")
    (insert "[@] Progress task\n")
    
    ;; Line 1: open
    (goto-char (point-min))
    (unless (altodo--line-open-p)
      (error "Line 1 should be open"))
    
    ;; Line 2: not open
    (forward-line 1)
    (when (altodo--line-open-p)
      (error "Line 2 should not be open"))
    
    ;; Line 3: not open
    (forward-line 1)
    (when (altodo--line-open-p)
      (error "Line 3 should not be open"))
    
    (message "test-line-open-p: PASS")))

(ert-deftest filter-predicate-test-line-has-tag-p ()
  "Test altodo--line-has-tag-p."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task without tag\n")
    (insert "[ ] Task with #person tag\n")
    (insert "[ ] Task with #work and #urgent tags\n")
    
    ;; Line 1: no tag
    (goto-char (point-min))
    (when (altodo--line-has-tag-p "person")
      (error "Line 1 should not have #person tag"))
    
    ;; Line 2: has @person
    (forward-line 1)
    (unless (altodo--line-has-tag-p "person")
      (error "Line 2 should have #person tag"))
    
    ;; Line 3: has @work and #urgent
    (forward-line 1)
    (unless (altodo--line-has-tag-p "work")
      (error "Line 3 should have #work tag"))
    (unless (altodo--line-has-tag-p "urgent")
      (error "Line 3 should have #urgent tag"))
    (when (altodo--line-has-tag-p "person")
      (error "Line 3 should not have #person tag"))
    
    (message "test-line-has-tag-p: PASS")))

(ert-deftest filter-predicate-test-line-has-priority-p ()
  "Test altodo--line-has-priority-p."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task without flag\n")
    (insert "[ ] ! Priority task\n")
    (insert "[ ] + Star task\n")
    (insert "[ ] !! High priority\n")
    
    ;; Line 1: no priority
    (goto-char (point-min))
    (when (altodo--line-has-priority-p)
      (error "Line 1 should not have priority"))
    
    ;; Line 2: has priority
    (forward-line 1)
    (unless (altodo--line-has-priority-p)
      (error "Line 2 should have priority"))
    
    ;; Line 3: no priority (has star)
    (forward-line 1)
    (when (altodo--line-has-priority-p)
      (error "Line 3 should not have priority"))
    
    ;; Line 4: has priority
    (forward-line 1)
    (unless (altodo--line-has-priority-p)
      (error "Line 4 should have priority"))
    
    (message "test-line-has-priority-p: PASS")))

(ert-deftest filter-predicate-test-line-has-star-p ()
  "Test altodo--line-has-star-p."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task without flag\n")
    (insert "[ ] + Star task\n")
    (insert "[ ] ! Priority task\n")
    (insert "[ ] + Star task 2\n")
    
    ;; Line 1: no star
    (goto-char (point-min))
    (when (altodo--line-has-star-p)
      (error "Line 1 should not have star"))
    
    ;; Line 2: has star
    (forward-line 1)
    (unless (altodo--line-has-star-p)
      (error "Line 2 should have star"))
    
    ;; Line 3: no star (has priority)
    (forward-line 1)
    (when (altodo--line-has-star-p)
      (error "Line 3 should not have star"))
    
    ;; Line 4: has star
    (forward-line 1)
    (unless (altodo--line-has-star-p)
      (error "Line 4 should have star"))
    
    (message "test-line-has-star-p: PASS")))

(provide 'filter-predicate-test)
;;; filter-predicate-test.el ends here
