;;; filter-integration-test.el --- Integration tests for filter functions

(require 'ert)
(require 'altodo)

(ert-deftest filter-integration-test-filter-lines-show-done ()
  "Test filtering to show only done tasks."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task 1\n")
    (insert "[x] Task 2\n")
    (insert "[ ] Task 3\n")
    (insert "[x] Task 4\n")
    
    ;; Apply filter: show only done tasks
    (altodo--filter-lines
     (lambda ()
       (looking-at "^[ \t]*\\[x\\]")))
    
    ;; Check: 2 overlays created (for non-done tasks)
    (unless (= (length altodo--filter-overlays) 2)
      (error "Expected 2 overlays, got %d" (length altodo--filter-overlays)))
    
    ;; Check: line 1 is hidden
    (goto-char (point-min))
    (let ((ov (altodo--filter-find-overlay
               (line-beginning-position)
               (1+ (line-end-position)))))
      (unless (and ov (overlay-get ov 'invisible))
        (error "Line 1 should be hidden")))
    
    ;; Check: line 2 is visible
    (forward-line 1)
    (let ((ov (altodo--filter-find-overlay
               (line-beginning-position)
               (1+ (line-end-position)))))
      (when ov
        (error "Line 2 should be visible (no overlay)")))
    
    (message "test-filter-lines-show-done: PASS")))

(ert-deftest filter-integration-test-filter-clear ()
  "Test clearing all filters."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task 1\n")
    (insert "[x] Task 2\n")
    (insert "[ ] Task 3\n")
    
    ;; Apply filter
    (altodo--filter-lines
     (lambda ()
       (looking-at "^[ \t]*\\[x\\]")))
    
    ;; Check: overlays exist
    (unless (> (length altodo--filter-overlays) 0)
      (error "Expected overlays after filter"))
    
    ;; Clear filter
    (altodo-filter-clear)
    
    ;; Check: no overlays
    (unless (= (length altodo--filter-overlays) 0)
      (error "Expected no overlays after clear"))
    
    ;; Check: filter mode cleared
    (when altodo--filter-mode
      (error "Filter mode should be nil after clear"))
    
    (message "test-filter-clear: PASS")))

(ert-deftest filter-integration-test-filter-empty-buffer ()
  "Test filtering on empty buffer."
  (with-temp-buffer
    (altodo-mode)
    
    ;; Apply filter on empty buffer
    (altodo--filter-lines
     (lambda () t))
    
    ;; Check: no overlays
    (unless (= (length altodo--filter-overlays) 0)
      (error "Expected no overlays on empty buffer"))
    
    (message "test-filter-empty-buffer: PASS")))

(ert-deftest filter-integration-test-filter-all-match ()
  "Test filtering where all lines match."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task 1\n")
    (insert "[ ] Task 2\n")
    (insert "[ ] Task 3\n")
    
    ;; Apply filter: show all lines
    (altodo--filter-lines
     (lambda () t))
    
    ;; Check: no overlays (all lines visible)
    (unless (= (length altodo--filter-overlays) 0)
      (error "Expected no overlays when all lines match"))
    
    (message "test-filter-all-match: PASS")))

(ert-deftest filter-integration-test-filter-none-match ()
  "Test filtering where no lines match."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task 1\n")
    (insert "[ ] Task 2\n")
    (insert "[ ] Task 3\n")
    
    ;; Apply filter: hide all lines
    (altodo--filter-lines
     (lambda () nil))
    
    ;; Check: 3 overlays created (all lines hidden)
    (unless (= (length altodo--filter-overlays) 3)
      (error "Expected 3 overlays, got %d" (length altodo--filter-overlays)))
    
    (message "test-filter-none-match: PASS")))

(provide 'filter-integration-test)
;;; filter-integration-test.el ends here
