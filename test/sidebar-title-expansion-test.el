;;; sidebar-title-expansion-test.el --- Tests for sidebar title expansion

;;; Commentary:
;; Tests for sidebar :title expansion with %n placeholder

;;; Code:

(require 'ert)
(require 'altodo)

;;; Basic Tests

(ert-deftest test-count-format-enabled ()
  "Test :count-format t replaces %n with match count."
  (with-temp-buffer
    (insert "[x] Done task 1\n")
    (insert "[x] Done task 2\n")
    (insert "[ ] Open task\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Done [x] %n" :pattern "done" :count-format t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Done [x] 2")))))

(ert-deftest test-count-format-disabled ()
  "Test :count-format nil does not replace %n."
  (with-temp-buffer
    (insert "[x] Done task 1\n")
    (insert "[x] Done task 2\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Done [x] %n" :pattern "done" :count-format nil)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Done [x] %n")))))

(ert-deftest test-count-format-omitted ()
  "Test :count-format omitted defaults to t."
  (with-temp-buffer
    (insert "[x] Done task 1\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Done [x] %n" :pattern "done")))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Done [x] 1")))))

(ert-deftest test-no-placeholder ()
  "Test :count-format is ignored when %n is not present."
  (with-temp-buffer
    (insert "[x] Done task 1\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Done [x]" :pattern "done" :count-format t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Done [x]")))))

(ert-deftest test-zero-count ()
  "Test match count of 0 is displayed correctly."
  (with-temp-buffer
    (insert "[ ] Open task\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Done [x] %n" :pattern "done" :count-format t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Done [x] 0")))))

(ert-deftest test-count-pattern-simple ()
  "Test :count-pattern-simple uses different pattern for counting."
  (with-temp-buffer
    (insert "[x] Done task\n")
    (insert "[ ] ! Priority task\n")
    (insert "[ ] Normal task\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Priority Tasks %n" 
                          :type search-simple
                          :pattern "done" 
                          :count-pattern-simple "priority"
                          :count-format t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Priority Tasks 1")))))

(ert-deftest test-count-pattern-lambda ()
  "Test :count-pattern-lambda uses lambda function for counting."
  (with-temp-buffer
    (insert "[x] Done task\n")
    (insert "[ ] ! Priority task\n")
    (insert "[ ] Normal task\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Priority Tasks %n"
                          :type search-lambda
                          :pattern (lambda () (altodo--line-done-p))
                          :count-pattern-lambda (lambda () (altodo--line-has-priority-p))
                          :count-format t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Priority Tasks 1")))))

(ert-deftest test-exclude-others-true ()
  "Test :count-exclude-others t counts only task lines."
  (with-temp-buffer
    (insert "[x] Done task\n")
    (insert "/// Comment\n")
    (insert "[x] Done task 2\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Done [x] %n" 
                          :pattern "done" 
                          :count-format t
                          :count-exclude-others t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Done [x] 2")))))

(ert-deftest test-exclude-others-nil ()
  "Test :count-exclude-others nil counts all matching lines."
  (with-temp-buffer
    (insert "[x] Done task\n")
    (insert "/// Comment\n")
    (insert "[x] Done task 2\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "All Matches %n"
                          :pattern "done"
                          :count-format t
                          :count-exclude-others nil)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "All Matches 2")))))

(ert-deftest test-exclude-others-default ()
  "Test :count-exclude-others defaults to t."
  (with-temp-buffer
    (insert "[x] Done task\n")
    (insert "/// Comment\n")
    (insert "[x] Done task 2\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Done [x] %n"
                          :pattern "done"
                          :count-format t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Done [x] 2")))))

(ert-deftest test-face-count-applied ()
  "Test :face-count applies face to count."
  (with-temp-buffer
    (insert "[x] Done task 1\n")
    (insert "[x] Done task 2\n")
    (altodo-mode)
    (let* ((pattern-spec '(:title "Done [x] %n"
                           :pattern "done"
                           :count-format t
                           :face-count altodo-done-text-face))
           (result (altodo--format-sidebar-title pattern-spec)))
      (should (string-match "Done \\[x\\] " result))
      (should (get-text-property (string-match "[0-9]" result) 'face result)))))

(ert-deftest test-face-count-omitted ()
  "Test :face-count omitted does not apply face."
  (with-temp-buffer
    (insert "[x] Done task 1\n")
    (altodo-mode)
    (let* ((pattern-spec '(:title "Done [x] %n"
                           :pattern "done"
                           :count-format t))
           (result (altodo--format-sidebar-title pattern-spec)))
      (should (string= result "Done [x] 1")))))

;;; Complex Tests

(ert-deftest test-complex-and-condition ()
  "Test match count with AND condition."
  (with-temp-buffer
    (insert "[x] ! Done priority task\n")
    (insert "[x] Done normal task\n")
    (insert "[ ] ! Open priority task\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Done Priority %n"
                          :pattern "and:done,priority"
                          :count-format t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Done Priority 1")))))

(ert-deftest test-complex-or-condition ()
  "Test match count with OR condition."
  (with-temp-buffer
    (insert "[x] Done task\n")
    (insert "[@] Progress task\n")
    (insert "[ ] Open task\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Done or Progress %n"
                          :pattern "or:done,progress"
                          :count-format t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Done or Progress 2")))))

(ert-deftest test-multiple-filters ()
  "Test multiple filter patterns with different counts."
  (with-temp-buffer
    (insert "[x] Done task 1\n")
    (insert "[x] Done task 2\n")
    (insert "[ ] Open task 1\n")
    (insert "[ ] Open task 2\n")
    (insert "[ ] Open task 3\n")
    (altodo-mode)
    (let ((done-spec '(:title "Done %n" :pattern "done" :count-format t))
          (open-spec '(:title "Open %n" :pattern "open" :count-format t)))
      (should (string= (altodo--format-sidebar-title done-spec) "Done 2"))
      (should (string= (altodo--format-sidebar-title open-spec) "Open 3")))))

(ert-deftest test-complex-nested-and-or ()
  "Test nested AND/OR conditions with tags."
  (with-temp-buffer
    (insert "[x] Done task #important\n")
    (insert "[x] Done task #normal\n")
    (insert "[@] Progress task #important\n")
    (insert "[ ] Open task #important\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Done/Progress + Important %n"
                          :pattern "and:or:done,progress,tag:important"
                          :count-format t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Done/Progress + Important 4")))))

(ert-deftest test-complex-not-condition ()
  "Test NOT condition with count."
  (with-temp-buffer
    (insert "[x] Done task\n")
    (insert "[ ] Open task 1\n")
    (insert "[ ] Open task 2\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Not Done %n"
                          :pattern "not:done"
                          :count-format t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Not Done 2")))))

(ert-deftest test-complex-tag-value ()
  "Test tag-value filter with count."
  (with-temp-buffer
    (insert "[ ] Task #priority:high\n")
    (insert "[ ] Task #priority:medium\n")
    (insert "[ ] Task #priority:low\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "High Priority %n"
                          :pattern "tag-value:priority high"
                          :count-format t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "High Priority 1")))))

(ert-deftest test-complex-tag-value-numeric ()
  "Test tag-value filter with numeric comparison."
  (with-temp-buffer
    (insert "[ ] Task #estimate:3\n")
    (insert "[ ] Task #estimate:5\n")
    (insert "[ ] Task #estimate:8\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Estimate > 5 %n"
                          :pattern "tag-value:estimate (> 5)"
                          :count-format t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Estimate > 5 1")))))

(ert-deftest test-complex-parent-task-regexp ()
  "Test parent-task-regexp filter with count."
  (with-temp-buffer
    (insert "[ ] Project Alpha\n")
    (insert "    [ ] Task 1\n")
    (insert "    [ ] Task 2\n")
    (insert "[ ] Project Beta\n")
    (insert "    [ ] Task 3\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Alpha Tasks %n"
                          :pattern "parent-task-regexp:Alpha"
                          :count-format t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Alpha Tasks 3")))))

(ert-deftest test-complex-root-task-regexp ()
  "Test root-task-regexp filter with count."
  (with-temp-buffer
    (insert "[ ] Root A\n")
    (insert "    [ ] Child A1\n")
    (insert "        [ ] Grandchild A1\n")
    (insert "[ ] Root B\n")
    (insert "    [ ] Child B1\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Root A Tasks %n"
                          :pattern "root-task-regexp:Root A"
                          :count-format t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Root A Tasks 3")))))

(ert-deftest test-complex-multiple-placeholders ()
  "Test multiple %n placeholders (all are replaced)."
  (with-temp-buffer
    (insert "[x] Done task 1\n")
    (insert "[x] Done task 2\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Done %n (Total %n)"
                          :pattern "done"
                          :count-format t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Done 2 (Total 2)")))))

(ert-deftest test-complex-face-with-and-condition ()
  "Test :face-count with AND condition."
  (with-temp-buffer
    (insert "[x] ! Done priority task\n")
    (insert "[x] Done normal task\n")
    (altodo-mode)
    (let* ((pattern-spec '(:title "Done Priority %n"
                           :pattern "and:done,priority"
                           :count-format t
                           :face-count altodo-done-text-face))
           (result (altodo--format-sidebar-title pattern-spec)))
      (should (string-match "Done Priority " result))
      (should (get-text-property (string-match "[0-9]" result) 'face result)))))

(ert-deftest test-complex-exclude-others-with-comments ()
  "Test :count-exclude-others with multiline comments."
  (with-temp-buffer
    (insert "[x] Done task\n")
    (insert "    Multiline comment line 1\n")
    (insert "    Multiline comment line 2\n")
    (insert "[x] Done task 2\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Done %n"
                          :pattern "done"
                          :count-format t
                          :count-exclude-others t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Done 2")))))

(ert-deftest test-complex-lambda-with-exclude-others ()
  "Test Lambda function with :count-exclude-others."
  (with-temp-buffer
    (insert "[x] Done task\n")
    (insert "/// Comment\n")
    (insert "[x] Done task 2\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Done %n"
                          :type search-lambda
                          :pattern (lambda () (altodo--line-done-p))
                          :count-format t
                          :count-exclude-others t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Done 2")))))

(ert-deftest test-complex-count-pattern-with-different-result ()
  "Test :count-pattern-simple with significantly different result."
  (with-temp-buffer
    (insert "[x] Done task\n")
    (insert "[x] Done task\n")
    (insert "[x] Done task\n")
    (insert "[ ] ! Priority task\n")
    (altodo-mode)
    (let ((pattern-spec '(:title "Filter: Done, Count: Priority %n"
                          :type search-simple
                          :pattern "done"
                          :count-pattern-simple "priority"
                          :count-format t)))
      (should (string= (altodo--format-sidebar-title pattern-spec) "Filter: Done, Count: Priority 1")))))

;;; Performance Test

(ert-deftest test-performance-large-buffer ()
  "Test performance with 5000 line buffer (should be < 100ms)."
  (with-temp-buffer
    ;; Create 5000 lines
    (dotimes (i 2500)
      (insert "[x] Done task\n")
      (insert "[ ] Open task\n"))
    (altodo-mode)
    (let ((pattern-spec '(:title "Done %n" :pattern "done" :count-format t))
          (start-time (current-time)))
      (altodo--format-sidebar-title pattern-spec)
      (let ((elapsed (float-time (time-subtract (current-time) start-time))))
        (message "Performance test: %.3f seconds for 5000 lines" elapsed)
        (should (< elapsed 0.1))))))  ; 100ms

(provide 'sidebar-title-expansion-test)
;;; sidebar-title-expansion-test.el ends here
