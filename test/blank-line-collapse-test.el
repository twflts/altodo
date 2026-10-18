;; Test for blank line collapse feature

(require 'ert)
(load-file "altodo.el")

(ert-deftest blank-line-collapse-consecutive-blanks ()
  "Test collapsing consecutive blank lines"
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "\n")  ;; Line 2: blank
    (insert "\n")  ;; Line 3: blank
    (insert "[ ] Task 1\n")
    (insert "Text line\n")  ;; Line 5: not blank
    (insert "\n")  ;; Line 6: blank
    (insert "\n")  ;; Line 7: blank
    (insert "[ ] Task 2\n")
    
    (let ((matched-lines '(4 8)))
      (let ((display-lines (altodo--compute-display-lines matched-lines 'all)))
        (message "Display lines: %S" (sort display-lines #'<))
        ;; After collapse: consecutive blanks (3, 7) should be removed
        ;; Should NOT have: 3, 7
        (should (not (member 3 display-lines)))  ;; Collapsed
        (should (not (member 7 display-lines)))  ;; Collapsed
        ))))

(ert-deftest blank-line-collapse-single-blank ()
  "Test that single blank lines are preserved"
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "\n")  ;; Line 2: blank
    (insert "[ ] Task 1\n")
    
    (let ((matched-lines '(3)))
      (let ((display-lines (altodo--compute-display-lines matched-lines 'all)))
        (message "Display lines: %S" (sort display-lines #'<))
        ;; Should have: 1 (heading), 2 (blank), 3 (task)
        (should (member 1 display-lines))
        (should (member 2 display-lines))
        (should (member 3 display-lines))))))

(ert-deftest blank-line-collapse-no-blanks ()
  "Test when there are no blank lines"
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "[ ] Task 1\n")
    (insert "[ ] Task 2\n")
    
    (let ((matched-lines '(2 3)))
      (let ((display-lines (altodo--compute-display-lines matched-lines 'all)))
        (message "Display lines: %S" (sort display-lines #'<))
        ;; Should have: 1 (heading), 2 (task), 3 (task)
        (should (member 1 display-lines))
        (should (member 2 display-lines))
        (should (member 3 display-lines))))))

(provide 'blank-line-collapse-test)
