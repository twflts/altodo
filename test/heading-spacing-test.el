;; Test for heading spacing (before/after newlines)

(require 'ert)
(require 'altodo)

(ert-deftest heading-spacing-first-heading-only ()
  "Test first heading gets newline after only"
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "[ ] Task 1\n")
    (insert "[ ] Task 2\n")
    (insert "# Heading 2\n")
    (insert "[x] Task 3\n")
    
    (let ((matched-lines '(2 3)))
      (let ((display-lines (altodo--compute-display-lines matched-lines 'all)))
        ;; First heading (1): should have line after (2)
        (should (member 1 display-lines))
        (should (member 2 display-lines))
        ;; Should NOT have line before first heading (0)
        (should (not (member 0 display-lines)))))))

(ert-deftest heading-spacing-second-heading-before-after ()
  "Test second heading gets newlines before and after"
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "[ ] Task 1\n")
    (insert "[ ] Task 2\n")
    (insert "# Heading 2\n")
    (insert "[x] Task 3\n")
    
    (let ((matched-lines '(5)))
      (let ((display-lines (altodo--compute-display-lines matched-lines 'all)))
        ;; Second heading (4): should have line before (3) and after (5)
        (should (member 3 display-lines))
        (should (member 4 display-lines))
        (should (member 5 display-lines))))))

(ert-deftest heading-spacing-no-duplicate-newlines ()
  "Test no duplicate newlines when spacing already exists"
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "[ ] Task 1\n")
    (insert "\n")  ;; Empty line
    (insert "# Heading 2\n")
    (insert "[x] Task 3\n")
    
    (let ((matched-lines '(2 5)))
      (let ((display-lines (altodo--compute-display-lines matched-lines 'all)))
        ;; Should include heading 1 (1), task 1 (2), empty line (3), heading 2 (4), task 3 (5)
        (should (member 1 display-lines))
        (should (member 2 display-lines))
        (should (member 3 display-lines))
        (should (member 4 display-lines))
        (should (member 5 display-lines))))))

(provide 'heading-spacing-test)
