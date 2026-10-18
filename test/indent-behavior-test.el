;;; indent-behavior-test.el --- Tests for TAB and the indentation helpers  -*- lexical-binding: t; -*-

;;; Commentary:
;; `altodo-indent-line' (TAB) cycles the indentation of a task, and falls
;; back to the Markdown behavior on other lines.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defun indent-behavior-test--tab (text line times)
  "Press TAB TIMES times on LINE (1-based) of TEXT.
Return the list of the line after each press."
  (altodo-test-with-buffer text
    (forward-line (1- line))
    (let (results)
      (dotimes (_ times)
        (setq last-command nil)
        (altodo-indent-line)
        (push (buffer-substring-no-properties (line-beginning-position)
                                              (line-end-position))
              results))
      (nreverse results))))

(ert-deftest indent-behavior-test-tab-cycles-sibling-task ()
  "TAB on a task after a task toggles between the sibling and child level."
  (should (equal (indent-behavior-test--tab "[ ] a\n[ ] b\n" 2 4)
                 '("    [ ] b" "[ ] b" "    [ ] b" "[ ] b"))))

(ert-deftest indent-behavior-test-tab-after-subtask ()
  "TAB on a task after a subtask cycles through the possible levels."
  (should (equal (indent-behavior-test--tab "[ ] a\n    [ ] b\n[ ] c\n" 3 2)
                 '("    [ ] c" "[ ] c"))))

(ert-deftest indent-behavior-test-tab-first-line ()
  "A task on the first line cannot be indented."
  (should (equal (indent-behavior-test--tab "[ ] a\n" 1 2)
                 '("[ ] a" "[ ] a"))))

(ert-deftest indent-behavior-test-tab-single-line-comment ()
  "A single-line comment is indented like a task."
  (should (equal (indent-behavior-test--tab "[ ] a\n    /// n\n/// m\n" 3 2)
                 '("    /// m" "/// m"))))

(ert-deftest indent-behavior-test-tab-moves-multiline-comment ()
  "The multi-line comment moves together with its task."
  (altodo-test-with-buffer "[ ] a\n[ ] b\n    note\n"
    (forward-line 1)
    (altodo-indent-line)
    (should (equal (buffer-substring-no-properties (point-min) (point-max))
                   "[ ] a\n    [ ] b\n        note\n"))))

(ert-deftest indent-behavior-test-tab-on-plain-text-does-not-recurse ()
  "TAB on a plain text line falls back to Markdown without an endless loop."
  (should (progn (indent-behavior-test--tab "text\n\nmore text\n" 3 3) t))
  (should (progn (indent-behavior-test--tab "[ ] a\n    note\ntext\n" 3 2) t))
  (should (progn (indent-behavior-test--tab "[ ] a\n\n" 2 2) t)))

(ert-deftest indent-behavior-test-tab-irregular-indent ()
  "A task indented by a non-multiple of the indent size is aligned."
  (should (equal (indent-behavior-test--tab "[ ] a\n  [ ] b\n" 2 1)
                 '("    [ ] b"))))

(ert-deftest indent-behavior-test-normalize-indent ()
  "An indentation is rounded up to a multiple of the indent size."
  (should (equal (mapcar #'altodo--normalize-indent '(0 1 3 4 5 8))
                 '(0 4 4 4 8 8)))
  (let ((altodo-indent-size 2))
    (should (equal (mapcar #'altodo--normalize-indent '(0 1 2 3))
                   '(0 2 2 4)))))

(ert-deftest indent-behavior-test-set-line-indent ()
  "The indentation of the current line is replaced."
  (altodo-test-with-buffer "  [ ] a\n"
    (altodo--set-line-indent 4)
    (should (equal (buffer-substring-no-properties (point-min) (point-max))
                   "    [ ] a\n"))
    (altodo--set-line-indent 0)
    (should (equal (buffer-substring-no-properties (point-min) (point-max))
                   "[ ] a\n"))))

(ert-deftest indent-behavior-test-reset-indent-flags ()
  "Resetting clears the state used to cycle the indentation."
  (altodo-test-with-buffer "[ ] a\n"
    (setq altodo--last-indent-action 'increase
          altodo--last-indent-line 3
          altodo--original-indent 4)
    (altodo--reset-indent-flags)
    (should-not altodo--last-indent-action)
    (should-not altodo--last-indent-line)
    (should-not altodo--original-indent)))

(ert-deftest indent-behavior-test-indent-multiline-comments ()
  "The given lines of a multi-line comment are shifted by the delta."
  (altodo-test-with-buffer "[ ] a\n    c1\n    c2\n[ ] b\n"
    (altodo--indent-multiline-comments '(2 3) 4)
    (should (equal (buffer-substring-no-properties (point-min) (point-max))
                   "[ ] a\n        c1\n        c2\n[ ] b\n"))))

(provide 'indent-behavior-test)
;;; indent-behavior-test.el ends here
