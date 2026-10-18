;; Debug test for heading spacing - detailed

(require 'ert)
(require 'altodo)

(ert-deftest heading-spacing-debug-detailed ()
  "Debug heading spacing in detail"
  (with-temp-buffer
    (insert "\n")  ;; Line 1: empty
    (insert "# Heading 1\n")  ;; Line 2
    (insert "[ ] Task 1\n")  ;; Line 3
    (insert "[ ] Task 2\n")  ;; Line 4
    (insert "\n")  ;; Line 5: empty
    (insert "# Heading 2\n")  ;; Line 6
    (insert "[x] Task 3\n")  ;; Line 7
    
    ;; Test helper function directly
    (let ((display-lines '(3 4)))
      (message "Before helper: %S" display-lines)
      (setq display-lines (altodo--add-heading-spacing display-lines 2))
      (message "After helper (heading 2): %S" (sort display-lines #'<))
      ;; Should have: 2 (heading), 3 (after heading), 3 (task), 4 (task)
      ;; Expected: (2 3 4)
      )))

(provide 'heading-spacing-debug2)
