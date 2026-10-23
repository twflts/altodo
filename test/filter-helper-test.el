;;; filter-helper-test.el --- Unit tests for filter helper functions

(require 'ert)
(require 'altodo)

(ert-deftest filter-helper-test-filter-find-overlay ()
  "Test altodo--filter-find-overlay."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task 1\n")
    (insert "[ ] Task 2\n")
    (goto-char (point-min))
    
    ;; Create overlay for line 1
    (let* ((line1-start (line-beginning-position))
           (line1-end (line-end-position))
           (ov1 (altodo--filter-create-overlay line1-start line1-end nil)))
      
      ;; Test: find existing overlay
      (let ((found (altodo--filter-find-overlay line1-start line1-end)))
        (unless (eq found ov1)
          (error "Failed to find existing overlay")))
      
      ;; Test: find non-existing overlay
      (forward-line 1)
      (let* ((line2-start (line-beginning-position))
             (line2-end (line-end-position))
             (found (altodo--filter-find-overlay line2-start line2-end)))
        (when found
          (error "Found non-existing overlay")))
      
      (message "test-filter-find-overlay: PASS"))))

(ert-deftest filter-helper-test-filter-create-overlay ()
  "Test altodo--filter-create-overlay."
  (with-temp-buffer
    (altodo-mode)
    (insert "[ ] Task 1\n")
    (goto-char (point-min))
    
    (let* ((line-start (line-beginning-position))
           (line-end (line-end-position)))
      
      ;; Test: create visible overlay
      (let ((ov1 (altodo--filter-create-overlay line-start line-end nil)))
        (unless (overlayp ov1)
          (error "Should return an overlay"))
        (unless (eq (overlay-get ov1 'category) 'altodo-filter)
          (error "Category should be 'altodo-filter"))
        (unless (null (overlay-get ov1 'invisible))
          (error "Should be visible"))
        (unless (overlay-get ov1 'evaporate)
          (error "Should have evaporate property")))
      
      ;; Test: create invisible overlay
      (let ((ov2 (altodo--filter-create-overlay line-start line-end t)))
        (unless (overlay-get ov2 'invisible)
          (error "Should be invisible")))
      
      ;; Test: overlay added to list
      (unless (= (length altodo--filter-overlays) 2)
        (error "Should have 2 overlays in list"))
      
      (message "test-filter-create-overlay: PASS"))))

(provide 'filter-helper-test)
;;; filter-helper-test.el ends here
