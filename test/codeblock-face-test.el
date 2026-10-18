;;; codeblock-face-test.el --- Tests for code block face handling

;;; Commentary:
;; Tests for altodo-mode's code block face handling.
;; Ensures that markdown faces are applied inside code blocks,
;; and altodo faces are applied outside code blocks.

;;; Code:

(require 'ert)
(require 'altodo)

(defun codeblock-face-test--get-face-at (content line col)
  "Get face at LINE COL in CONTENT."
  (with-temp-buffer
    (insert content)
    (altodo-mode)
    (font-lock-ensure)
    (goto-line line)
    (move-to-column col)
    (get-text-property (point) 'face)))

(defun codeblock-face-test--has-face-p (content line col face)
  "Check if FACE is applied at LINE COL in CONTENT."
  (let ((actual-face (codeblock-face-test--get-face-at content line col)))
    (cond
     ((listp actual-face)
      (memq face actual-face))
     ((symbolp actual-face)
      (eq actual-face face))
     (t nil))))

;;; Tests

(ert-deftest codeblock-face-test-task-outside-codeblock ()
  "Task outside code block should have altodo face."
  (should (codeblock-face-test--has-face-p "[ ] Task line\n" 1 1 'altodo-task-open-face)))

(ert-deftest codeblock-face-test-task-inside-codeblock ()
  "Task inside code block should have markdown face, not altodo face."
  (should (codeblock-face-test--has-face-p "```\n[ ] Task line\n```\n" 2 1 'markdown-pre-face)))

(ert-deftest codeblock-face-test-comment-outside-codeblock ()
  "Comment outside code block should have altodo face."
  (should (codeblock-face-test--has-face-p "/// Comment\n" 1 1 'altodo-comment-face)))

(ert-deftest codeblock-face-test-comment-inside-codeblock ()
  "Comment inside code block should have markdown face."
  (should (codeblock-face-test--has-face-p "```\n/// Comment\n```\n" 2 1 'markdown-pre-face)))

(ert-deftest codeblock-face-test-multiline-comment-outside-codeblock ()
  "Multiline comment outside code block should have altodo face."
  (should (codeblock-face-test--has-face-p "[ ] Task\n    Multiline comment\n" 2 5 'altodo-multiline-comment-face)))

(ert-deftest codeblock-face-test-multiline-comment-inside-codeblock ()
  "Multiline comment inside code block should have markdown face."
  (should (codeblock-face-test--has-face-p "```\n[ ] Task\n    Multiline comment\n```\n" 3 5 'markdown-pre-face)))

(ert-deftest codeblock-face-test-mixed-content ()
  "Mixed content with code blocks and tasks."
  (let ((content "[ ] Task 1\n\n```\n[ ] Task in code\n```\n\n[ ] Task 2\n"))
    (should (codeblock-face-test--has-face-p content 1 1 'altodo-task-open-face))
    (should (codeblock-face-test--has-face-p content 4 1 'markdown-pre-face))
    (should (codeblock-face-test--has-face-p content 7 1 'altodo-task-open-face))))

(ert-deftest codeblock-face-test-tilde-fenced-codeblock ()
  "Tilde-fenced code blocks should also apply markdown faces."
  (should (codeblock-face-test--has-face-p "~~~\n[ ] Task in tilde fence\n~~~\n" 2 1 'markdown-pre-face)))

(ert-deftest codeblock-face-test-indented-codeblock ()
  "Indented code blocks (4+ spaces) are treated as altodo multiline comments.
font-lock-remove-keywords excludes markdown-match-pre-blocks, and
altodo--restore-code-block-faces only targets fenced code blocks."
  (should-not (codeblock-face-test--has-face-p "    [ ] Task in indented code\n" 1 5 'markdown-pre-face)))

(ert-deftest codeblock-face-test-nested-tasks-outside-codeblock ()
  "Nested tasks outside code block should have altodo faces."
  (let ((content "[ ] Parent\n    [ ] Child\n"))
    (should (codeblock-face-test--has-face-p content 1 1 'altodo-task-open-face))
    (should (codeblock-face-test--has-face-p content 2 5 'altodo-task-open-face))))

(ert-deftest codeblock-face-test-nested-tasks-inside-codeblock ()
  "Nested tasks inside code block should have markdown faces."
  (let ((content "```\n[ ] Parent\n    [ ] Child\n```\n"))
    (should (codeblock-face-test--has-face-p content 2 1 'markdown-pre-face))
    (should (codeblock-face-test--has-face-p content 3 5 'markdown-pre-face))))

(ert-deftest codeblock-face-test-tag-outside-codeblock ()
  "Tags outside code block should have altodo face."
  (should (codeblock-face-test--has-face-p "[ ] Task #tag\n" 1 10 'altodo-tag-face)))

(ert-deftest codeblock-face-test-tag-inside-codeblock ()
  "Tags inside code block should have markdown face."
  (should (codeblock-face-test--has-face-p "```\n[ ] Task #tag\n```\n" 2 10 'markdown-pre-face)))

(ert-deftest codeblock-face-test-priority-outside-codeblock ()
  "Priority markers outside code block should have altodo face."
  (should (codeblock-face-test--has-face-p "[ ] ! Task\n" 1 6 'altodo-flag-priority1-text-face)))

(ert-deftest codeblock-face-test-priority-inside-codeblock ()
  "Priority markers inside code block should have markdown face."
  (should (codeblock-face-test--has-face-p "```\n[ ] ! Task\n```\n" 2 6 'markdown-pre-face)))

(ert-deftest codeblock-face-test-date-outside-codeblock ()
  "Dates outside code block should have altodo face."
  (should (codeblock-face-test--has-face-p "[ ] Task 2025-12-31\n" 1 10 'altodo-task-open-text-face)))

(ert-deftest codeblock-face-test-date-inside-codeblock ()
  "Dates inside code block should have markdown face."
  (should (codeblock-face-test--has-face-p "```\n[ ] Task 2025-12-31\n```\n" 2 10 'markdown-pre-face)))

(ert-deftest codeblock-face-test-complex-scenario ()
  "Complex scenario with multiple code blocks and tasks."
  (let ((content "# Heading\n\n[ ] Task 1 #tag\n    Multiline comment\n\n```\n[ ] Task in code #tag\n    Indented in code\n```\n\n[ ] Task 2 ! 2025-12-31\n    Another comment\n"))
    ;; Task 1 outside code block (line 3)
    (should (codeblock-face-test--has-face-p content 3 1 'altodo-task-open-face))
    ;; Multiline comment outside code block (line 4)
    (should (codeblock-face-test--has-face-p content 4 5 'altodo-multiline-comment-face))
    ;; Task in code block (line 7)
    (should (codeblock-face-test--has-face-p content 7 1 'markdown-pre-face))
    ;; Indented in code block (line 8)
    (should (codeblock-face-test--has-face-p content 8 5 'markdown-pre-face))
    ;; Task 2 outside code block (line 11)
    (should (codeblock-face-test--has-face-p content 11 1 'altodo-task-open-face))
    ;; Another comment outside code block (line 12)
    (should (codeblock-face-test--has-face-p content 12 5 'altodo-multiline-comment-face))))

(ert-deftest codeblock-face-test-gfm-quoted-codeblock ()
  "GFM quoted code blocks should apply markdown faces."
  (should (codeblock-face-test--has-face-p "```python\n[ ] Task in python code\n```\n" 2 1 'markdown-pre-face)))

(ert-deftest codeblock-face-test-empty-codeblock ()
  "Empty code blocks should not affect surrounding tasks."
  (let ((content "[ ] Task 1\n\n```\n```\n\n[ ] Task 2\n"))
    (should (codeblock-face-test--has-face-p content 1 1 'altodo-task-open-face))
    (should (codeblock-face-test--has-face-p content 6 1 'altodo-task-open-face))))

(ert-deftest codeblock-face-test-unclosed-codeblock ()
  "Unclosed code blocks are not recognized by markdown-mode.
This test documents the current behavior."
  ;; markdown-mode does not recognize unclosed code blocks
  ;; so altodo faces are applied instead
  (should (codeblock-face-test--has-face-p "```\n[ ] Task in unclosed code\n" 2 1 'altodo-task-open-face)))

(ert-deftest codeblock-face-test-state-change-outside-codeblock ()
  "State markers outside code block should have correct face."
  (let ((content "[@] In progress\n[x] Done\n[w] Waiting\n[~] Cancelled\n"))
    (should (codeblock-face-test--has-face-p content 1 1 'altodo--task-progress-face))
    (should (codeblock-face-test--has-face-p content 2 1 'altodo-task-done-face))
    (should (codeblock-face-test--has-face-p content 3 1 'altodo-task-waiting-face))
    (should (codeblock-face-test--has-face-p content 4 1 'altodo-task-cancelled-face))))

(ert-deftest codeblock-face-test-state-change-inside-codeblock ()
  "State markers inside code block should have markdown face."
  (let ((content "```\n[@] In progress\n[x] Done\n[w] Waiting\n[~] Cancelled\n```\n"))
    (should (codeblock-face-test--has-face-p content 2 1 'markdown-pre-face))
    (should (codeblock-face-test--has-face-p content 3 1 'markdown-pre-face))
    (should (codeblock-face-test--has-face-p content 4 1 'markdown-pre-face))
    (should (codeblock-face-test--has-face-p content 5 1 'markdown-pre-face))))

(ert-deftest codeblock-face-test-multiline-comment-with-empty-line ()
  "Multiline comment with empty line should have altodo face.
This is a regression test for the bug where empty lines in multiline comments
were incorrectly treated as code blocks."
  (let ((content "[@] + ステークホルダーからの要件収集 @田中 @佐藤\n    要件収集は進行中です。\n    来週ミーティングを予定しています。\n    \n    チームでスコープを確認する必要があります。\n"))
    ;; Line 2: multiline comment
    (should (codeblock-face-test--has-face-p content 2 5 'altodo-multiline-comment-face))
    ;; Line 3: multiline comment
    (should (codeblock-face-test--has-face-p content 3 5 'altodo-multiline-comment-face))
    ;; Line 4: empty line (no face)
    (should-not (codeblock-face-test--has-face-p content 4 5 'markdown-pre-face))
    ;; Line 5: multiline comment (after empty line)
    (should (codeblock-face-test--has-face-p content 5 5 'altodo-multiline-comment-face))))

(ert-deftest codeblock-face-test-multiline-comment-with-empty-line-in-fenced-code ()
  "Multiline comment-like content inside fenced code block should have markdown face.
This tests that fenced code blocks are correctly identified even with empty lines."
  (let ((content "```\n[@] Task\n    Indented\n    \n    More indented\n```\n"))
    ;; Line 2: inside fenced code block
    (should (codeblock-face-test--has-face-p content 2 1 'markdown-pre-face))
    ;; Line 3: inside fenced code block
    (should (codeblock-face-test--has-face-p content 3 5 'markdown-pre-face))
    ;; Line 4: empty line inside fenced code block
    (should (codeblock-face-test--has-face-p content 4 5 'markdown-pre-face))
    ;; Line 5: inside fenced code block
    (should (codeblock-face-test--has-face-p content 5 5 'markdown-pre-face))))

(provide 'codeblock-face-test)
;;; codeblock-face-test.el ends here
