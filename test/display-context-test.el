;;; display-context-test.el --- Tests for :display-context option

(require 'ert)
(require 'altodo)

(ert-deftest test-compute-display-lines-none ()
  "Test :display-context none - show only matched lines"
  (let ((matched-lines '(5 10 15)))
    (let ((result (altodo--compute-display-lines matched-lines 'none)))
      (should (equal result '(5 10 15)))
      (message "DEBUG test-compute-display-lines-none: result=%S" result))))

(ert-deftest test-compute-display-lines-heading-only ()
  "Test :display-context heading-only - show matched lines + heading lines"
  (with-temp-buffer
    (insert "# Heading 1\n")           ; line 1
    (insert "[ ] Task 1\n")            ; line 2
    (insert "[ ] Task 2\n")            ; line 3
    (insert "\n")                      ; line 4
    (insert "# Heading 2\n")           ; line 5
    (insert "[x] Task 3\n")            ; line 6
    (insert "[x] Task 4\n")            ; line 7
    
    ;; Initialize heading ranges
    (altodo--compute-all-heading-ranges)
    
    ;; Test: matched lines 6, 7 (done tasks under Heading 2)
    (let ((matched-lines '(6 7)))
      (let ((result (altodo--compute-display-lines matched-lines 'heading-only)))
        (message "DEBUG test-compute-display-lines-heading-only: matched=%S result=%S" matched-lines result)
        ;; Should include matched lines (6, 7) and heading line (5)
        (should (member 6 result))
        (should (member 7 result))
        (should (member 5 result))
        ;; Should NOT include heading 1
        (should-not (member 1 result))))))

(ert-deftest test-compute-display-lines-all ()
  "Test :display-context all - show matched lines + heading + multiline comments"
  (with-temp-buffer
    (insert "# Heading 1\n")           ; line 1
    (insert "[ ] Task 1\n")            ; line 2
    (insert "    Comment line 1\n")      ; line 3 (multiline comment)
    (insert "    Comment line 2\n")      ; line 4 (multiline comment)
    (insert "\n")                      ; line 5
    (insert "# Heading 2\n")           ; line 6
    (insert "[x] Task 2\n")            ; line 7
    (insert "    Comment line 3\n")      ; line 8 (multiline comment)
    
    ;; Initialize heading ranges
    (altodo--compute-all-heading-ranges)
    
    ;; Test: matched line 7 (done task)
    (let ((matched-lines '(7)))
      (let ((result (altodo--compute-display-lines matched-lines 'all)))
        (message "DEBUG test-compute-display-lines-all: matched=%S result=%S" matched-lines result)
        ;; Should include matched line (7)
        (should (member 7 result))
        ;; Should include heading line (6)
        (should (member 6 result))
        ;; Should include multiline comment line (8)
        (should (member 8 result))))))

(ert-deftest test-compute-display-lines-multiple-matched ()
  "Test :display-context with multiple matched lines"
  (with-temp-buffer
    (insert "# Heading 1\n")           ; line 1
    (insert "[ ] Task 1\n")            ; line 2
    (insert "[x] Task 2\n")            ; line 3
    (insert "\n")                      ; line 4
    (insert "# Heading 2\n")           ; line 5
    (insert "[x] Task 3\n")            ; line 6
    (insert "[x] Task 4\n")            ; line 7
    
    ;; Initialize heading ranges
    (altodo--compute-all-heading-ranges)
    
    ;; Test: matched lines 3, 6, 7 (done tasks)
    (let ((matched-lines '(3 6 7)))
      (let ((result (altodo--compute-display-lines matched-lines 'heading-only)))
        (message "DEBUG test-compute-display-lines-multiple: matched=%S result=%S" matched-lines result)
        ;; Should include all matched lines
        (should (member 3 result))
        (should (member 6 result))
        (should (member 7 result))
        ;; Should include heading lines
        (should (member 1 result))
        (should (member 5 result))))))

(provide 'display-context-test)
;;; display-context-test.el ends here
