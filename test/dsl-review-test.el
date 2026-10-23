;;; dsl-review-test.el --- DSL behavior of the design document  -*- lexical-binding: t; -*-

;;; Commentary:

;; Each test covers a finding of
;; `.claude/memo/examine/dsl-review-20261024/review.md' (R1 to R9), where the
;; DSL did not do what `doc/design-filter.md' (13.5) or the format
;; specification says.

;;; Code:

(add-to-list 'load-path (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defun dsl-review-matches (text pattern)
  "Return the numbers of the lines of TEXT that match the DSL PATTERN."
  (altodo-test-with-buffer text
    (let ((predicate (altodo--compile-simple-pattern pattern))
          lines)
      (while (not (eobp))
        (when (funcall predicate)
          (push (line-number-at-pos) lines))
        (forward-line 1))
      (nreverse lines))))

(defun dsl-review-compile-error (pattern)
  "Return the error message of compiling the DSL PATTERN, or nil."
  (condition-case err
      (let ((normalized (altodo--normalize-pattern pattern)))
        (unless (altodo--validate-pattern normalized)
          (error "Invalid pattern structure"))
        (altodo--compile-normalized-pattern normalized)
        nil)
    (error (error-message-string err))))


;;; R1: fenced code blocks

(ert-deftest dsl-review-fence-states-and-flags ()
  "R1: a line in a fenced code block is not a task for any pattern."
  (let ((text "```\n[x] ! + in code\n[w] w\n[@] p\n[~] c\n[ ] o\n```\n[ ] real\n"))
    (dolist (pattern '("done" "waiting" "progress" "cancelled" "priority" "star"
                       "state-any:done|open" "has-any-flag:star|priority"
                       "task"))
      (should-not (cl-intersection (dsl-review-matches text pattern)
                                   '(2 3 4 5 6))))
    (should (equal (dsl-review-matches text "open") '(8)))))

(ert-deftest dsl-review-fence-count-equals-filter ()
  "R1: the count of an entry is the number of lines that the filter shows."
  (altodo-test-with-buffer "[ ] a\n```\n[ ] in code\n```\n[ ] b\n"
    (should (= (altodo--count-matching-lines "open" nil (current-buffer)) 2))
    (altodo--filter-lines (altodo--compile-simple-pattern "open") nil 'none)
    (should (equal (cl-loop for line from 1 to 5
                            unless (progn (goto-char (point-min))
                                          (forward-line (1- line))
                                          (get-char-property (point) 'invisible))
                            collect line)
                   '(1 5)))))

(ert-deftest dsl-review-fence-heading ()
  "R1: a `# comment' in a fenced code block is not a heading."
  (let ((text "# Real\n[ ] a\n```bash\n# bash comment\n```\n[ ] b\n## Sub\n[ ] c\n"))
    (should (equal (dsl-review-matches text "heading") '(1 7)))
    (should (equal (dsl-review-matches text "heading:Real") '(2 6 8)))
    (should-not (dsl-review-matches text "heading:bash"))))


;;; R2, R3: tags and persons

(ert-deftest dsl-review-tag-is-the-whole-tag ()
  "R2: tag: matches the tags that the highlighting and the lists know."
  (let ((text (concat "[ ] 1 #java\n[ ] 2 #java2\n[ ] 3 #java-x\n[ ] 4 #java_x\n"
                      "[ ] 5 x#java\n[ ] 6 #JAVA\n[ ] 7 #java,\n[ ] 8 (#java)\n"
                      "[ ] 9 https://x/#java\n[ ] 10 #java:v\n[ ] 11 `#java`\n"
                      "/// 12 #java\n# H #java\n")))
    (should (equal (dsl-review-matches text "tag:java") '(1 6 7 10 12)))
    (should (equal (dsl-review-matches text "tag:java-x") '(3)))
    (should (equal (dsl-review-matches text "has-any-tag:java2|java_x") '(2 4)))
    (should (equal (dsl-review-matches text "tag:java:v") '(10)))))

(ert-deftest dsl-review-tag-value-needs-a-space-before ()
  "R2: tag-value: finds `#key:value' after a space only."
  (let ((text "[ ] 1 #p:5\n[ ] 2 x#p:5\n[ ] 3 #P:5\n"))
    (should (equal (dsl-review-matches text "tag-value:p 5") '(1 3)))))

(ert-deftest dsl-review-person-is-the-whole-name ()
  "R3: person: matches the name up to the next space, in any case."
  (let ((text (concat "[ ] 1 @bob\n[ ] 2 @bobby\n[ ] 3 @bob.\n[ ] 4 @bob,\n"
                      "[ ] 5 a@bob\n[ ] 6 @Bob\n[ ] 7 @bob.smith\n[ ] 8 @山田\n"
                      "/// 9 @bob\n")))
    (should (equal (dsl-review-matches text "person:bob") '(1 6 9)))
    (should (equal (dsl-review-matches text "person:bob.") '(3)))
    (should (equal (dsl-review-matches text "person:bob,") '(4)))
    (should (equal (dsl-review-matches text "person:山田") '(8)))
    (should (equal (dsl-review-matches text "has-any-person:bobby|bob.smith")
                   '(2 7)))))

(ert-deftest dsl-review-dynamic-values-ignore-case ()
  "R2, R3: the lists take a person or a tag in different cases as one value."
  (altodo-test-with-buffer "[ ] 1 @bob, @Bob #Java\n[ ] 2 @bob #java #java-x\n"
    (let ((titles (lambda (type)
                    (mapcar (lambda (entry)
                              (list (plist-get entry :title)
                                    (altodo--compute-entry-count
                                     entry (current-buffer))))
                            (altodo--expand-dynamic-filter
                             (list :title "%s" :type 'dynamic :dynamic-type type)
                             (current-buffer))))))
      (should (equal (funcall titles "person")
                     '(("Bob" 2) ("bob," 1))))
      (should (equal (funcall titles "tag")
                     '(("Java" 2) ("java-x" 1)))))))


;;; R4, R9: parent and root

(ert-deftest dsl-review-parent-and-root ()
  "R4: the parent is the nearest task that is indented less; root is indent 0."
  (let ((text (concat "[ ] Proj A #x\n    [ ] child\n        [ ] grand\n"
                      "    /// note\n        text\n[ ] Proj B\n    [ ] childB\n")))
    (should (equal (dsl-review-matches text "parent-task-regexp:Proj A")
                   '(1 2 4)))
    (should (equal (dsl-review-matches text "parent-task-regexp:child$")
                   '(2 3 5)))
    (should (equal (dsl-review-matches text "parent-task-regexp:#x") '(1 2 4)))
    (should (equal (dsl-review-matches text "root-task-regexp:Proj A")
                   '(1 2 3 4 5)))
    (should (equal (dsl-review-matches text "root-task-regexp:Proj B") '(6 7)))))

(ert-deftest dsl-review-parent-stops-at-a-heading ()
  "R9: a task under a heading does not have a parent from before the heading."
  (let ((text "[ ] Proj\n    [ ] child\n# Other\n    [ ] orphan\n"))
    (should (equal (dsl-review-matches text "parent-task-regexp:Proj") '(1 2)))
    (should (equal (dsl-review-matches text "root-task-regexp:Proj") '(1 2)))))

(ert-deftest dsl-review-ancestors-follow-edits ()
  "R4: the parents are made again after the buffer changes."
  (altodo-test-with-buffer "[ ] Proj\n    [ ] child\n"
    (let ((predicate (altodo--compile-simple-pattern "parent-task-regexp:Proj")))
      (goto-char (point-max))
      (insert "    [ ] second\n")
      (goto-char (point-min))
      (let (lines)
        (while (not (eobp))
          (when (funcall predicate) (push (line-number-at-pos) lines))
          (forward-line 1))
        (should (equal (nreverse lines) '(1 2 3)))))))

(ert-deftest dsl-review-parent-is-fast-without-parents ()
  "R4: the time of the parent patterns does not grow with the square."
  (altodo-test-with-buffer (apply #'concat (make-list 3000 "    [ ] orphan\n"))
    (let ((start (float-time)))
      (altodo--count-matching-lines "parent-task-regexp:zzz" t (current-buffer))
      (altodo--count-matching-lines "root-task-regexp:zzz" t (current-buffer))
      (should (< (- (float-time) start) 2.0)))))


;;; R5 to R8: invalid arguments

(ert-deftest dsl-review-invalid-regexp-is-found-at-compile-time ()
  "R5: an invalid regexp is an error of the compilation, for every pattern."
  (dolist (type '("regexp" "heading" "parent-task-regexp" "root-task-regexp"
                  "multiline-comment-contains"))
    (should (string-match-p "Invalid regexp"
                            (dsl-review-compile-error (concat type ":["))))))

(ert-deftest dsl-review-invalid-regexp-matches-nothing ()
  "R5: the sidebar treats such a pattern as one that matches no line."
  (let ((inhibit-message t))
    (should-not (dsl-review-matches "[ ] a\n" "regexp:["))))

(ert-deftest dsl-review-tag-value-conditions ()
  "R6: a condition with an operator is a number or an error."
  (let ((text "[ ] 1 #p:5\n[ ] 2 #p:10\n[ ] 3 #p:high\n"))
    (should (equal (dsl-review-matches text "tag-value:p (> 5)") '(2)))
    (should (equal (dsl-review-matches text "tag-value:p (<= 5)") '(1)))
    (should (equal (dsl-review-matches text "tag-value:p (5 high)") '(1 3)))
    (dolist (condition '("(!= 5)" "(> abc)" "(=> 5)" "(> 5 6)"))
      (should (string-match-p "Invalid tag-value condition"
                              (dsl-review-compile-error
                               (concat "tag-value:p " condition)))))))

(ert-deftest dsl-review-level-is-a-non-negative-integer ()
  "R7: level: takes digits only."
  (should (equal (dsl-review-matches "[ ] a\n    [ ] b\n" "level:1") '(2)))
  (dolist (arg '("abc" "-1" "1.5" ""))
    (should (dsl-review-compile-error (concat "level:" arg)))))

(ert-deftest dsl-review-logic-operands ()
  "R8: the operands are trimmed, and an empty operand is an error."
  (let ((text "[ ] ! a\n[x] b\n"))
    (should (equal (dsl-review-matches text "and: open , priority") '(1)))
    (should (equal (dsl-review-matches text "or:done, priority ") '(1 2)))
    (dolist (pattern '("and:open,,priority" "and:open,priority," "and:,open"
                       "and: ,open"))
      (should (string-match-p "empty operand"
                              (dsl-review-compile-error pattern))))))

(provide 'dsl-review-test)
;;; dsl-review-test.el ends here
