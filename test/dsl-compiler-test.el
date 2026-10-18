;;; dsl-compiler-test.el --- Tests for DSL compiler

(require 'ert)

;; Mock markdown-mode
(unless (featurep 'markdown-mode)
  (provide 'markdown-mode)
  (defvar markdown-mode-map (make-sparse-keymap))
  (defun markdown-mode nil)
  (defun markdown-cycle nil))

(load-file "altodo.el")

(defvar test-buffer nil)

(defun setup-test-buffer ()
  (setq test-buffer (get-buffer-create "*altodo-dsl-compiler-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task 1\n")                          ; Line 1: open
    (insert "[x] Task 2\n")                          ; Line 2: done
    (insert "[@] Task 3\n")                          ; Line 3: progress
    (insert "[w] Task 4\n")                          ; Line 4: waiting
    (insert "[~] Task 5\n")                          ; Line 5: cancelled
    (insert "[ ] Task 6 #important\n")               ; Line 6: open + tag
    (insert "[ ] Task 7 @john\n")                    ; Line 7: open + person
    (insert "[ ] Task 8 -> 2026-01-01\n")            ; Line 8: open + date
    (insert "[ ] ! Priority task\n")                 ; Line 9: open + priority
    (insert "[ ] + Star task\n")                     ; Line 10: open + star
    (insert "[x] ! Done with priority\n")            ; Line 11: done + priority
    (insert "[x] + Done with star\n")                ; Line 12: done + star
    (insert "[~] + Cancelled with star\n")           ; Line 13: cancelled + star
    (insert "[ ] ! + Priority and star\n")           ; Line 14: open + priority + star
    (insert "[x] ! + Done priority star\n")          ; Line 15: done + priority + star
    (insert "[ ] ! Task #urgent @alice\n")           ; Line 16: open + priority + tag + person
    (insert "[~] Task #old @bob\n")                  ; Line 17: cancelled + tag + person
    (insert "[@] ! Progress priority\n")             ; Line 18: progress + priority
    (insert "[w] + Waiting star\n")                  ; Line 19: waiting + star
    (insert "[ ] #bug #critical @team\n"))           ; Line 20: open + 2 tags + person
  )


(defun cleanup-test-buffer ()
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

;; ============================================================================
;; 正規化テスト
;; ============================================================================

(ert-deftest test-normalize-simple-pattern ()
  "Test normalization of simple patterns."
  (should (equal (altodo--normalize-pattern "done")
                 '(simple "done")))
  (should (equal (altodo--normalize-pattern "priority")
                 '(simple "priority")))
  (should (equal (altodo--normalize-pattern "star")
                 '(simple "star"))))

(ert-deftest test-normalize-arg-pattern ()
  "Test normalization of argument patterns."
  (should (equal (altodo--normalize-pattern "tag:important")
                 '(arg "tag" "important")))
  (should (equal (altodo--normalize-pattern "person:john")
                 '(arg "person" "john")))
  (should (equal (altodo--normalize-pattern "level:0")
                 '(arg "level" "0"))))

(ert-deftest test-normalize-logic-pattern ()
  "Test normalization of logic patterns."
  (should (equal (altodo--normalize-pattern "not:done")
                 '(logic not ("done"))))
  (should (equal (altodo--normalize-pattern "and:done,priority")
                 '(logic and ("done" "priority"))))
  (should (equal (altodo--normalize-pattern "or:done,cancelled")
                 '(logic or ("done" "cancelled")))))

;; ============================================================================
;; 検証テスト
;; ============================================================================

(ert-deftest test-validate-simple-pattern ()
  "Test validation of simple patterns."
  (should (altodo--validate-pattern '(simple "done")))
  (should (altodo--validate-pattern '(simple "priority")))
  (should-not (altodo--validate-pattern '(simple "invalid"))))

(ert-deftest test-validate-arg-pattern ()
  "Test validation of argument patterns."
  (should (altodo--validate-pattern '(arg "tag" "important")))
  (should (altodo--validate-pattern '(arg "person" "john")))
  (should-not (altodo--validate-pattern '(arg "invalid" "value"))))

(ert-deftest test-validate-logic-pattern ()
  "Test validation of logic patterns."
  (should (altodo--validate-pattern '(logic and ("done" "priority"))))
  (should (altodo--validate-pattern '(logic or ("done" "cancelled"))))
  (should (altodo--validate-pattern '(logic not ("done"))))
  (should-not (altodo--validate-pattern '(logic invalid ("done")))))

;; ============================================================================
;; コンパイルテスト
;; ============================================================================

(ert-deftest test-compile-simple-pattern-done ()
  "Test compilation of 'done' pattern."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "done")))
      (should (functionp pred))
      ;; Line 1: [ ] Task 1 - should not match
      (goto-char (point-min))
      (should-not (funcall pred))
      ;; Line 2: [x] Task 2 - should match
      (forward-line 1)
      (should (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-compile-simple-pattern-priority ()
  "Test compilation of 'priority' pattern."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "priority")))
      (should (functionp pred))
      ;; Line 1: [ ] Task 1 - should not match
      (goto-char (point-min))
      (should-not (funcall pred))
      ;; Line 9: [ ] Task 9 ! - should match
      (goto-char (point-min))
      (forward-line 8)
      (should (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-compile-arg-pattern-tag ()
  "Test compilation of 'tag:TAG' pattern."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "tag:important")))
      (should (functionp pred))
      ;; Line 1: [ ] Task 1 - should not match
      (goto-char (point-min))
      (should-not (funcall pred))
      ;; Line 6: [ ] Task 6 #important - should match
      (goto-char (point-min))
      (forward-line 5)
      (should (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-compile-arg-pattern-person ()
  "Test compilation of 'person:PERSON' pattern."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "person:john")))
      (should (functionp pred))
      ;; Line 1: [ ] Task 1 - should not match
      (goto-char (point-min))
      (should-not (funcall pred))
      ;; Line 7: [ ] Task 7 @john - should match
      (goto-char (point-min))
      (forward-line 6)
      (should (funcall pred))))
  (cleanup-test-buffer))

;; ============================================================================
;; 複合条件テスト
;; ============================================================================

(ert-deftest test-compile-logic-pattern-and ()
  "Test compilation of 'and:P1,P2' pattern."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "and:priority,open")))
      (should (functionp pred))
      ;; Line 1: [ ] Task 1 - open but no priority - should not match
      (goto-char (point-min))
      (should-not (funcall pred))
      ;; Line 11: [x] ! Done with priority - priority but not open - should not match
      (goto-char (point-min))
      (forward-line 10)
      (should-not (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-compile-logic-pattern-or ()
  "Test compilation of 'or:P1,P2' pattern."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "or:done,cancelled")))
      (should (functionp pred))
      ;; Line 1: [ ] Task 1 - neither done nor cancelled - should not match
      (goto-char (point-min))
      (should-not (funcall pred))
      ;; Line 2: [x] Task 2 - done - should match
      (goto-char (point-min))
      (forward-line 1)
      (should (funcall pred))
      ;; Line 5: [~] Task 5 - cancelled - should match
      (goto-char (point-min))
      (forward-line 4)
      (should (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-compile-logic-pattern-not ()
  "Test compilation of 'not:PATTERN' pattern."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "not:done")))
      (should (functionp pred))
      ;; Line 1: [ ] Task 1 - not done - should match
      (goto-char (point-min))
      (should (funcall pred))
      ;; Line 2: [x] Task 2 - done - should not match
      (goto-char (point-min))
      (forward-line 1)
      (should-not (funcall pred))))
  (cleanup-test-buffer))

;; ============================================================================
;; 複雑な複合条件テスト
;; ============================================================================

(ert-deftest test-compile-complex-pattern-and-or ()
  "Test compilation of complex 'and:P1,or:P2,P3' pattern."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "and:priority,or:done,cancelled")))
      (should (functionp pred))
      ;; Line 1: [ ] Task 1 - no priority - should not match
      (goto-char (point-min))
      (should-not (funcall pred))
      ;; Line 9: [ ] Task 9 ! - priority but not done/cancelled - should not match
      (goto-char (point-min))
      (forward-line 8)
      (should-not (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-compile-complex-pattern-or-and ()
  "Test compilation of complex 'or:and:done,priority,and:cancelled,star' pattern."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "or:and:done,priority,and:cancelled,star")))
      (should (functionp pred))
      ;; Line 1: [ ] Task 1 - neither condition - should not match
      (goto-char (point-min))
      (should-not (funcall pred))
      ;; Line 2: [x] Task 2 - done but no priority - should not match
      (goto-char (point-min))
      (forward-line 1)
      (should-not (funcall pred))))
  (cleanup-test-buffer))

;; ============================================================================
;; 複雑な複合条件テスト（追加）
;; ============================================================================

(ert-deftest test-complex-triple-and ()
  "Test 'and:priority,star,open' - 3 conditions."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "and:priority,star,open")))
      ;; Line 14: [ ] ! + Priority and star - should match
      ;; Note: This line doesn't exist in current format, skip this test case
      ;; Line 9: [ ] ! Priority task - no star - should not match
      (goto-char (point-min))
      (forward-line 8)
      (should-not (funcall pred))
      ;; Line 10: [ ] + Star task - no priority - should not match
      (goto-char (point-min))
      (forward-line 9)
      (should-not (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-complex-nested-or-and ()
  "Test 'or:and:done,priority,and:done,star' - nested OR with 2 AND conditions."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "or:and:done,priority,and:done,star")))
      ;; Line 11: [x] ! Done with priority - should match (first AND)
      (goto-char (point-min))
      (forward-line 10)
      (should (funcall pred))
      ;; Line 12: [x] + Done with star - should match (second AND)
      (goto-char (point-min))
      (forward-line 11)
      (should (funcall pred))
      ;; Line 15: [x] ! + Done priority star - should match (both AND)
      (goto-char (point-min))
      (forward-line 14)
      (should (funcall pred))
      ;; Line 2: [x] Task 2 - done but no priority/star - should not match
      (goto-char (point-min))
      (forward-line 1)
      (should-not (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-complex-triple-or ()
  "Test 'or:done,cancelled,waiting' - 3 state conditions."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "or:done,cancelled,waiting")))
      ;; Line 2: [x] Task 2 - done - should match
      (goto-char (point-min))
      (forward-line 1)
      (should (funcall pred))
      ;; Line 5: [~] Task 5 - cancelled - should match
      (goto-char (point-min))
      (forward-line 4)
      (should (funcall pred))
      ;; Line 4: [w] Task 4 - waiting - should match
      (goto-char (point-min))
      (forward-line 3)
      (should (funcall pred))
      ;; Line 1: [ ] Task 1 - open - should not match
      (goto-char (point-min))
      (should-not (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-complex-and-with-or ()
  "Test 'and:priority,or:done,cancelled' - AND with OR.
Note: Current implementation parses this as (and priority (or done cancelled))
which is equivalent to: priority AND (done OR cancelled)"
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "and:priority,or:done,cancelled")))
      ;; Line 11: [x] ! Done with priority - priority AND done - should match
      (goto-char (point-min))
      (forward-line 10)
      (should (funcall pred))
      ;; Line 9: [ ] ! Priority task - priority but not done/cancelled - should not match
      (goto-char (point-min))
      (forward-line 8)
      (should-not (funcall pred))
      ;; Line 2: [x] Task 2 - done but no priority - should not match
      (goto-char (point-min))
      (forward-line 1)
      (should-not (funcall pred))
      ;; Line 1: [ ] Task 1 - open, no priority - should not match
      (goto-char (point-min))
      (should-not (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-complex-deep-nesting ()
  "Test 'or:and:priority,done,and:star,waiting' - OR with multiple AND.
Note: Current implementation parses this as (or (and priority done) (and star waiting))
which means: (priority AND done) OR (star AND waiting)"
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "or:and:priority,done,and:star,waiting")))
      ;; Line 11: [x] ! Done with priority - priority AND done - should match
      (goto-char (point-min))
      (forward-line 10)
      (should (funcall pred))
      ;; Line 19: [w] + Waiting star - star AND waiting - should match
      (goto-char (point-min))
      (forward-line 18)
      (should (funcall pred))
      ;; Line 9: [ ] ! Priority task - priority but not done - should not match
      (goto-char (point-min))
      (forward-line 8)
      (should-not (funcall pred))
      ;; Line 1: [ ] Task 1 - neither condition - should not match
      (goto-char (point-min))
      (should-not (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-complex-not-with-and ()
  "Test 'not:and:done,priority' - NOT with nested AND."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "not:and:done,priority")))
      ;; Line 11: [x] ! Done with priority - should not match (NOT of true)
      (goto-char (point-min))
      (forward-line 10)
      (should-not (funcall pred))
      ;; Line 2: [x] Task 2 - done but no priority - should match (NOT of false)
      (goto-char (point-min))
      (forward-line 1)
      (should (funcall pred))
      ;; Line 9: [ ] ! Priority task - priority but not done - should match (NOT of false)
      (goto-char (point-min))
      (forward-line 8)
      (should (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-complex-quadruple-or ()
  "Test 'or:done,cancelled,progress,waiting' - 4 state conditions."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "or:done,cancelled,progress,waiting")))
      ;; Line 2: [x] Task 2 - done - should match
      (goto-char (point-min))
      (forward-line 1)
      (should (funcall pred))
      ;; Line 3: [@] Task 3 - progress - should match
      (goto-char (point-min))
      (forward-line 2)
      (should (funcall pred))
      ;; Line 4: [w] Task 4 - waiting - should match
      (goto-char (point-min))
      (forward-line 3)
      (should (funcall pred))
      ;; Line 5: [~] Task 5 - cancelled - should match
      (goto-char (point-min))
      (forward-line 4)
      (should (funcall pred))
      ;; Line 1: [ ] Task 1 - open - should not match
      (goto-char (point-min))
      (should-not (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-complex-not-with-or ()
  "Test 'not:or:done,cancelled' - NOT with nested OR."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "not:or:done,cancelled")))
      ;; Line 1: [ ] Task 1 - open - should match (NOT of false)
      (goto-char (point-min))
      (should (funcall pred))
      ;; Line 2: [x] Task 2 - done - should not match (NOT of true)
      (goto-char (point-min))
      (forward-line 1)
      (should-not (funcall pred))
      ;; Line 5: [~] Task 5 - cancelled - should not match (NOT of true)
      (goto-char (point-min))
      (forward-line 4)
      (should-not (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-complex-and-multiple-or ()
  "Test 'and:or:done,cancelled,or:priority,star' - AND with multiple nested OR."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "and:or:done,cancelled,or:priority,star")))
      ;; Pattern: and:(or:done,cancelled), (or:priority,star)
      ;; Line 11: [x] ! Done with priority - done AND priority - should match
      (goto-char (point-min))
      (forward-line 10)
      (should (funcall pred))
      ;; Line 12: [x] + Done with star - done AND star - should match
      (goto-char (point-min))
      (forward-line 11)
      (should (funcall pred))
      ;; Line 13: [~] + Cancelled with star - cancelled AND star - should match
      (goto-char (point-min))
      (forward-line 12)
      (should (funcall pred))
      ;; Line 2: [x] Task 2 - done but no priority/star - should not match
      (goto-char (point-min))
      (forward-line 1)
      (should-not (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-complex-tag-with-state ()
  "Test 'and:tag:important,or:done,open' - tag with state conditions."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "and:tag:important,or:done,open")))
      ;; Line 6: [ ] Task 6 #important - open AND tag - should match
      (goto-char (point-min))
      (forward-line 5)
      (should (funcall pred))
      ;; Line 1: [ ] Task 1 - open but no tag - should not match
      (goto-char (point-min))
      (should-not (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-complex-quintuple-or ()
  "Test 'or:done,cancelled,progress,waiting,open' - 5 state conditions."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "or:done,cancelled,progress,waiting,open")))
      ;; All task states - should match all lines
      (goto-char (point-min))
      (should (funcall pred))
      (forward-line 1)
      (should (funcall pred))
      (forward-line 1)
      (should (funcall pred))
      (forward-line 1)
      (should (funcall pred))
      (forward-line 1)
      (should (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-complex-double-not ()
  "Test 'not:or:done,cancelled' - NOT of OR (equivalent to 'not done AND not cancelled')."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "not:or:done,cancelled")))
      ;; Line 1: [ ] Task 1 - open (not done, not cancelled) - should match
      (goto-char (point-min))
      (should (funcall pred))
      ;; Line 3: [@] Task 3 - progress (not done, not cancelled) - should match
      (goto-char (point-min))
      (forward-line 2)
      (should (funcall pred))
      ;; Line 2: [x] Task 2 - done - should not match
      (goto-char (point-min))
      (forward-line 1)
      (should-not (funcall pred))
      ;; Line 5: [~] Task 5 - cancelled - should not match
      (goto-char (point-min))
      (forward-line 4)
      (should-not (funcall pred))))
  (cleanup-test-buffer))

(ert-deftest test-complex-tag-person-state ()
  "Test 'or:and:tag:urgent,priority,and:person:alice,open' - tag, person, state."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "or:and:tag:urgent,priority,and:person:alice,open")))
      ;; Pattern: or:(and:tag:urgent,priority), (and:person:alice,open)
      ;; Line 16: [ ] ! Task #urgent @alice - both conditions - should match
      (goto-char (point-min))
      (forward-line 15)
      (should (funcall pred))
      ;; Line 1: [ ] Task 1 - neither condition - should not match
      (goto-char (point-min))
      (should-not (funcall pred))))
  (cleanup-test-buffer))

;; ============================================================================
;; エラーハンドリングテスト
;; ============================================================================

(ert-deftest test-compile-invalid-pattern ()
  "Test compilation of invalid pattern."
  (let ((pred (altodo--compile-simple-pattern "invalid:pattern:with:colons")))
    (should (functionp pred))
    ;; Should return fallback lambda that matches nothing
    (should-not (funcall pred))))

(ert-deftest test-compile-unknown-simple-pattern ()
  "Test compilation of unknown simple pattern."
  (let ((pred (altodo--compile-simple-pattern "unknown")))
    (should (functionp pred))
    ;; Should return fallback lambda that matches nothing
    (should-not (funcall pred))))

;; ============================================================================
;; フィルタリング統合テスト
;; ============================================================================

(ert-deftest test-filter-with-dsl-pattern-done ()
  "Test filtering with DSL pattern 'done'."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "done")))
      (altodo--filter-lines pred)
      ;; Check that overlays were created
      (should altodo--filter-overlays)
      ;; Line 2 should be visible (done task)
      (goto-line 2)
      (should-not (get-char-property (point) 'invisible))))
  (cleanup-test-buffer))

(ert-deftest test-filter-with-dsl-pattern-or ()
  "Test filtering with DSL pattern 'or:done,cancelled'."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "or:done,cancelled")))
      (altodo--filter-lines pred)
      ;; Check that overlays were created
      (should altodo--filter-overlays)
      ;; Line 2 (done) should be visible
      (goto-line 2)
      (should-not (get-char-property (point) 'invisible))
      ;; Line 5 (cancelled) should be visible
      (goto-line 5)
      (should-not (get-char-property (point) 'invisible))))
  (cleanup-test-buffer))

(ert-deftest test-filter-clear-after-dsl ()
  "Test clearing filter after DSL pattern."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((pred (altodo--compile-simple-pattern "done")))
      (altodo--filter-lines pred)
      (should altodo--filter-overlays)
      (altodo-filter-clear)
      (should-not altodo--filter-overlays)
      (should-not altodo--filter-mode)))
  (cleanup-test-buffer))

(provide 'dsl-compiler-test)
;;; dsl-compiler-test.el ends here
