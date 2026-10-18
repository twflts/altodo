;; Test for Setext heading syntax

(require 'ert)
(load-file "altodo.el")

(ert-deftest setext-heading-level-test ()
  "Test Setext heading level detection"
  (with-temp-buffer
    (insert "Heading 1\n")
    (insert "=========\n")
    (insert "[ ] Task 1\n")
    (insert "Heading 2\n")
    (insert "---\n")
    (insert "[x] Task 2\n")
    
    ;; Test level 1 (===)
    (goto-char (point-min))
    (should (equal (altodo--heading-level) 1))
    
    ;; Test level 2 (---)
    (forward-line 3)
    (should (equal (altodo--heading-level) 2))))

(ert-deftest setext-heading-text-test ()
  "Test Setext heading text extraction"
  (with-temp-buffer
    (insert "My Heading\n")
    (insert "==========\n")
    (insert "[ ] Task 1\n")
    
    ;; Test heading text
    (goto-char (point-min))
    (should (equal (altodo--heading-text) "My Heading"))))

(ert-deftest atx-heading-level-test ()
  "Test ATX heading level detection still works"
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "[ ] Task 1\n")
    (insert "## Heading 2\n")
    (insert "[x] Task 2\n")
    
    ;; Test level 1
    (goto-char (point-min))
    (should (equal (altodo--heading-level) 1))
    
    ;; Test level 2
    (forward-line 2)
    (should (equal (altodo--heading-level) 2))))

(ert-deftest atx-heading-text-test ()
  "Test ATX heading text extraction still works"
  (with-temp-buffer
    (insert "# My Heading\n")
    (insert "[ ] Task 1\n")
    
    ;; Test heading text
    (goto-char (point-min))
    (should (equal (altodo--heading-text) "My Heading"))))

(provide 'setext-test)
