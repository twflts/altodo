;;; command-behavior-test.el --- Tests for the editing commands  -*- lexical-binding: t; -*-

;;; Commentary:
;; The result of each command is checked on the buffer text.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defmacro command-behavior-test--result (text &rest body)
  "Run BODY in an `altodo-mode' buffer holding TEXT; return the buffer text.
The `indent-tabs-mode' default is left as it is, to show that
`altodo-mode' does not insert tabs."
  (declare (indent 1))
  `(altodo-test-with-buffer ,text
     ,@body
     (buffer-substring-no-properties (point-min) (point-max))))

;;; Task state

(ert-deftest command-behavior-test-set-done-adds-done-tag ()
  "Setting done adds a #done tag with an ISO 8601 time."
  (should (string-match-p
           "\\`\\[x\\] a #done:[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}T[0-9:]+[+-][0-9:]+\n\\'"
           (command-behavior-test--result "[ ] a\n" (altodo-set-task-done)))))

(ert-deftest command-behavior-test-set-open-removes-done-tag ()
  "Reopening a task removes its #done tag."
  (should (equal (command-behavior-test--result
                     "[x] a #done:2026-01-01T00:00:00+09:00\n"
                   (altodo-set-task-open))
                 "[ ] a\n")))

(ert-deftest command-behavior-test-done-tag-not-duplicated ()
  "Setting a done task to done again keeps one #done tag."
  (let ((text (command-behavior-test--result "[x] a #done:2026-01-01\n"
                (altodo-set-task-done))))
    (should (= (length (split-string text "#done:")) 2))))

(ert-deftest command-behavior-test-set-progress-waiting-have-no-done-tag ()
  "In-progress and waiting tasks get no #done tag."
  (should (equal (command-behavior-test--result "[ ] a\n"
                   (altodo-set-task-progress))
                 "[@] a\n"))
  (should (equal (command-behavior-test--result "[ ] a\n"
                   (altodo-set-task-waiting))
                 "[w] a\n")))

(ert-deftest command-behavior-test-cancelled-adds-done-tag ()
  "Cancelling a task adds a #done tag."
  (should (string-match-p
           "\\`\\[~\\] a #done:"
           (command-behavior-test--result "[ ] a\n"
             (altodo-set-task-cancelled)))))

(ert-deftest command-behavior-test-toggle-state ()
  "The toggle switches open and done; any other state becomes done."
  (should (string-match-p
           "\\`\\[x\\] a #done:"
           (command-behavior-test--result "[ ] a\n" (altodo-toggle-task-state))))
  (should (equal (command-behavior-test--result "[x] a #done:2026-01-01\n"
                   (altodo-toggle-task-state))
                 "[ ] a\n"))
  (should (string-match-p
           "\\`\\[x\\] a #done:"
           (command-behavior-test--result "[@] a\n" (altodo-toggle-task-state)))))

(ert-deftest command-behavior-test-state-commands-ignore-other-lines ()
  "State commands do nothing on a line that is not a task."
  (should (equal (command-behavior-test--result "text\n"
                   (altodo-set-task-done))
                 "text\n")))

;;; Flags

(ert-deftest command-behavior-test-priority-levels ()
  "Priority 1, 2 and 3 set one to three exclamation marks."
  (should (equal (command-behavior-test--result "[ ] a\n" (altodo-set-priority-1))
                 "[ ] ! a\n"))
  (should (equal (command-behavior-test--result "[ ] a\n" (altodo-set-priority-2))
                 "[ ] !! a\n"))
  (should (equal (command-behavior-test--result "[ ] a\n" (altodo-set-priority-3))
                 "[ ] !!! a\n")))

(ert-deftest command-behavior-test-priority-replaces-priority ()
  "A new priority replaces the existing one."
  (should (equal (command-behavior-test--result "[ ] ! a\n"
                   (altodo-set-priority-2))
                 "[ ] !! a\n"))
  (should (equal (command-behavior-test--result "[ ] !!! a\n"
                   (altodo-set-priority-1))
                 "[ ] ! a\n")))

(ert-deftest command-behavior-test-priority-on-comment ()
  "A single-line comment can have a priority flag."
  (should (equal (command-behavior-test--result "/// note\n"
                   (altodo-set-priority-2))
                 "/// !! note\n")))

(ert-deftest command-behavior-test-star-toggle ()
  "The star flag is added and removed."
  (should (equal (command-behavior-test--result "[ ] a\n"
                   (altodo-toggle-star-flag))
                 "[ ] + a\n"))
  (should (equal (command-behavior-test--result "[ ] + a\n"
                   (altodo-toggle-star-flag))
                 "[ ] a\n")))

;;; Indentation

(ert-deftest command-behavior-test-indent-increase-decrease ()
  "The indentation changes by `altodo-indent-size' spaces."
  (should (equal (command-behavior-test--result "[ ] a\n"
                   (altodo-indent-increase))
                 "    [ ] a\n"))
  (should (equal (command-behavior-test--result "    [ ] a\n"
                   (altodo-indent-decrease))
                 "[ ] a\n"))
  (let ((altodo-indent-size 2))
    (should (equal (command-behavior-test--result "[ ] a\n"
                     (altodo-indent-increase))
                   "  [ ] a\n"))))

(ert-deftest command-behavior-test-indent-decrease-at-zero ()
  "Decreasing the indentation of a top-level task changes nothing."
  (should (equal (command-behavior-test--result "[ ] a\n"
                   (altodo-indent-decrease))
                 "[ ] a\n")))

(ert-deftest command-behavior-test-indent-region ()
  "The indentation of every line in the region changes."
  (let ((transient-mark-mode t))
    (should (equal (command-behavior-test--result "[ ] a\n[ ] b\n"
                     (set-mark (point-max))
                     (activate-mark)
                     (altodo-indent-increase))
                   "    [ ] a\n    [ ] b\n"))))

;;; Adding lines

(ert-deftest command-behavior-test-add-task ()
  "Adding a task puts an empty task on the next line at the same level."
  (should (equal (command-behavior-test--result "    [ ] a\n"
                   (end-of-line)
                   (altodo-add-task))
                 "    [ ] a\n    [ ] \n")))

(ert-deftest command-behavior-test-add-subtask-uses-spaces ()
  "A subtask is indented by spaces, never by a tab."
  (let ((indent-tabs-mode t)
        (text (command-behavior-test--result "[ ] a\n"
                (end-of-line)
                (altodo-add-subtask))))
    (should (equal text "[ ] a\n    [ ] \n"))
    (should-not (string-match-p "\t" text))))

(ert-deftest command-behavior-test-multiline-comment-uses-spaces ()
  "A multi-line comment is indented by spaces, never by a tab."
  (let ((indent-tabs-mode t)
        (text (command-behavior-test--result "[ ] a\n"
                (altodo-start-multiline-comment))))
    (should (string-match-p "\\`\\[ \\] a\n    \n?\\'" text))
    (should-not (string-match-p "\t" text))))

(ert-deftest command-behavior-test-enter-after-task ()
  "RET at the end of a task starts a new task."
  (should (equal (command-behavior-test--result "[ ] a"
                   (end-of-line)
                   (altodo-enter))
                 "[ ] a\n[ ] ")))

(ert-deftest command-behavior-test-enter-in-plain-text ()
  "RET in plain Markdown text is an ordinary newline."
  (should (equal (command-behavior-test--result "text"
                   (end-of-line)
                   (altodo-enter))
                 "text\n")))

;;; Other commands

(ert-deftest command-behavior-test-insert-id ()
  "Inserting an ID adds an #id tag at the end of the line."
  (let ((altodo-insert-id-format 'tiny))
    (should (string-match-p
             "\\`\\[ \\] a #id:[0-9A-Za-z]\\{10\\}\n\\'"
             (command-behavior-test--result "[ ] a\n" (altodo-insert-id))))))

(ert-deftest command-behavior-test-insert-id-formats ()
  "Each ID format has its documented length.
The random-first formats drop leading zeros, so their length varies
(at most 16 and 10 characters)."
  (dolist (case '((uuid 36 36) (base62 21 21) (short 15 15)
                  (short-random 14 16) (tiny 10 10) (tiny-random 8 10)))
    (let ((altodo-insert-id-format (car case)))
      (dotimes (_ 20)
        (let ((length (length (altodo--generate-id))))
          (should (<= (nth 1 case) length (nth 2 case))))))))

(ert-deftest command-behavior-test-toggle-comment ()
  "Toggling converts between a task and a single-line comment."
  (should (equal (command-behavior-test--result "[ ] a\n"
                   (altodo-toggle-comment))
                 "/// a\n"))
  (should (equal (command-behavior-test--result "    [x] a b\n"
                   (altodo-toggle-comment))
                 "    /// a b\n"))
  (should (equal (command-behavior-test--result "/// a\n"
                   (altodo-toggle-comment))
                 "[ ] a\n")))

(provide 'command-behavior-test)
;;; command-behavior-test.el ends here
