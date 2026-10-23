;;; goto-dep-test.el --- Tests for goto-dependency command

(require 'ert)
(require 'altodo)

;;; Basic Tests

(ert-deftest goto-dep-test-find-line-with-tag ()
  "Test finding line with #tag:value."
  (with-temp-buffer
    (altodo-mode)
    (insert "- [ ] Task A #id:task-a\n")
    (insert "- [ ] Task B #id:task-b\n")
    (goto-char (point-min))
    (should (equal (altodo--find-line-with-tag "id" "task-a") 1))
    (should (equal (altodo--find-line-with-tag "id" "task-b") 2))))

(ert-deftest goto-dep-test-find-line-with-tag-nil ()
  "Test finding line with #tag:value when not found."
  (with-temp-buffer
    (altodo-mode)
    (insert "- [ ] Task A #id:task-a\n")
    (goto-char (point-min))
    (should (null (altodo--find-line-with-tag "id" "task-c")))))

(ert-deftest goto-dep-test-jump-success ()
  "Test jumping to dependency target."
  (with-temp-buffer
    (altodo-mode)
    (insert "- [ ] Task A #id:task-a\n")
    (insert "- [ ] Task B #dep:task-a\n")
    (goto-line 2)
    (forward-char 6)  ;; Move to task content
    (let ((start-line (line-number-at-pos)))
      (altodo-goto-dependency)
      (should (< (line-number-at-pos) start-line)))))

(ert-deftest goto-dep-test-no-dep-tag ()
  "Test when current line has no #dep: tag."
  (with-temp-buffer
    (altodo-mode)
    (insert "- [ ] Task A #id:task-a\n")
    (goto-line 1)
    (altodo-goto-dependency)
    ;; Should display message but not jump
    (should (equal (line-number-at-pos) 1))))

(ert-deftest goto-dep-test-target-not-found ()
  "Test when dependency target is not found."
  (with-temp-buffer
    (altodo-mode)
    (insert "- [ ] Task B #dep:task-a\n")
    (goto-line 1)
    (altodo-goto-dependency)
    ;; Should display message but not jump
    (should (equal (line-number-at-pos) 1))))

;;; Complex Tests

(ert-deftest goto-dep-test-multiple-dep-tags ()
  "Test with multiple #dep: tags (uses first one)."
  (with-temp-buffer
    (altodo-mode)
    (insert "- [ ] Task A #id:task-a\n")
    (insert "- [ ] Task B #dep:task-a #dep:task-c\n")
    (goto-line 2)
    (forward-char 6)  ;; Move to task content
    (let ((start-line (line-number-at-pos)))
      (altodo-goto-dependency)
      (should (< (line-number-at-pos) start-line)))))

(ert-deftest goto-dep-test-multiple-id-tags ()
  "Test with multiple #id: tags (uses first one)."
  (with-temp-buffer
    (altodo-mode)
    (insert "- [ ] Task A #id:task-a #id:task-x\n")
    (insert "- [ ] Task B #dep:task-a\n")
    (goto-line 2)
    (forward-char 6)  ;; Move to task content
    (let ((start-line (line-number-at-pos)))
      (altodo-goto-dependency)
      (should (< (line-number-at-pos) start-line)))))

(provide 'goto-dep-test)
;;; goto-dep-test.el ends here
