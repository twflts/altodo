;;; seq-tasks-tag-test.el --- Tests for the #seq-tasks tag detection  -*- lexical-binding: t; -*-

;;; Commentary:
;; `#seq-tasks' must be matched as a whole tag name.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defun seq-tasks-tag-test--has-tag (line)
  "Return non-nil if LINE has the #seq-tasks tag."
  (altodo-test-with-buffer line
    (and (altodo--has-seq-tasks-tag) t)))

(ert-deftest seq-tasks-tag-test-matches-the-tag ()
  (should (seq-tasks-tag-test--has-tag "[ ] parent #seq-tasks\n"))
  (should (seq-tasks-tag-test--has-tag "[ ] parent #seq-tasks #other\n"))
  (should (seq-tasks-tag-test--has-tag "[ ] #seq-tasks parent\n"))
  (should (seq-tasks-tag-test--has-tag "[ ] parent #seq-tasks")))

(ert-deftest seq-tasks-tag-test-ignores-longer-tag-names ()
  (should-not (seq-tasks-tag-test--has-tag "[ ] parent #seq-tasks-foo\n"))
  (should-not (seq-tasks-tag-test--has-tag "[ ] parent #seq-tasks2\n"))
  (should-not (seq-tasks-tag-test--has-tag "[ ] parent #my-seq-tasks\n"))
  (should-not (seq-tasks-tag-test--has-tag "[ ] parent seq-tasks\n")))

(ert-deftest seq-tasks-tag-test-status-of-a-longer-tag ()
  "A parent with #seq-tasks-foo does not block its children."
  (altodo-test-with-buffer "[ ] parent #seq-tasks-foo\n    [ ] a\n    [ ] b\n"
    (forward-line 2)
    (should-not (altodo--is-seq-tasks-child-blocked-p))))

(ert-deftest seq-tasks-tag-test-blocks-the-second-child ()
  (altodo-test-with-buffer "[ ] parent #seq-tasks\n    [ ] a\n    [ ] b\n"
    (forward-line 2)
    (should (altodo--is-seq-tasks-child-blocked-p))))

(defun seq-tasks-tag-test--face-at (line column)
  "Return the face at COLUMN of LINE (1-based) in the current buffer."
  (save-excursion
    (goto-char (point-min))
    (forward-line (1- line))
    (forward-char column)
    (get-text-property (point) 'face)))

(ert-deftest seq-tasks-tag-test-state-change-refreshes-faces ()
  "Finishing a task updates the faces of the task it was blocking."
  (altodo-test-with-buffer "[ ] parent #seq-tasks\n    [ ] a\n    [ ] b\n"
    (font-lock-ensure)
    (should (eq (seq-tasks-tag-test--face-at 3 5) 'altodo-dep-blocked-text-face))
    (forward-line 1)
    (altodo-set-task-done)
    (font-lock-ensure)
    (should (eq (seq-tasks-tag-test--face-at 3 5) 'altodo-task-open-face))))

(provide 'seq-tasks-tag-test)
;;; seq-tasks-tag-test.el ends here
