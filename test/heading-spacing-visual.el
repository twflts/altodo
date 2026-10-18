;; Visual test for heading spacing

(require 'ert)
(require 'altodo)

(ert-deftest heading-spacing-visual-test ()
  "Visual test showing display lines"
  (with-temp-buffer
    ;; Simulate file with empty line at start
    (insert "\n")  ;; Line 1: empty
    (insert "# Heading 1\n")  ;; Line 2
    (insert "[ ] Task 1\n")  ;; Line 3
    (insert "[ ] Task 2\n")  ;; Line 4
    (insert "\n")  ;; Line 5: empty
    (insert "# Heading 2\n")  ;; Line 6
    (insert "[x] Task 3\n")  ;; Line 7
    
    (let ((matched-lines '(3 4)))
      (let ((display-lines (altodo--compute-display-lines matched-lines 'all)))
        (message "Matched lines: %S" matched-lines)
        (message "Display lines: %S" (sort display-lines #'<))
        ;; Expected:
        ;; Line 1: empty (before first heading - added by helper)
        ;; Line 2: Heading 1 (first heading)
        ;; Line 3: Task 1 (matched, also next line after heading)
        ;; Line 4: Task 2 (matched)
        ;; Note: Line 5 is NOT added because line 3 is already the next line
        (should (member 1 display-lines))  ;; Before first heading
        (should (member 2 display-lines))  ;; Heading 1
        (should (member 3 display-lines))  ;; Task 1 (next line after heading)
        (should (member 4 display-lines))  ;; Task 2
        ))))

(provide 'heading-spacing-visual)
