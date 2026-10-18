;; Debug test for heading spacing

(require 'ert)
(load-file "altodo.el")

(ert-deftest heading-spacing-first-heading-debug ()
  "Debug first heading spacing"
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "[ ] Task 1\n")
    (insert "[ ] Task 2\n")
    (insert "# Heading 2\n")
    (insert "[x] Task 3\n")
    
    (let ((matched-lines '(2 3)))
      (let ((display-lines (altodo--compute-display-lines matched-lines 'all)))
        (message "display-lines: %S" (sort display-lines #'<))
        ;; Expected: (1 2 3) for first heading
        ;; Line 1: Heading 1
        ;; Line 2: Task 1 (matched)
        ;; Line 3: Task 2 (matched)
        ;; Should NOT have line 0 (before heading)
        ;; Should have line 2 (after heading)
        (should (member 1 display-lines))
        (should (member 2 display-lines))
        (should (member 3 display-lines))
        (should (not (member 0 display-lines)))))))

(provide 'heading-spacing-debug)
