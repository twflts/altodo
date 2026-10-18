;;; display-context-option-test.el --- Tests for :display-context option

(require 'ert)
(require 'altodo)

(ert-deftest test-display-context-default-value ()
  "Test that :display-context defaults to 'heading-only."
  (let ((pattern '(:title "Test" :type search-simple :pattern "done")))
    (should (eq (altodo--get-display-context-option pattern) 'heading-only))))

(ert-deftest test-display-context-all ()
  "Test :display-context 'all option."
  (let ((pattern '(:title "Test" :type search-simple :pattern "done" :display-context all)))
    (should (eq (altodo--get-display-context-option pattern) 'all))))

(ert-deftest test-display-context-heading-only ()
  "Test :display-context 'heading-only option."
  (let ((pattern '(:title "Test" :type search-simple :pattern "done" :display-context heading-only)))
    (should (eq (altodo--get-display-context-option pattern) 'heading-only))))

(ert-deftest test-display-context-none ()
  "Test :display-context 'none option."
  (let ((pattern '(:title "Test" :type search-simple :pattern "done" :display-context none)))
    (should (eq (altodo--get-display-context-option pattern) 'none))))

(ert-deftest test-compute-display-lines-none ()
  "Test compute-display-lines with 'none option."
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "[ ] Task 1\n")
    (insert "[ ] Task 2\n")
    (insert "# Heading 2\n")
    (insert "[x] Task 3\n")
    
    (let ((matched-lines '(2 5)))
      (let ((result (altodo--compute-display-lines matched-lines 'none)))
        (should (equal result '(2 5)))))))

(ert-deftest test-compute-display-lines-heading-only ()
  "Test compute-display-lines with 'heading-only option."
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "[ ] Task 1\n")
    (insert "[ ] Task 2\n")
    (insert "# Heading 2\n")
    (insert "[x] Task 3\n")
    
    (altodo--compute-all-heading-ranges)
    
    (let ((matched-lines '(2 5)))
      (let ((result (altodo--compute-display-lines matched-lines 'heading-only)))
        ;; Should include matched lines
        (should (member 2 result))
        (should (member 5 result))))))

(ert-deftest test-filter-lines-with-display-context-none ()
  "Test altodo--filter-lines with :display-context 'none."
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "[ ] Task 1\n")
    (insert "[ ] Task 2\n")
    (insert "# Heading 2\n")
    (insert "[x] Task 3\n")
    
    (altodo--filter-lines #'altodo--line-done-p t 'none)
    
    ;; Check that only done task is visible (no overlay)
    (should (not (altodo--filter-find-overlay (line-beginning-position 1) (line-end-position 1))))  ; Heading 1 hidden
    (should (not (altodo--filter-find-overlay (line-beginning-position 2) (line-end-position 2))))  ; Task 1 hidden
    (should (not (altodo--filter-find-overlay (line-beginning-position 3) (line-end-position 3))))  ; Task 2 hidden
    (should (not (altodo--filter-find-overlay (line-beginning-position 4) (line-end-position 4))))  ; Heading 2 hidden
    (should (not (altodo--filter-find-overlay (line-beginning-position 5) (line-end-position 5))))))  ; Task 3 visible

(ert-deftest test-filter-lines-with-display-context-heading-only ()
  "Test altodo--filter-lines with :display-context 'heading-only."
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "[ ] Task 1\n")
    (insert "[ ] Task 2\n")
    (insert "# Heading 2\n")
    (insert "[x] Task 3\n")
    
    (altodo--filter-lines #'altodo--line-done-p t 'heading-only)
    
    ;; Check that done task and its heading are visible
    (should (not (altodo--filter-find-overlay (line-beginning-position 4) (line-end-position 4))))  ; Heading 2 visible
    (should (not (altodo--filter-find-overlay (line-beginning-position 5) (line-end-position 5))))))  ; Task 3 visible

(provide 'display-context-option-test)
;;; display-context-option-test.el ends here
