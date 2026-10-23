;;; dsl-multi-patterns-test.el --- Tests for the line type and multi-value DSL patterns  -*- lexical-binding: t; -*-

;;; Commentary:
;; T20261018-84, -85, -86: `state-any', `has-any-flag', `has-any-tag',
;; `has-any-person', `has-all-tags', `task', `comment', `multiline-comment',
;; `heading', `empty-line' and `any-line'.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defconst dsl-multi-patterns-test--text
  (concat "# Heading\n"                    ; 1
          "[ ] open #a #b @x\n"            ; 2
          "[x] done #a @y\n"               ; 3
          "[@] + progress\n"               ; 4
          "[w] ! waiting\n"                ; 5
          "    multiline\n"                ; 6
          "/// note\n"                     ; 7
          "\n"                             ; 8
          "Plain text\n"                   ; 9
          "Title\n"                        ; 10
          "=====\n")                       ; 11
  "Sample buffer.  The comments give the line numbers.")

(defun dsl-multi-patterns-test--lines (pattern)
  "Return the line numbers of the sample text that match PATTERN."
  (altodo-test-with-buffer dsl-multi-patterns-test--text
    (let ((predicate (altodo--compile-simple-pattern pattern))
          (lines nil)
          (line 1))
      (while (not (eobp))
        (when (funcall predicate)
          (push line lines))
        (forward-line 1)
        (setq line (1+ line)))
      (nreverse lines))))

;;; Line types and special conditions

(ert-deftest dsl-multi-patterns-task ()
  "`task' matches the task lines."
  (should (equal (dsl-multi-patterns-test--lines "task") '(2 3 4 5))))

(ert-deftest dsl-multi-patterns-comment ()
  "`comment' matches the `///' lines."
  (should (equal (dsl-multi-patterns-test--lines "comment") '(7))))

(ert-deftest dsl-multi-patterns-multiline-comment ()
  "`multiline-comment' matches the lines of a multi-line comment."
  (should (equal (dsl-multi-patterns-test--lines "multiline-comment") '(6))))

(ert-deftest dsl-multi-patterns-heading ()
  "`heading' matches ATX headings and Setext titles, not underlines."
  (should (equal (dsl-multi-patterns-test--lines "heading") '(1 10))))

(ert-deftest dsl-multi-patterns-empty-line ()
  "`empty-line' matches blank lines."
  (should (equal (dsl-multi-patterns-test--lines "empty-line") '(8))))

(ert-deftest dsl-multi-patterns-any-line ()
  "`any-line' matches every line."
  (should (equal (dsl-multi-patterns-test--lines "any-line")
                 '(1 2 3 4 5 6 7 8 9 10 11))))

;;; Multi-value patterns

(ert-deftest dsl-multi-patterns-state-any ()
  "`state-any' matches a line that has any of the states."
  (should (equal (dsl-multi-patterns-test--lines "state-any:open,done") '(2 3)))
  (should (equal (dsl-multi-patterns-test--lines "state-any:progress,waiting,cancelled")
                 '(4 5)))
  (should (equal (dsl-multi-patterns-test--lines "state-any:open") '(2))))

(ert-deftest dsl-multi-patterns-has-any-flag ()
  "`has-any-flag' matches a line that has any of the flags."
  (should (equal (dsl-multi-patterns-test--lines "has-any-flag:star,priority")
                 '(4 5)))
  (should (equal (dsl-multi-patterns-test--lines "has-any-flag:star") '(4))))

(ert-deftest dsl-multi-patterns-has-any-and-all-tags ()
  "`has-any-tag' matches any tag; `has-all-tags' needs all of them."
  (should (equal (dsl-multi-patterns-test--lines "has-any-tag:a,b") '(2 3)))
  (should (equal (dsl-multi-patterns-test--lines "has-any-tag:b") '(2)))
  (should (equal (dsl-multi-patterns-test--lines "has-all-tags:a,b") '(2)))
  (should-not (dsl-multi-patterns-test--lines "has-all-tags:a,zzz")))

(ert-deftest dsl-multi-patterns-has-any-person ()
  "`has-any-person' matches a line that has any of the persons."
  (should (equal (dsl-multi-patterns-test--lines "has-any-person:x,y") '(2 3)))
  (should (equal (dsl-multi-patterns-test--lines "has-any-person:y") '(3))))

;;; Combination and errors

(ert-deftest dsl-multi-patterns-bar-separator-in-logic ()
  "Inside a logic operation, the values are separated by a bar."
  (should (equal (dsl-multi-patterns-test--lines "and:open,has-any-tag:a|b") '(2)))
  (should (equal (dsl-multi-patterns-test--lines "or:comment,empty-line") '(7 8)))
  (should (equal (dsl-multi-patterns-test--lines "not:any-line") nil))
  (should (equal (dsl-multi-patterns-test--lines "state-any:open|done") '(2 3))))

(ert-deftest dsl-multi-patterns-unknown-value-matches-nothing ()
  "An unknown value gives a message and a pattern that matches nothing."
  (let ((messages nil))
    (cl-letf (((symbol-function 'message)
               (lambda (format &rest args)
                 (push (apply #'format format args) messages))))
      (should-not (dsl-multi-patterns-test--lines "state-any:open,foo"))
      (should-not (dsl-multi-patterns-test--lines "has-any-flag:bold")))
    (should (cl-some (lambda (m) (string-match-p "Unknown value for state-any: foo" m))
                     messages))
    (should (cl-some (lambda (m) (string-match-p "Unknown value for has-any-flag: bold" m))
                     messages))))

(ert-deftest dsl-multi-patterns-sidebar-count ()
  "The new patterns work as sidebar entries and count the task lines."
  (altodo-test-with-buffer dsl-multi-patterns-test--text
    (let ((entry '(:title "x %n" :type search-simple
                          :pattern "state-any:open,done" :count-format t)))
      (should (= (altodo--get-entry-count entry (current-buffer)) 2)))))

(provide 'dsl-multi-patterns-test)
;;; dsl-multi-patterns-test.el ends here
