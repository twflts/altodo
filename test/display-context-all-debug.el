;; Debug test for :display-context all

(require 'ert)
(load-file "altodo.el")

(ert-deftest display-context-all-with-comments ()
  "Test :display-context all shows comments"
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "[ ] Task 1\n")
    (insert "    This is a multiline comment\n")
    (insert "    Another comment line\n")
    (insert "[ ] Task 2\n")
    
    (let ((matched-lines '(2 5)))
      (let ((display-lines (altodo--compute-display-lines matched-lines 'all)))
        (message "Matched lines: %S" matched-lines)
        (message "Display lines: %S" (sort display-lines #'<))
        ;; Expected: heading (1), task 1 (2), comments (3, 4), task 2 (5), and spacing
        (should (member 1 display-lines))  ;; Heading
        (should (member 2 display-lines))  ;; Task 1
        (should (member 3 display-lines))  ;; Comment 1
        (should (member 4 display-lines))  ;; Comment 2
        (should (member 5 display-lines))  ;; Task 2
        ))))

(provide 'display-context-all-debug)
