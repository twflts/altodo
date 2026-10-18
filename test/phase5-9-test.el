;;; phase5-9-test.el --- Tests for Phase 5-9 tag-value filter -*- lexical-binding: t; -*-

(require 'ert)
(load-file "altodo.el")

;;; Helper Functions Tests

(ert-deftest test-string-to-valid-number-integer ()
  "Test integer conversion."
  (should (= (altodo--string-to-valid-number "5") 5))
  (should (= (altodo--string-to-valid-number "123") 123))
  (should (= (altodo--string-to-valid-number "-5") -5))
  (should (= (altodo--string-to-valid-number "+10") 10)))

(ert-deftest test-string-to-valid-number-float ()
  "Test float conversion."
  (should (= (altodo--string-to-valid-number "9.5") 9.5))
  (should (= (altodo--string-to-valid-number "0.5") 0.5))
  (should (= (altodo--string-to-valid-number ".5") 0.5))
  (should (= (altodo--string-to-valid-number "-4.5") -4.5)))

(ert-deftest test-string-to-valid-number-scientific ()
  "Test scientific notation conversion."
  (should (= (altodo--string-to-valid-number "1e5") 100000.0))
  (should (= (altodo--string-to-valid-number "1.5e3") 1500.0))
  (should (= (altodo--string-to-valid-number "1e-3") 0.001)))

(ert-deftest test-string-to-valid-number-leading-zero ()
  "Test leading zero conversion."
  (should (= (altodo--string-to-valid-number "010") 10))
  (should (= (altodo--string-to-valid-number "007") 7)))

(ert-deftest test-string-to-valid-number-invalid ()
  "Test invalid string conversion."
  (should-not (altodo--string-to-valid-number "abc"))
  (should-not (altodo--string-to-valid-number ""))
  (should-not (altodo--string-to-valid-number "5.5.5"))
  (should-not (altodo--string-to-valid-number nil)))

(ert-deftest test-extract-tag-value-with-quotes ()
  "Test quote removal."
  (should (string= (altodo--extract-tag-value "\"john doe\"") "john doe"))
  (should (string= (altodo--extract-tag-value "\"abc efg\"") "abc efg"))
  (should (string= (altodo--extract-tag-value "\"test\"") "test")))

(ert-deftest test-extract-tag-value-without-quotes ()
  "Test value without quotes."
  (should (string= (altodo--extract-tag-value "high") "high"))
  (should (string= (altodo--extract-tag-value "5") "5"))
  (should (string= (altodo--extract-tag-value "urgent") "urgent")))

(ert-deftest test-line-get-tag-value ()
  "Test tag value extraction."
  (with-temp-buffer
    (insert "[ ] Task #priority:high #estimate:5\n")
    (goto-char (point-min))
    (should (string= (altodo--line-get-tag-value "priority") "high"))
    (should (string= (altodo--line-get-tag-value "estimate") "5"))
    (should-not (altodo--line-get-tag-value "nonexistent"))))

(ert-deftest test-line-get-tag-value-with-quotes ()
  "Test tag value extraction with quotes."
  (with-temp-buffer
    (insert "[ ] Task #owner:\"john doe\" #description:\"abc efg\"\n")
    (goto-char (point-min))
    (should (string= (altodo--line-get-tag-value "owner") "john doe"))
    (should (string= (altodo--line-get-tag-value "description") "abc efg"))))

(ert-deftest test-line-has-tag-value-p ()
  "Test exact tag value match."
  (with-temp-buffer
    (insert "[ ] Task #priority:high #estimate:5\n")
    (goto-char (point-min))
    (should (altodo--line-has-tag-value-p "priority" "high"))
    (should (altodo--line-has-tag-value-p "estimate" "5"))
    (should-not (altodo--line-has-tag-value-p "priority" "low"))
    (should-not (altodo--line-has-tag-value-p "nonexistent" "value"))))

(ert-deftest test-line-has-tag-value-any-p ()
  "Test multiple value OR match."
  (with-temp-buffer
    (insert "[ ] Task #priority:high\n")
    (goto-char (point-min))
    (should (altodo--line-has-tag-value-any-p "priority" '("high" "urgent")))
    (should (altodo--line-has-tag-value-any-p "priority" '("low" "high")))
    (should-not (altodo--line-has-tag-value-any-p "priority" '("low" "medium")))))

(ert-deftest test-line-has-tag-value-numeric-p-greater ()
  "Test numeric comparison: greater than."
  (with-temp-buffer
    (insert "[ ] Task #estimate:10\n")
    (goto-char (point-min))
    (should (altodo--line-has-tag-value-numeric-p "estimate" '> 5))
    (should-not (altodo--line-has-tag-value-numeric-p "estimate" '> 10))
    (should-not (altodo--line-has-tag-value-numeric-p "estimate" '> 15))))

(ert-deftest test-line-has-tag-value-numeric-p-less ()
  "Test numeric comparison: less than."
  (with-temp-buffer
    (insert "[ ] Task #estimate:5\n")
    (goto-char (point-min))
    (should (altodo--line-has-tag-value-numeric-p "estimate" '< 10))
    (should-not (altodo--line-has-tag-value-numeric-p "estimate" '< 5))
    (should-not (altodo--line-has-tag-value-numeric-p "estimate" '< 3))))

(ert-deftest test-line-has-tag-value-numeric-p-equal ()
  "Test numeric comparison: equal."
  (with-temp-buffer
    (insert "[ ] Task #estimate:5\n")
    (goto-char (point-min))
    (should (altodo--line-has-tag-value-numeric-p "estimate" '= 5))
    (should-not (altodo--line-has-tag-value-numeric-p "estimate" '= 10))))

(ert-deftest test-line-has-tag-value-numeric-p-gte ()
  "Test numeric comparison: greater than or equal."
  (with-temp-buffer
    (insert "[ ] Task #estimate:5\n")
    (goto-char (point-min))
    (should (altodo--line-has-tag-value-numeric-p "estimate" '>= 5))
    (should (altodo--line-has-tag-value-numeric-p "estimate" '>= 3))
    (should-not (altodo--line-has-tag-value-numeric-p "estimate" '>= 10))))

(ert-deftest test-line-has-tag-value-numeric-p-lte ()
  "Test numeric comparison: less than or equal."
  (with-temp-buffer
    (insert "[ ] Task #estimate:5\n")
    (goto-char (point-min))
    (should (altodo--line-has-tag-value-numeric-p "estimate" '<= 5))
    (should (altodo--line-has-tag-value-numeric-p "estimate" '<= 10))
    (should-not (altodo--line-has-tag-value-numeric-p "estimate" '<= 3))))

(ert-deftest test-line-has-tag-value-numeric-p-float ()
  "Test numeric comparison with float."
  (with-temp-buffer
    (insert "[ ] Task #estimate:9.5\n")
    (goto-char (point-min))
    (should (altodo--line-has-tag-value-numeric-p "estimate" '> 9))
    (should (altodo--line-has-tag-value-numeric-p "estimate" '< 10))
    (should (altodo--line-has-tag-value-numeric-p "estimate" '= 9.5))))

(ert-deftest test-line-has-tag-value-numeric-p-invalid ()
  "Test numeric comparison with non-numeric value."
  (with-temp-buffer
    (insert "[ ] Task #priority:high\n")
    (goto-char (point-min))
    (should-not (altodo--line-has-tag-value-numeric-p "priority" '> 5))))

;;; DSL Integration Tests

(ert-deftest test-dsl-arg-types-includes-tag-value ()
  "Test that tag-value is in DSL arg types."
  (should (member "tag-value" altodo--dsl-arg-types)))

(ert-deftest test-parse-tag-value-exact-match ()
  "Test parsing exact match condition."
  (let ((pred (altodo--parse-tag-value-condition "priority high")))
    (with-temp-buffer
      (insert "[ ] Task #priority:high\n")
      (goto-char (point-min))
      (should (funcall pred)))))

(ert-deftest test-parse-tag-value-multiple-or ()
  "Test parsing multiple value OR condition."
  (let ((pred (altodo--parse-tag-value-condition "priority (high urgent)")))
    (with-temp-buffer
      (insert "[ ] Task #priority:high\n")
      (goto-char (point-min))
      (should (funcall pred))
      (erase-buffer)
      (insert "[ ] Task #priority:urgent\n")
      (goto-char (point-min))
      (should (funcall pred))
      (erase-buffer)
      (insert "[ ] Task #priority:low\n")
      (goto-char (point-min))
      (should-not (funcall pred)))))

(ert-deftest test-parse-tag-value-numeric-gt ()
  "Test parsing numeric greater than condition."
  (let ((pred (altodo--parse-tag-value-condition "estimate (> 5)")))
    (with-temp-buffer
      (insert "[ ] Task #estimate:10\n")
      (goto-char (point-min))
      (should (funcall pred))
      (erase-buffer)
      (insert "[ ] Task #estimate:5\n")
      (goto-char (point-min))
      (should-not (funcall pred)))))

(ert-deftest test-parse-tag-value-numeric-lt ()
  "Test parsing numeric less than condition."
  (let ((pred (altodo--parse-tag-value-condition "estimate (< 10)")))
    (with-temp-buffer
      (insert "[ ] Task #estimate:5\n")
      (goto-char (point-min))
      (should (funcall pred))
      (erase-buffer)
      (insert "[ ] Task #estimate:15\n")
      (goto-char (point-min))
      (should-not (funcall pred)))))

(ert-deftest test-parse-tag-value-numeric-eq ()
  "Test parsing numeric equal condition."
  (let ((pred (altodo--parse-tag-value-condition "estimate (= 5)")))
    (with-temp-buffer
      (insert "[ ] Task #estimate:5\n")
      (goto-char (point-min))
      (should (funcall pred))
      (erase-buffer)
      (insert "[ ] Task #estimate:10\n")
      (goto-char (point-min))
      (should-not (funcall pred)))))

(ert-deftest test-parse-tag-value-numeric-gte ()
  "Test parsing numeric greater than or equal condition."
  (let ((pred (altodo--parse-tag-value-condition "estimate (>= 5)")))
    (with-temp-buffer
      (insert "[ ] Task #estimate:5\n")
      (goto-char (point-min))
      (should (funcall pred))
      (erase-buffer)
      (insert "[ ] Task #estimate:10\n")
      (goto-char (point-min))
      (should (funcall pred))
      (erase-buffer)
      (insert "[ ] Task #estimate:3\n")
      (goto-char (point-min))
      (should-not (funcall pred)))))

(ert-deftest test-parse-tag-value-numeric-lte ()
  "Test parsing numeric less than or equal condition."
  (let ((pred (altodo--parse-tag-value-condition "estimate (<= 10)")))
    (with-temp-buffer
      (insert "[ ] Task #estimate:10\n")
      (goto-char (point-min))
      (should (funcall pred))
      (erase-buffer)
      (insert "[ ] Task #estimate:5\n")
      (goto-char (point-min))
      (should (funcall pred))
      (erase-buffer)
      (insert "[ ] Task #estimate:15\n")
      (goto-char (point-min))
      (should-not (funcall pred)))))

(ert-deftest test-compile-simple-pattern-tag-value ()
  "Test compiling tag-value pattern."
  (let ((pred (altodo--compile-simple-pattern "tag-value:priority high")))
    (with-temp-buffer
      (insert "[ ] Task #priority:high\n")
      (goto-char (point-min))
      (should (funcall pred))
      (erase-buffer)
      (insert "[ ] Task #priority:low\n")
      (goto-char (point-min))
      (should-not (funcall pred)))))

;;; Filter Execution Tests

(ert-deftest test-filter-tag-value-exact ()
  "Test filter execution with exact match."
  (with-temp-buffer
    (insert "[ ] Task 1 #priority:high\n")
    (insert "[ ] Task 2 #priority:low\n")
    (insert "[ ] Task 3 #priority:high\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "tag-value:priority high")))
      (altodo--filter-lines pred)
      ;; Task 2 should be hidden
      (goto-char (point-min))
      (should-not (invisible-p (point)))
      (forward-line 1)
      (should (invisible-p (point)))
      (forward-line 1)
      (should-not (invisible-p (point))))))

(ert-deftest test-filter-tag-value-numeric ()
  "Test filter execution with numeric comparison."
  (with-temp-buffer
    (insert "[ ] Task 1 #estimate:3\n")
    (insert "[ ] Task 2 #estimate:10\n")
    (insert "[ ] Task 3 #estimate:7\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "tag-value:estimate (> 5)")))
      (altodo--filter-lines pred)
      ;; Task 1 should be hidden
      (goto-char (point-min))
      (should (invisible-p (point)))
      (forward-line 1)
      (should-not (invisible-p (point)))
      (forward-line 1)
      (should-not (invisible-p (point))))))

(ert-deftest test-filter-tag-value-with-quotes ()
  "Test filter execution with quoted values."
  (with-temp-buffer
    (insert "[ ] Task 1 #owner:\"john doe\"\n")
    (insert "[ ] Task 2 #owner:alice\n")
    (insert "[ ] Task 3 #owner:\"john doe\"\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "tag-value:owner john doe")))
      (altodo--filter-lines pred)
      ;; Task 2 should be hidden
      (goto-char (point-min))
      (should-not (invisible-p (point)))
      (forward-line 1)
      (should (invisible-p (point)))
      (forward-line 1)
      (should-not (invisible-p (point))))))

;;; Complex Tag Conditions Tests

(ert-deftest test-complex-multiple-tags-same-line ()
  "Test multiple different tags on same line."
  (with-temp-buffer
    (insert "[ ] Task #priority:high #estimate:10 #owner:john\n")
    (goto-char (point-min))
    (should (altodo--line-has-tag-value-p "priority" "high"))
    (should (altodo--line-has-tag-value-p "estimate" "10"))
    (should (altodo--line-has-tag-value-p "owner" "john"))))

(ert-deftest test-complex-tag-with-special-chars ()
  "Test tag values with special characters (allowed: [-_a-zA-Z0-9])."
  (with-temp-buffer
    (insert "[ ] Task #id:task-123 #code:v1_0_0 #ref:PR456\n")
    (goto-char (point-min))
    (should (altodo--line-has-tag-value-p "id" "task-123"))
    (should (altodo--line-has-tag-value-p "code" "v1_0_0"))
    (should (altodo--line-has-tag-value-p "ref" "PR456"))))

(ert-deftest test-complex-numeric-comparison-chain ()
  "Test multiple numeric comparisons on same line."
  (with-temp-buffer
    (insert "[ ] Task #estimate:5 #priority:3 #level:2\n")
    (goto-char (point-min))
    (should (altodo--line-has-tag-value-numeric-p "estimate" '> 3))
    (should (altodo--line-has-tag-value-numeric-p "priority" '< 5))
    (should (altodo--line-has-tag-value-numeric-p "level" '= 2))))

(ert-deftest test-complex-mixed-quoted-unquoted ()
  "Test mix of quoted and unquoted values."
  (with-temp-buffer
    (insert "[ ] Task #owner:\"john doe\" #status:active #team:\"backend team\"\n")
    (goto-char (point-min))
    (should (altodo--line-has-tag-value-p "owner" "john doe"))
    (should (altodo--line-has-tag-value-p "status" "active"))
    (should (altodo--line-has-tag-value-p "team" "backend team"))))

(ert-deftest test-complex-nested-tasks ()
  "Test tag values in nested tasks."
  (with-temp-buffer
    (insert "[ ] Parent #priority:high\n")
    (insert "  [ ] Child #priority:medium\n")
    (insert "    [ ] Grandchild #priority:low\n")
    (goto-char (point-min))
    (should (altodo--line-has-tag-value-p "priority" "high"))
    (forward-line 1)
    (should (altodo--line-has-tag-value-p "priority" "medium"))
    (forward-line 1)
    (should (altodo--line-has-tag-value-p "priority" "low"))))

(ert-deftest test-complex-multiple-same-tag ()
  "Test multiple instances of same tag (first one found)."
  (with-temp-buffer
    (insert "[ ] Task #priority:low #priority:high\n")
    (goto-char (point-min))
    ;; Should match the first occurrence
    (should (altodo--line-has-tag-value-p "priority" "low"))))

(ert-deftest test-complex-filter-with_and_condition ()
  "Test filter with AND condition."
  (with-temp-buffer
    (insert "[ ] Task 1 #priority:high #estimate:10\n")
    (insert "[ ] Task 2 #priority:high #estimate:3\n")
    (insert "[ ] Task 3 #priority:low #estimate:10\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "and:tag-value:priority high,tag-value:estimate (> 5)")))
      (altodo--filter-lines pred)
      ;; Task 1 should be visible (high AND > 5)
      (goto-char (point-min))
      (should-not (invisible-p (point)))
      ;; Task 2 should be hidden (high BUT <= 5)
      (forward-line 1)
      (should (invisible-p (point)))
      ;; Task 3 should be hidden (low AND > 5)
      (forward-line 1)
      (should (invisible-p (point))))))

(ert-deftest test-complex_filter_with_or_condition ()
  "Test filter with OR condition."
  (with-temp-buffer
    (insert "[ ] Task 1 #priority:high\n")
    (insert "[ ] Task 2 #priority:low\n")
    (insert "[ ] Task 3 #priority:medium\n")
    (goto-char (point-min))
    (let ((pred (altodo--compile-simple-pattern "or:tag-value:priority high,tag-value:priority low")))
      (altodo--filter-lines pred)
      ;; Task 1 should be visible (high)
      (goto-char (point-min))
      (should-not (invisible-p (point)))
      ;; Task 2 should be visible (low)
      (forward-line 1)
      (should-not (invisible-p (point)))
      ;; Task 3 should be hidden (medium)
      (forward-line 1)
      (should (invisible-p (point))))))

;;; Abnormal Cases Tests

(ert-deftest test-abnormal-empty-tag-value ()
  "Test empty tag value."
  (with-temp-buffer
    (insert "[ ] Task #priority:\n")
    (goto-char (point-min))
    (should-not (altodo--line-get-tag-value "priority"))))

(ert-deftest test-abnormal-tag-without-value ()
  "Test tag without value (no colon)."
  (with-temp-buffer
    (insert "[ ] Task #priority\n")
    (goto-char (point-min))
    (should-not (altodo--line-get-tag-value "priority"))))

(ert-deftest test-abnormal_malformed_numeric ()
  "Test malformed numeric values."
  (with-temp-buffer
    (insert "[ ] Task #estimate:abc\n")
    (goto-char (point-min))
    (should-not (altodo--line-has-tag-value-numeric-p "estimate" '> 5))))

(ert-deftest test-abnormal-multiple-colons ()
  "Test tag with multiple colons."
  (with-temp-buffer
    (insert "[ ] Task #url:http://example.com\n")
    (goto-char (point-min))
    ;; Should match the first colon
    (should (string= (altodo--line-get-tag-value "url") "http://example.com"))))

(ert-deftest test-abnormal-tag-at-end-of-line ()
  "Test tag at end of line without space after."
  (with-temp-buffer
    (insert "[ ] Task #priority:high")
    (goto-char (point-min))
    (should (altodo--line-has-tag-value-p "priority" "high"))))

(ert-deftest test-abnormal-tag-with-trailing-space ()
  "Test tag value with trailing space."
  (with-temp-buffer
    (insert "[ ] Task #priority:high \n")
    (goto-char (point-min))
    ;; Trailing space should not be included
    (should (altodo--line-has-tag-value-p "priority" "high"))))

(ert-deftest test-abnormal-quoted_empty_value ()
  "Test quoted empty value."
  (with-temp-buffer
    (insert "[ ] Task #owner:\"\"\n")
    (goto-char (point-min))
    (should (string= (altodo--line-get-tag-value "owner") ""))))

(ert-deftest test-abnormal-mismatched_quotes ()
  "Test mismatched quotes."
  (with-temp-buffer
    (insert "[ ] Task #owner:\"john doe\n")
    (goto-char (point-min))
    ;; Should not match (mismatched quotes)
    (should-not (altodo--line-has-tag-value-p "owner" "john doe"))))

(ert-deftest test-abnormal-numeric-with-leading-plus ()
  "Test numeric with leading plus sign."
  (with-temp-buffer
    (insert "[ ] Task #estimate:+5\n")
    (goto-char (point-min))
    (should (altodo--line-has-tag-value-numeric-p "estimate" '= 5))))

(ert-deftest test-abnormal-numeric-with-multiple-signs ()
  "Test numeric with multiple signs."
  (with-temp-buffer
    (insert "[ ] Task #estimate:+-5\n")
    (goto-char (point-min))
    ;; Should not match (invalid format)
    (should-not (altodo--line-has-tag-value-numeric-p "estimate" '= 5))))

(ert-deftest test-abnormal-tag-in-comment ()
  "Test tag in comment line."
  (with-temp-buffer
    (insert "/// Comment #priority:high\n")
    (goto-char (point-min))
    ;; Comment lines starting with /// are recognized as comments
    (should (altodo--comment-p))
    (should (altodo--line-has-tag-value-p "priority" "high"))))

(ert-deftest test-abnormal-tag-in-multiline-comment ()
  "Test tag in multiline comment."
  (with-temp-buffer
    (insert "[ ] Task\n")
    (insert "  #priority:high\n")
    (goto-char (point-min))
    (forward-line 1)
    ;; Multiline comment line should not match
    (should-not (altodo--line-has-tag-value-p "priority" "high"))))

(ert-deftest test-abnormal-numeric-comparison-with_non_numeric ()
  "Test numeric comparison on non-numeric value."
  (with-temp-buffer
    (insert "[ ] Task #status:active\n")
    (goto-char (point-min))
    (should-not (altodo--line-has-tag-value-numeric-p "status" '> 5))))

(ert-deftest test-abnormal-parse-invalid_condition ()
  "Test parsing invalid tag-value condition."
  (should-error (altodo--parse-tag-value-condition "invalid")))

(ert-deftest test-abnormal-parse-malformed_numeric ()
  "Test parsing malformed numeric condition."
  (let ((pred (altodo--parse-tag-value-condition "estimate (> 5)")))
    ;; Should create a valid predicate even with unusual format
    (with-temp-buffer
      (insert "[ ] Task #estimate:10\n")
      (goto-char (point-min))
      (should (funcall pred)))))

(provide 'phase5-9-test)
;;; phase5-9-test.el ends here
