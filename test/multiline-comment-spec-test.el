;;; multiline-comment-spec-test.el --- Multi-line comment rules of the specification  -*- lexical-binding: t; -*-

;;; Commentary:

;; Each case checks whether one line is a multi-line comment, following
;; section 3.2.3 of doc/altodo_spec.md:
;;   - the first line is indented by the previous task or `///' line + 4 spaces
;;   - every non-task line with that indentation is part of the comment
;;   - the comment ends at a line with a different indentation or at a
;;     completely empty line
;; Cases that the implementation does not satisfy yet are marked as expected
;; failures with the TODO id (see project.altodo).

;;; Code:

(require 'ert)
(require 'altodo)

(defun multiline-comment-spec-test--line-p (text line)
  "Return non-nil if LINE (1-based) of TEXT is a multi-line comment."
  (with-temp-buffer
    (insert text)
    (altodo-mode)
    (font-lock-ensure)
    (goto-char (point-min))
    (forward-line (1- line))
    (and (altodo--multiline-comment-p) t)))

(defmacro multiline-comment-spec-test--case (name text line expected &optional todo)
  "Define a test NAME: is LINE of TEXT a multi-line comment (EXPECTED)?
TODO is the id of the task that fixes a known difference."
  (declare (indent 1))
  `(ert-deftest ,(intern (format "multiline-comment-spec-test-%s" name)) ()
     ,@(when todo
         `(:expected-result :failed))
     (should (eq (multiline-comment-spec-test--line-p ,text ,line) ,expected))))

;;; Lines that are multi-line comments

(multiline-comment-spec-test--case a-indent-plus-4
  "[ ] task\n    description\n" 2 t)
(multiline-comment-spec-test--case b-consecutive-lines
  "[ ] task\n    line 1\n    line 2\n" 3 t)
(multiline-comment-spec-test--case e-space-only-line
  "[ ] task\n    line 1\n    \n    line 3\n" 3 t)
(multiline-comment-spec-test--case f-after-space-only-line
  "[ ] task\n    line 1\n    \n    line 3\n" 4 t)
(multiline-comment-spec-test--case i-under-single-line-comment
  "[ ] task\n    /// note\n        continued\n" 3 t)
(multiline-comment-spec-test--case o-under-nested-task
  "[ ] a\n    [ ] b\n        about b\n" 3 t)
(multiline-comment-spec-test--case p-under-task-after-blank-line
  "[ ] a\n\n        [ ] b\n            about b\n" 4 t)
(multiline-comment-spec-test--case l-link-line
  "[ ] task\n    [ref](http://example.com)\n" 2 t)
(multiline-comment-spec-test--case m-inside-fenced-block
  "[ ] task\n    ```\n    code\n    ```\n" 3 t)
(multiline-comment-spec-test--case n-markdown-list
  "[ ] task\n    - item\n" 2 t)

;;; Lines that are not multi-line comments

(multiline-comment-spec-test--case c-same-indent-as-subtask
  "[ ] parent\n    [ ] child\n    same indent\n" 3 nil)
(multiline-comment-spec-test--case d-indent-plus-8
  "[ ] task\n        too deep\n" 2 nil)
(multiline-comment-spec-test--case i2-same-indent-as-single-line-comment
  "[ ] task\n    /// note\n    same indent\n" 3 nil)
(multiline-comment-spec-test--case g-after-empty-line
  "[ ] task\n    line 1\n\n    after empty line\n" 4 nil)
(multiline-comment-spec-test--case h-no-indent
  "[ ] task\n    line 1\ntext\n" 3 nil)
(multiline-comment-spec-test--case j-no-task-above
  "# heading\n\n    just text\n" 3 nil)
(multiline-comment-spec-test--case k-task-line
  "[ ] task\n    [x] subtask\n" 2 nil)

(provide 'multiline-comment-spec-test)
;;; multiline-comment-spec-test.el ends here
