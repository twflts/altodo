;; Test for heading newline feature

(require 'ert)
(require 'altodo)

(ert-deftest heading-newline-test-all-context ()
  "Test heading newline with 'all' display context"
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "[ ] Task 1\n")
    (insert "[ ] Task 2\n")
    (insert "## Heading 2\n")
    (insert "[x] Task 3\n")
    
    (let ((matched-lines '(2 3)))
      (let ((display-lines (altodo--compute-display-lines matched-lines 'all)))
        ;; Should include heading line (1), next line (2), matched lines (2, 3)
        (should (member 1 display-lines))
        (should (member 2 display-lines))
        (should (member 3 display-lines))))))

(ert-deftest heading-newline-test-heading-only-context ()
  "Test heading newline with 'heading-only' display context"
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "[ ] Task 1\n")
    (insert "[ ] Task 2\n")
    (insert "## Heading 2\n")
    (insert "[x] Task 3\n")
    
    (let ((matched-lines '(2 3)))
      (let ((display-lines (altodo--compute-display-lines matched-lines 'heading-only)))
        ;; Should include heading line (1), next line (2), and matched lines (2, 3)
        (should (member 1 display-lines))
        (should (member 2 display-lines))
        (should (member 3 display-lines))))))

(ert-deftest heading-newline-test-none-context ()
  "Test heading newline with 'none' display context"
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "[ ] Task 1\n")
    (insert "[ ] Task 2\n")
    (insert "## Heading 2\n")
    (insert "[x] Task 3\n")
    
    (let ((matched-lines '(2 3)))
      (let ((display-lines (altodo--compute-display-lines matched-lines 'none)))
        ;; Should only include matched lines (2, 3)
        (should (equal (sort display-lines #'<) '(2 3)))))))

(provide 'heading-newline-test)
