;;; date-arrow-test.el --- Tests for date arrow face handling

;;; Commentary:
;; Tests for altodo-mode's date arrow (->)  face handling.
;; Ensures that arrow faces are applied only when dates are present.

;;; Code:

(require 'ert)
(require 'altodo)

(defun date-arrow-test--get-face-at (content line col)
  "Get face at LINE COL in CONTENT."
  (with-temp-buffer
    (insert content)
    (altodo-mode)
    (font-lock-ensure)
    (goto-line line)
    (move-to-column col)
    (get-text-property (point) 'face)))

(defun date-arrow-test--has-face-p (content line col face)
  "Check if FACE is applied at LINE COL in CONTENT."
  (let ((actual-face (date-arrow-test--get-face-at content line col)))
    (cond
     ((listp actual-face)
      (memq face actual-face))
     ((symbolp actual-face)
      (eq actual-face face))
     (t nil))))

;;; Tests - Arrow without dates (should NOT apply arrow face)

(ert-deftest date-arrow-test-bare-arrow ()
  "Bare arrow without dates should NOT have arrow face."
  (should-not (date-arrow-test--has-face-p "[ ] Task ->\n" 1 10 'altodo-date-arrow-face)))

(ert-deftest date-arrow-test-arrow-with-incomplete-date ()
  "Arrow with incomplete date (YYYY-MM) should NOT have arrow face."
  (should-not (date-arrow-test--has-face-p "[ ] Task 2026-03 ->\n" 1 15 'altodo-date-arrow-face)))

(ert-deftest date-arrow-test-arrow-with-invalid-date ()
  "Arrow with invalid date should NOT have arrow face."
  (should-not (date-arrow-test--has-face-p "[ ] Task 2026-13-01 ->\n" 1 15 'altodo-date-arrow-face)))

;;; Tests - Start date (DATE ->)

(ert-deftest date-arrow-test-start-date-with-space ()
  "Start date with space after arrow should have date face."
  (should (date-arrow-test--has-face-p "[ ] Task 2026-04-01 -> \n" 1 15 'altodo-date-face)))

(ert-deftest date-arrow-test-start-date-at-eol ()
  "Start date at end of line should have date face."
  (should (date-arrow-test--has-face-p "[ ] Task 2026-04-01 ->\n" 1 15 'altodo-date-face)))

(ert-deftest date-arrow-test-start-date-in-middle ()
  "Start date in middle of line should have date face."
  (should (date-arrow-test--has-face-p "[ ] Task 2026-04-01 -> with more text\n" 1 15 'altodo-date-face)))

(ert-deftest date-arrow-test-start-date-with-tag ()
  "Start date followed by tag should have date face."
  (should (date-arrow-test--has-face-p "[ ] Task 2026-04-01 -> #tag\n" 1 15 'altodo-date-face)))

;;; Tests - Due date (-> DATE)

(ert-deftest date-arrow-test-due-date-with-space ()
  "Due date with space before arrow should have arrow face."
  (should (date-arrow-test--has-face-p "[ ] Task -> 2026-04-01\n" 1 10 'altodo-date-arrow-face)))

(ert-deftest date-arrow-test-due-date-in-middle ()
  "Due date in middle of line should have arrow face."
  (should (date-arrow-test--has-face-p "[ ] Task with due -> 2026-04-01 and more\n" 1 20 'altodo-date-arrow-face)))

(ert-deftest date-arrow-test-due-date-with-tag ()
  "Due date followed by tag should have arrow face."
  (should (date-arrow-test--has-face-p "[ ] Task -> 2026-04-01 #tag\n" 1 10 'altodo-date-arrow-face)))

;;; Tests - Both dates (DATE -> DATE)

(ert-deftest date-arrow-test-both-dates ()
  "Both start and due dates should have start-active face."
  (should (date-arrow-test--has-face-p "[ ] Task 2026-01-01 -> 2026-12-31\n" 1 15 'altodo-date-start-active-face)))

(ert-deftest date-arrow-test-both-dates-with-tag ()
  "Both dates with tag should have start-active face."
  (should (date-arrow-test--has-face-p "[ ] Task 2026-01-01 -> 2026-12-31 #tag\n" 1 15 'altodo-date-start-active-face)))

;;; Tests - Start date not yet (future date)

(ert-deftest date-arrow-test-start-not-yet-at-eol ()
  "Future start date at end of line should have not-yet face."
  (should (date-arrow-test--has-face-p "[ ] Task 2026-04-01 ->\n" 1 5 'altodo-start-not-yet-text-face)))

(ert-deftest date-arrow-test-start-not-yet-with-space ()
  "Future start date with space after arrow should have not-yet face."
  (should (date-arrow-test--has-face-p "[ ] Task 2026-04-01 -> \n" 1 5 'altodo-start-not-yet-text-face)))

(ert-deftest date-arrow-test-start-not-yet-in-middle ()
  "Future start date in middle of line should have not-yet face."
  (should (date-arrow-test--has-face-p "[ ] Task 2026-04-01 -> with more text\n" 1 5 'altodo-start-not-yet-text-face)))

;;; Tests - Edge cases

(ert-deftest date-arrow-test-multiple-arrows ()
  "Multiple arrows in line should match first valid pattern."
  (should (date-arrow-test--has-face-p "[ ] Task 2026-04-01 -> 2026-12-31 -> extra\n" 1 15 'altodo-date-face)))

(ert-deftest date-arrow-test-arrow-with-no-space-before ()
  "Arrow without space before should NOT have arrow face."
  (should-not (date-arrow-test--has-face-p "[ ] Task2026-04-01->\n" 1 10 'altodo-date-arrow-face)))

(ert-deftest date-arrow-test-arrow-with-no-space-after-due ()
  "Due arrow without space after should NOT have arrow face."
  (should-not (date-arrow-test--has-face-p "[ ] Task->2026-04-01\n" 1 10 'altodo-date-arrow-face)))

(ert-deftest date-arrow-test-date-like-text ()
  "Text that looks like date but isn't should NOT have arrow face."
  (should-not (date-arrow-test--has-face-p "[ ] Task 2026-99-99 ->\n" 1 15 'altodo-date-arrow-face)))

(ert-deftest date-arrow-test-partial-date-before-arrow ()
  "Partial date before arrow should NOT have arrow face."
  (should-not (date-arrow-test--has-face-p "[ ] Task 2026-04 ->\n" 1 15 'altodo-date-arrow-face)))

(ert-deftest date-arrow-test-partial-date-after-arrow ()
  "Partial date after arrow should NOT have arrow face."
  (should-not (date-arrow-test--has-face-p "[ ] Task -> 2026-04\n" 1 10 'altodo-date-arrow-face)))

(ert-deftest date-arrow-test-arrow-at-line-start ()
  "Arrow at line start with due date should have arrow face."
  (should (date-arrow-test--has-face-p "[ ] -> 2026-04-01\n" 1 5 'altodo-date-arrow-face)))

(ert-deftest date-arrow-test-nested-task-with-start-date ()
  "Nested task with start date should have not-yet face."
  (should (date-arrow-test--has-face-p "[ ] Parent\n    [ ] Child 2026-04-01 ->\n" 2 9 'altodo-start-not-yet-text-face)))

(ert-deftest date-arrow-test-comment-with-arrow ()
  "Comment with arrow should NOT have arrow face (comments don't support dates)."
  (should-not (date-arrow-test--has-face-p "/// Comment 2026-04-01 ->\n" 1 15 'altodo-date-arrow-face)))

(provide 'date-arrow-test)
;;; date-arrow-test.el ends here
