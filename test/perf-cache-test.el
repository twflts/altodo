;;; perf-cache-test.el --- Caches that speed up the fontification  -*- lexical-binding: t; -*-
;;; Commentary:

;; The cache of the inline code spans (`altodo-inline-code-cache'), the index
;; of the #id tags and the search of the parent of a #seq-tasks child must not
;; change the result.  The faces with the cache are compared with the faces
;; without it, for the whole buffer, for chunks in reverse order and after an
;; edit.  The memo is `.claude/memo/examine/perf-memo-review-20261026/review.md'.

;;; Code:

(add-to-list 'load-path (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defun perf-cache-faces ()
  "Return the faces of the current buffer as a list of (BEG END FACE)."
  (let ((pos (point-min))
        (result nil))
    (while (< pos (point-max))
      (let ((next (min (next-single-property-change pos 'face nil (point-max))
                       (next-single-property-change
                        pos 'altodo-dep-status nil (point-max)))))
        (push (list pos next (get-text-property pos 'face)
                    (get-text-property pos 'altodo-dep-status))
              result)
        (setq pos next)))
    (nreverse result)))

(defun perf-cache-result (text cache)
  "Fontify TEXT with `altodo-inline-code-cache' set to CACHE.
Return the faces after the whole buffer, after chunks in reverse order and
after an edit."
  (let ((altodo-inline-code-cache cache))
    (with-temp-buffer
      (insert text)
      (altodo-mode)
      (font-lock-mode 1)
      (font-lock-ensure)
      (let ((whole (perf-cache-faces))
            chunks edited)
        (font-lock-flush)
        (let ((end (point-max)))
          (while (> end (point-min))
            (let ((beg (max (point-min) (- end 40))))
              (font-lock-ensure beg end)
              (setq end beg))))
        (setq chunks (perf-cache-faces))
        (goto-char (/ (point-max) 2))
        (insert "`")
        (goto-char (/ (point-max) 3))
        (insert "_i_ ")
        (font-lock-flush)
        (font-lock-ensure)
        (setq edited (perf-cache-faces))
        (list whole chunks edited)))))

(defconst perf-cache-texts
  (list
   ;; Code spans, a span over two lines, italics near and inside them.
   "[ ] a `code` _it_ and foo_bar_baz `x _y_ z`\n    /// `multi _x_ line\n    /// more` _z_ end\n[ ] b *e* `c`\n"
   ;; Blocks separated by blank lines, a block that begins with indentation.
   "[ ] a `x\n\n    /// y` _i_\n\n    /// `c` _d_ _e_\n[ ] t `u` *v*\n"
   ;; Fenced code blocks and HTML comments in a block.
   "[ ] a _i_ `c`\n```\n[ ] in _fence_ `c`\n```\n[ ] b <!-- `x _y_` --> _z_\n"
   ;; A fence and a comment that go over a blank line.
   "```\n`a\n\n_b_ `c`\n```\n<!--\n\n`x _y_ z`\n-->\n[ ] t `p` _q_\n"
   ;; A rejected candidate after the last span (the match data it leaves).
   "[ ] a `x` _i_\n[ ] <!-- `c` --> _j_ `y`\n"
   ;; Random texts that once differed from `markdown-mode' (the memo).
   "`\n-->word#tag_1.      \n`#tag@bob```\n```\n/// _foo_bar<!--\n``[ ] `[ ]  a*b```\n> word[ ] #tag    [ ] *` <!--///  `*foo_bara*bfoo_bar**``@bob``@bob\\`\n`` word\n>     \n    *`- [ ] _-->@bob_- \\`\n\n <!-- word\n> ```\n[ ] \n[ ] ```\nfoo_bar\n\na*b[ ]  foo_barfoo_bar~~~\n__-->\\`word_~~~\n*__\n **| a | b |\n[x] \n\n#tag 1. <!--    | a | b |\n> [x] word\\`[ ]  - #tag`\n\n<!--*\n@bob~~~\n````\n[ ] #taga*b`[ ] "
   "#tag\n[ ] ```1. [ ] _[x] ~~~\n~~~\n\\`*@bob\nword[x] *\n*```\n~~~\n| a | b |\n\\`a*b| a | b |\n@bob/// /// a*b**    *-->`"
   "[ ]     @bob[ ] `\n\n__/// [ ] ~~~\n*`x\ny``\\`<!--[ ]  --> @bob```\n<!--\n    ```\n/// `z` *e* #tag[ ] ``x\ny``\n\n#tag/// `z` *e* @bob#tag`\n    ```\n/// `z` *e* `__word[x] > /// `@bobword@bob`1. 1. ~~~\n - [ ] <!--**~~~\n`@bob\n    ```\nfoo_bar\n\n| a | b |\n\n    ```\n\n\n\n[ ] t `c` _i_  > __<!--*\\` - word\n    ```\n`x\ny`> `> _\n\n[ ] t `c` _i_ #tag__~~~\n -->__\n `a_b`"
   )
  "Texts to fontify with and without the cache of the inline code spans.")

(ert-deftest perf-cache-inline-code-same-faces ()
  "The faces are the same with and without the cache of the code spans."
  (dolist (text perf-cache-texts)
    (should (equal (perf-cache-result text t)
                   (perf-cache-result text nil)))))

(ert-deftest perf-cache-inline-code-fewer-searches ()
  "With the cache, the code spans of a block are searched once."
  (let ((text (apply #'concat
                     (mapcar (lambda (i) (format "[ ] task %d foo_bar_baz\n" i))
                             (number-sequence 1 120))))
        (calls 0))
    (cl-letf* ((original (symbol-function 'markdown-match-code))
               ((symbol-function 'markdown-match-code)
                (lambda (last) (cl-incf calls) (funcall original last))))
      (let ((altodo-inline-code-cache nil))
        (setq calls 0)
        (altodo-test-with-buffer text (font-lock-ensure))
        (should (> calls 100)))
      (let ((altodo-inline-code-cache t))
        (setq calls 0)
        (altodo-test-with-buffer text (font-lock-ensure))
        (should (< calls 20))))))

(ert-deftest perf-cache-inline-code-restores-function ()
  "The replacement of `markdown-inline-code-at-pos' ends with the fontification."
  (let ((original (symbol-function 'markdown-inline-code-at-pos)))
    (altodo-test-with-buffer "[ ] a `c` _i_\n" (font-lock-ensure))
    (should (eq (symbol-function 'markdown-inline-code-at-pos) original))
    (should-not altodo--inline-code-original)))

(ert-deftest perf-cache-inline-code-not-for-comment-block ()
  "A block with a comment or a fence is searched by `markdown-mode'."
  (dolist (text '("[ ] a <!-- c --> _i_ `x`\n" "[ ] a\n```\nb\n```\n"))
    (altodo-test-with-buffer text
      (font-lock-ensure)
      (should-not (altodo--inline-code-scan-for (1+ (point-min)))))))


;;; Index of the #id tags

(ert-deftest perf-cache-id-first-tag-wins ()
  "The first tag with an ID gives the state, as the search of the buffer did."
  (altodo-test-with-buffer "[x] one #id:a\n[ ] two #id:a\n[ ] three #id:b\n"
    (should (equal (altodo--find-task-by-id "a") "x"))
    (should (equal (altodo--find-task-by-id "b") " "))
    (should-not (altodo--find-task-by-id "c"))))

(ert-deftest perf-cache-id-whole-tag ()
  "A tag ends with a space, a tab or the end of the line, not before."
  (altodo-test-with-buffer "[x] a #id:ab\n[@] b #id:a-b\n[w] c #id:a\tz\n"
    (should (equal (altodo--find-task-by-id "a") "w"))
    (should (equal (altodo--find-task-by-id "ab") "x"))
    (should (equal (altodo--find-task-by-id "a-b") "@"))))

(ert-deftest perf-cache-id-tag-in-tag ()
  "A tag inside another one is found, as the search of the buffer did."
  (altodo-test-with-buffer "[x] a #id:p#id:q \n"
    (should (equal (altodo--find-task-by-id "q") "x"))
    (should-not (altodo--find-task-by-id "p"))))

(ert-deftest perf-cache-id-case-fold ()
  "The case of an ID follows `case-fold-search'."
  (altodo-test-with-buffer "[x] a #id:Abc\n"
    (let ((case-fold-search t))
      (should (equal (altodo--find-task-by-id "aBC") "x")))
    (let ((case-fold-search nil))
      (should-not (altodo--find-task-by-id "aBC"))
      (should (equal (altodo--find-task-by-id "Abc") "x")))))

(ert-deftest perf-cache-id-index-follows-text ()
  "The index changes with the text, not with the text properties."
  (altodo-test-with-buffer "[x] a #id:a\n"
    (should (equal (altodo--find-task-by-id "a") "x"))
    (let ((index altodo--id-index))
      (put-text-property (point-min) (point-max) 'face 'bold)
      (altodo--find-task-by-id "a")
      (should (eq altodo--id-index index)))
    (goto-char (point-max))
    (insert "[@] b #id:b\n")
    (should (equal (altodo--find-task-by-id "b") "@"))))

(ert-deftest perf-cache-id-circular-dependency ()
  "A circle of dependencies is found through the index."
  (altodo-test-with-buffer "[ ] a #id:a #dep:b\n[ ] b #id:b #dep:a\n"
    (should (eq (catch 'circular (altodo--check-circular-dependency "a"))
                'circular))
    (should (eq (altodo--check-all-deps-completed '("b")) 'circular))))


;;; The parent of a #seq-tasks child

(defun perf-cache-seq-blocked (text)
  "Return the numbers of the lines of TEXT that are blocked seq-tasks children."
  (altodo-test-with-buffer text
    (let (lines)
      (while (not (eobp))
        (when (altodo--is-seq-tasks-child-blocked-p)
          (push (line-number-at-pos) lines))
        (forward-line 1))
      (nreverse lines))))

(ert-deftest perf-cache-seq-tasks-blocked-children ()
  "A child is blocked while the sibling above is open; descendants are skipped.
The first child (line 2) is never blocked, and neither is the child below a
done sibling (line 7)."
  (should (equal (perf-cache-seq-blocked
                  (concat "[ ] p #seq-tasks\n"
                          "    [ ] c1\n"
                          "        [ ] g1\n"
                          "        /// note\n"
                          "    [ ] c2\n"
                          "    [x] c3\n"
                          "    [ ] c4\n"))
                 '(5 6))))

(ert-deftest perf-cache-seq-tasks-done-sibling-unblocks ()
  "A child below a done or cancelled sibling is not blocked."
  (should (equal (perf-cache-seq-blocked
                  "[ ] p #seq-tasks\n    [x] c1\n    [ ] c2\n    [~] c3\n    [ ] c4\n")
                 '(4))))

(ert-deftest perf-cache-seq-tasks-without-tag ()
  "Without a #seq-tasks tag, or above it, no line is blocked."
  (should-not (perf-cache-seq-blocked "[ ] p\n    [ ] c1\n    [ ] c2\n"))
  (should-not (perf-cache-seq-blocked
               "[ ] p\n    [ ] c1\n    [ ] c2\n[ ] q #seq-tasks\n")))

(ert-deftest perf-cache-seq-tasks-grandchildren ()
  "The grandchildren of a #seq-tasks task are not blocked by its children."
  (should (equal (perf-cache-seq-blocked
                  (concat "[ ] p #seq-tasks\n"
                          "    [ ] c1\n"
                          "        [ ] g1\n"
                          "        [ ] g2\n"
                          "    [ ] c2\n"))
                 '(5))))


;;; Text of a task with a blocked dependency

(ert-deftest perf-cache-dep-blocked-text-face ()
  "Only the tasks with a blocked dependency get the blocked text face."
  (altodo-test-with-buffer
      "[ ] a #id:a\n[ ] b #dep:a\n[x] c #id:c\n[ ] d #dep:c\n[ ] e\n"
    (font-lock-mode 1)
    (font-lock-ensure)
    (dolist (case '(("b #dep" t) ("d #dep" nil) ("a #id" nil) ("e" nil)))
      (goto-char (point-min))
      (search-forward (car case))
      (let ((face (get-text-property (match-beginning 0) 'face)))
        (should (eq (and (memq 'altodo-dep-blocked-text-face
                               (if (listp face) face (list face)))
                         t)
                    (cadr case)))))))

(ert-deftest perf-cache-dep-tag-matcher-searches-once ()
  "Without #dep: in the region, the matcher fails after one search.
It used to repeat the failed search 1000 times."
  (altodo-test-with-buffer "[ ] a #id:a\n[ ] b\n[ ] c #tag\n"
    (let ((calls 0))
      (advice-add 're-search-forward :before
                  (lambda (regexp &rest _)
                    (when (string-match-p "#dep:" regexp) (cl-incf calls)))
                  '((name . perf-cache-count)))
      (unwind-protect
          (should-not (altodo--dep-tag-matcher (point-max)))
        (advice-remove 're-search-forward 'perf-cache-count))
      (should (= calls 1)))))

(ert-deftest perf-cache-dep-tag-matcher-sets-status ()
  "The matcher gives the value of the first #dep: tag and its status."
  (altodo-test-with-buffer "[ ] a #id:a\n[ ] b #dep:a\n"
    (should (altodo--dep-tag-matcher (point-max)))
    (should (equal (match-string 0) "a"))
    (should (eq (get-text-property (match-beginning 0) 'altodo-dep-status)
                'blocked))
    (should-not (altodo--dep-tag-matcher (point-max)))))

;;; Matchers with many candidates that are skipped

(ert-deftest perf-cache-tag-matchers-many-skipped-candidates ()
  "Tags and persons after thousands of skipped candidates are still matched.
The matchers gave up after 1000 candidates in one call."
  (altodo-test-with-buffer
      (concat "plain paragraph" (apply #'concat (make-list 1500 " #t @x"))
              "\n[ ] task #real #key:value @bob\n")
    (font-lock-mode 1)
    (font-lock-ensure)
    (dolist (case '(("#real" altodo-tag-face)
                    ("#key" altodo-tag-face)
                    ("value @bob" altodo-tag-value-face)
                    ("@bob" altodo-person-tag-face)))
      (goto-char (point-min))
      (search-forward (car case))
      (let ((face (get-text-property (match-beginning 0) 'face)))
        (should (memq (cadr case) (if (listp face) face (list face))))))))


;;; Fenced block search

(defun perf-cache-fence-lines (text)
  "Return the numbers of the lines of TEXT that are in a fenced block."
  (altodo-test-with-buffer text
    (font-lock-mode 1)
    (font-lock-ensure)
    (let (lines)
      (while (not (eobp))
        (when (altodo--in-fenced-code-block-p)
          (push (line-number-at-pos) lines))
        (forward-line 1))
      (nreverse lines))))

(ert-deftest perf-cache-fence-found ()
  "Lines of fenced blocks and of YAML metadata are found."
  (should (equal (perf-cache-fence-lines "[ ] a\n```\n[ ] b\n```\n[ ] c\n")
                 '(2 3 4)))
  (should (equal (perf-cache-fence-lines "[ ] a\n~~~\n[ ] b\n~~~\n[ ] c\n")
                 '(2 3 4)))
  (should (equal (perf-cache-fence-lines "---\ntitle: x\n---\n[ ] a\n")
                 '(1 2 3))))

(ert-deftest perf-cache-fence-not-searched-without-markers ()
  "Without ```, ~~~ or --- in the buffer, `markdown-mode' is not asked."
  (let ((calls 0))
    (cl-letf* ((original (symbol-function
                          'markdown-get-enclosing-fenced-block-construct))
               ((symbol-function 'markdown-get-enclosing-fenced-block-construct)
                (lambda (&rest args) (cl-incf calls) (apply original args))))
      (altodo-test-with-buffer "[ ] a\n    /// b\n[ ] c `d`\n"
        (setq calls 0)
        (should-not (altodo--in-fenced-code-block-p))
        (should (zerop calls))
        (goto-char (point-max))
        (insert "```\n[ ] in\n```\n")
        (forward-line -2)
        (font-lock-ensure)
        (setq calls 0)
        (should (altodo--in-fenced-code-block-p))
        (should (> calls 0))))))

(ert-deftest perf-cache-fence-marker-follows-text ()
  "The markers are looked for again when the text changes."
  (altodo-test-with-buffer "[ ] a\n```\n[ ] b\n```\n"
    (font-lock-ensure)
    (forward-line 2)
    (should (altodo--in-fenced-code-block-p))
    (goto-char (point-min))
    (re-search-forward "```\n")
    (replace-match "")
    (re-search-forward "```\n")
    (replace-match "")
    (font-lock-ensure)
    (goto-char (point-min))
    (forward-line 1)
    (should-not (altodo--in-fenced-code-block-p))))


;;; Region that was fontified

(ert-deftest perf-cache-fontify-region-returns-bounds ()
  "The function returns the bounds that `jit-lock' needs, and the code block
lines inside them have the faces of `markdown-mode'."
  (altodo-test-with-buffer "[ ] t\n```\nline1 _x_\nline2 _y_\nline3\n```\n[ ] after\n"
    (font-lock-mode 1)
    (font-lock-flush)
    (let ((result (font-lock-fontify-region 16 18)))
      (should (eq (car-safe result) 'jit-lock-bounds))
      (let ((beg (cadr result))
            (end (cddr result)))
        (should (<= beg 16))
        (should (>= end 18))
        (save-excursion
          (goto-char beg)
          (while (< (point) end)
            (when (get-text-property (point) 'markdown-gfm-code)
              (let ((face (get-text-property (point) 'face)))
                (should (memq 'markdown-pre-face
                              (if (listp face) face (list face))))))
            (forward-line 1)))))))

(provide 'perf-cache-test)
;;; perf-cache-test.el ends here
