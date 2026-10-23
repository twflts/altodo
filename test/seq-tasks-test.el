;;; seq-tasks-test.el --- Tests for seq-tasks  -*- lexical-binding: t; -*-

;;; Commentary:
;; A child of a task with #seq-tasks is blocked while the sibling right above
;; it is neither done nor cancelled (T20261023-11).  The parent is not blocked.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defun seq-tasks--blocked-lines (text)
  "Return the line numbers of the blocked children in TEXT."
  (altodo-test-with-buffer text
    (let (lines)
      (while (not (eobp))
        (when (altodo--is-seq-tasks-child-blocked-p)
          (push (line-number-at-pos) lines))
        (forward-line 1))
      (nreverse lines))))

(ert-deftest seq-tasks-has-seq-tasks-tag ()
  "The tag is detected on the current line."
  (altodo-test-with-buffer "[ ] Task with #seq-tasks tag\n[ ] Task without tag\n"
    (should (altodo--has-seq-tasks-tag))
    (forward-line 1)
    (should-not (altodo--has-seq-tasks-tag))))

(ert-deftest seq-tasks-first-child-is-not-blocked ()
  "Only the children after the first are blocked, in order."
  (should (equal (seq-tasks--blocked-lines
                  "[ ] P #seq-tasks\n    [ ] a\n    [ ] b\n    [ ] c\n")
                 '(3 4))))

(ert-deftest seq-tasks-done-sibling-unblocks-the-next ()
  "A done or cancelled sibling above unblocks the child."
  (should (equal (seq-tasks--blocked-lines
                  "[ ] P #seq-tasks\n    [x] a\n    [ ] b\n    [ ] c\n")
                 '(4)))
  (should (equal (seq-tasks--blocked-lines
                  "[ ] P #seq-tasks\n    [~] a\n    [ ] b\n")
                 nil)))

(ert-deftest seq-tasks-only-the-sibling-right-above-counts ()
  "With [ ] a, [x] b, [ ] c, the child c is not blocked: b is done."
  (should (equal (seq-tasks--blocked-lines
                  "[ ] P #seq-tasks\n    [ ] a\n    [x] b\n    [ ] c\n")
                 '(3))))

(ert-deftest seq-tasks-in-progress-and-waiting-siblings-block ()
  "A sibling in progress or waiting blocks the next child."
  (should (equal (seq-tasks--blocked-lines
                  "[ ] P #seq-tasks\n    [@] a\n    [ ] b\n    [w] c\n    [ ] d\n")
                 '(3 4 5))))

(ert-deftest seq-tasks-the-parent-is-not-blocked ()
  "The task with #seq-tasks is not blocked, whatever its children are."
  (should-not (memq 1 (seq-tasks--blocked-lines
                       "[ ] P #seq-tasks\n    [ ] a\n    [ ] b\n"))))

(ert-deftest seq-tasks-subtasks-and-comments-between-siblings ()
  "Deeper tasks, comments and multi-line comments are not siblings.
b is not blocked (a is done) and c is (b is open); a-sub is a child of a."
  (should (equal (seq-tasks--blocked-lines
                  (concat "[ ] P #seq-tasks\n"
                          "    [x] a\n"
                          "        [ ] a-sub\n"
                          "        note\n"
                          "    /// side note\n"
                          "    [ ] b\n"
                          "    [ ] c\n"))
                 '(7))))

(ert-deftest seq-tasks-nested-seq-tasks ()
  "Each level uses the nearest parent."
  (should (equal (seq-tasks--blocked-lines
                  (concat "[ ] Root #seq-tasks\n"
                          "    [ ] Mid #seq-tasks\n"
                          "        [ ] a\n"
                          "        [ ] b\n"
                          "    [ ] Sibling\n"))
                 '(4 5))))

(ert-deftest seq-tasks-children-of-an-ordinary-parent-are-not-blocked ()
  "Without the tag on the parent, nothing is blocked."
  (should-not (seq-tasks--blocked-lines "[ ] P\n    [ ] a\n    [ ] b\n"))
  (should-not (seq-tasks--blocked-lines "[ ] P #seq-tasks-x\n    [ ] a\n    [ ] b\n")))

(ert-deftest seq-tasks-grandchild-is-not-a-direct-child ()
  "The tag applies to the direct children only."
  (should-not (seq-tasks--blocked-lines
               "[ ] P #seq-tasks\n    [x] a\n        [ ] g1\n        [ ] g2\n")))

(ert-deftest seq-tasks-blocked-child-has-the-blocked-face ()
  "The bracket of a blocked child has the blocked face; the parent's does not."
  (altodo-test-with-buffer "[ ] P #seq-tasks\n    [ ] a\n    [ ] b\n"
    (font-lock-mode 1)
    (font-lock-ensure)
    (should-not (eq (get-text-property 2 'face) 'altodo-dep-blocked-text-face))
    (goto-char (point-min))
    (forward-line 2)
    (should (eq (get-text-property (+ (point) 5) 'face)
                'altodo-dep-blocked-text-face))))

(provide 'seq-tasks-test)
;;; seq-tasks-test.el ends here
