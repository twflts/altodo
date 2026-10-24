;;; docs-code-review-test.el --- Fixes of the documentation and code review  -*- lexical-binding: t; -*-

;;; Commentary:

;; Each test covers an item of
;; `.claude/memo/examine/docs-code-review-20261024/review.md' (C1 to C5, F1 to
;; F9), where the code did not do what the documents or the specification say.

;;; Code:

(add-to-list 'load-path (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defun docs-code-review-face-at (text search)
  "Return the face of the first character of SEARCH in fontified TEXT."
  (altodo-test-with-buffer text
    (font-lock-mode 1)
    (font-lock-ensure)
    (search-forward search)
    (get-char-property (match-beginning 0) 'face)))

(defun docs-code-review-face-has (face value)
  "Return non-nil if FACE (a symbol or a list of faces) includes VALUE."
  (if (listp face) (memq value face) (eq face value)))


;;; C1: adding a task goes after the subtree

(ert-deftest docs-code-review-add-task-after-multiline-comment ()
  "C1: a new task is inserted after the multi-line comment of the task."
  (altodo-test-with-buffer "[ ] a\n    detail\n[ ] b\n"
    (altodo-add-task)
    (should (equal (buffer-string) "[ ] a\n    detail\n[ ] \n[ ] b\n"))
    (should (= (point) (+ (point-min) (length "[ ] a\n    detail\n[ ] "))))))

(ert-deftest docs-code-review-add-task-after-children ()
  "C1: a new task is inserted after the children and grandchildren."
  (altodo-test-with-buffer "[ ] a\n    [ ] a1\n        [ ] a11\n[ ] b\n"
    (altodo-add-task)
    (should (equal (buffer-string)
                   "[ ] a\n    [ ] a1\n        [ ] a11\n[ ] \n[ ] b\n"))))

(ert-deftest docs-code-review-add-subtask-as-last-child ()
  "C1: a new subtask is the last child, one level deeper."
  (altodo-test-with-buffer "[ ] a\n    [ ] a1\n    note of a1\n[ ] b\n"
    (altodo-add-subtask)
    (should (equal (buffer-string)
                   "[ ] a\n    [ ] a1\n    note of a1\n    [ ] \n[ ] b\n"))))

(ert-deftest docs-code-review-add-task-at-end-without-newline ()
  "C1: a task is added at the end of a buffer without a final newline."
  (altodo-test-with-buffer "[ ] a\n    [ ] a1"
    (altodo-add-task)
    (should (equal (buffer-string) "[ ] a\n    [ ] a1\n[ ] "))))

(ert-deftest docs-code-review-add-task-keeps-blank-line ()
  "C1: a blank line after the subtree stays after the new task."
  (altodo-test-with-buffer "[ ] a\n    [ ] a1\n\n[ ] b\n"
    (altodo-add-task)
    (should (equal (buffer-string) "[ ] a\n    [ ] a1\n[ ] \n\n[ ] b\n"))))

(ert-deftest docs-code-review-enter-after-subtree ()
  "C1: RET at a task adds a task after its multi-line comment and children."
  (altodo-test-with-buffer "[ ] a\n    detail\n    [ ] a1\n[ ] b\n"
    (end-of-line)
    (altodo-enter)
    (should (equal (buffer-string)
                   "[ ] a\n    detail\n    [ ] a1\n[ ] \n[ ] b\n"))))

(ert-deftest docs-code-review-enter-in-multiline-comment ()
  "C1: RET in a multi-line comment continues the comment."
  (altodo-test-with-buffer "[ ] a\n    detail\n[ ] b\n"
    (forward-line 1)
    (end-of-line)
    (altodo-enter)
    (should (equal (buffer-string) "[ ] a\n    detail\n    \n[ ] b\n"))))


;;; C2: progress and waiting remove #done

(ert-deftest docs-code-review-progress-removes-done-tag ()
  "C2: setting the progress state removes the #done tag."
  (altodo-test-with-buffer "[x] a #done:2026-01-01\n"
    (altodo-set-task-progress)
    (should (equal (buffer-string) "[@] a\n"))))

(ert-deftest docs-code-review-waiting-removes-done-tag ()
  "C2: setting the waiting state removes the #done tag."
  (altodo-test-with-buffer "[~] a #done:2026-01-01\n"
    (altodo-set-task-waiting)
    (should (equal (buffer-string) "[w] a\n"))))


;;; C3: moving the indentation

(ert-deftest docs-code-review-indent-moves-multiline-comment ()
  "C3: the multi-line comment moves with its task; children stay."
  (altodo-test-with-buffer "[ ] a\n[ ] b\n    detail\n    [ ] b1\n"
    (forward-line 1)
    (altodo-indent-increase)
    (should (equal (buffer-string)
                   "[ ] a\n    [ ] b\n        detail\n    [ ] b1\n"))
    (altodo-indent-decrease)
    (should (equal (buffer-string)
                   "[ ] a\n[ ] b\n    detail\n    [ ] b1\n"))))

(ert-deftest docs-code-review-indent-moves-comment-line-note ()
  "C3: the multi-line comment of a `///' line moves with it."
  (altodo-test-with-buffer "[ ] a\n/// note\n    more\n"
    (forward-line 1)
    (altodo-indent-increase)
    (should (equal (buffer-string) "[ ] a\n    /// note\n        more\n"))))


;;; C4: priority toggle

(ert-deftest docs-code-review-priority-toggles-off ()
  "C4: the same priority level removes the flag; the star stays."
  (altodo-test-with-buffer "[ ] + !! a\n"
    (altodo-set-priority-2)
    (should (equal (buffer-string) "[ ] + a\n"))
    (altodo-set-priority-3)
    (should (equal (buffer-string) "[ ] + !!! a\n"))))


;;; C5: fenced code blocks

(ert-deftest docs-code-review-state-change-ignores-fence ()
  "C5: a state command does not change a line in a fenced code block."
  (altodo-test-with-buffer "```\n[ ] in code\n```\n"
    (forward-line 1)
    (altodo-set-task-done)
    (should (equal (buffer-string) "```\n[ ] in code\n```\n"))))


;;; F1 to F5, F9: font-lock

(ert-deftest docs-code-review-date-in-inline-code-not-highlighted ()
  "F1: a date in inline code has no date face."
  (should-not (docs-code-review-face-has
               (docs-code-review-face-at "[ ] a `-> 2026-01-01` b\n" "2026")
               'altodo-date-face)))

(ert-deftest docs-code-review-tag-in-inline-code-not-highlighted ()
  "F2: a tag in inline code has no tag face."
  (should-not (docs-code-review-face-has
               (docs-code-review-face-at "[ ] a `#work` b\n" "#work")
               'altodo-tag-face)))

(ert-deftest docs-code-review-tag-in-heading-highlighted ()
  "F2: a tag in a heading has the tag face."
  (should (docs-code-review-face-has
           (docs-code-review-face-at "# Plan #work\n" "#work")
           'altodo-tag-face)))

(ert-deftest docs-code-review-person-only-on-inline-lines ()
  "F3: a person has the person face on a task line, not in a paragraph."
  (should-not (docs-code-review-face-has
               (docs-code-review-face-at "plain @alice text\n" "@alice")
               'altodo-person-tag-face))
  (should (docs-code-review-face-has
           (docs-code-review-face-at "[ ] a @alice text\n" "@alice")
           'altodo-person-tag-face)))

(ert-deftest docs-code-review-comment-line-flags-highlighted ()
  "F4: the star flag of a `///' line has the star face."
  (should (docs-code-review-face-has
           (docs-code-review-face-at "/// + note\n" "+")
           'altodo-flag-star-face)))

(ert-deftest docs-code-review-dep-tag-needs-boundary ()
  "F5: `x#dep:id' is not a dependency tag."
  (altodo-test-with-buffer "[ ] a #id:a\n[ ] b x#dep:a\n"
    (forward-line 1)
    (should-not (altodo--get-task-deps (point)))))

(ert-deftest docs-code-review-special-tag-names ()
  "F9: `seq-tasks' is a special tag; `idea' is not."
  (should (member "seq-tasks" altodo-special-tag-names))
  (should-not (docs-code-review-face-has
               (docs-code-review-face-at "[ ] a #idea\n" "#idea")
               'altodo-special-tag-face))
  (should (docs-code-review-face-has
           (docs-code-review-face-at "[ ] a #seq-tasks\n" "#seq-tasks")
           'altodo-special-tag-face)))

(provide 'docs-code-review-test)
;;; docs-code-review-test.el ends here
