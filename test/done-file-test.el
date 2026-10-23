;;; done-file-test.el --- Tests for moving done tasks to the done file  -*- lexical-binding: t; -*-

;;; Commentary:
;; Tests for `altodo-move-done-tasks-at-point', `altodo-move-all-done-tasks',
;; the done file name and the automatic move timer.  Files are created in a
;; temporary directory.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defun done-file-test--read (file)
  "Return the contents of FILE as a string."
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

(defmacro done-file-test--with-file (text &rest body)
  "Visit a new file `todo.altodo' holding TEXT in `altodo-mode' and run BODY.
The variables `dir' and `done-file' are bound to the temporary directory and
the expected done file."
  (declare (indent 1))
  `(altodo-test-with-temp-dir dir
     (let* ((file (expand-file-name "todo.altodo" dir))
            (done-file (expand-file-name "todo_done.altodo" dir)))
       (with-temp-file file (insert ,text))
       (let ((buffer (find-file-noselect file)))
         (unwind-protect
             (with-current-buffer buffer
               (altodo-mode)
               (goto-char (point-min))
               ,@body)
           (with-current-buffer buffer (set-buffer-modified-p nil))
           (kill-buffer buffer))))))

;;; File names

(ert-deftest done-file-test-path ()
  "The done file is next to the source file, with the prefix before the extension."
  (altodo-test-with-temp-dir dir
    (with-temp-buffer
      (setq buffer-file-name (expand-file-name "todo.altodo" dir))
      (should (equal (altodo--get-done-file-path)
                     (expand-file-name "todo_done.altodo" dir)))
      (let ((altodo-done-file-prefix "_archive"))
        (should (equal (altodo--get-done-file-path)
                       (expand-file-name "todo_archive.altodo" dir)))))))

(ert-deftest done-file-test-is-done-file-p ()
  "A buffer is a done file when its base name ends with the prefix."
  (with-temp-buffer
    (setq buffer-file-name "/tmp/todo_done.altodo")
    (should (altodo--is-done-file-p))
    (setq buffer-file-name "/tmp/todo.altodo")
    (should-not (altodo--is-done-file-p))))

;;; Moving one task

(ert-deftest done-file-test-move-at-point ()
  "The done task moves to the done file under its heading, with its comment."
  (done-file-test--with-file
      "# Work\n\n[ ] open task\n[x] finished task\n    its comment\n[ ] next\n"
    (forward-line 3)
    (altodo-move-done-tasks-at-point)
    (should (equal (buffer-string) "# Work\n\n[ ] open task\n[ ] next\n"))
    (should (equal (done-file-test--read done-file)
                   "# Work\n\n[x] finished task\n    its comment\n"))))

(ert-deftest done-file-test-move-cancelled-task ()
  "A cancelled task moves like a done task."
  (done-file-test--with-file "# H\n[~] dropped\n[ ] kept\n"
    (forward-line 1)
    (altodo-move-done-tasks-at-point)
    (should (equal (buffer-string) "# H\n[ ] kept\n"))
    (should (string-match-p "\\[~\\] dropped" (done-file-test--read done-file)))))

(ert-deftest done-file-test-move-appends-under-same-heading ()
  "Tasks from the same heading are collected under one heading."
  (done-file-test--with-file "# H\n[x] one\n[x] two\n"
    (forward-line 1)
    (altodo-move-done-tasks-at-point)
    (altodo-move-done-tasks-at-point)
    (let ((content (done-file-test--read done-file)))
      (should (= (with-temp-buffer
                   (insert content)
                   (how-many "^# H$" (point-min) (point-max)))
                 1))
      (should (string-match-p "\\[x\\] one" content))
      (should (string-match-p "\\[x\\] two" content)))))

(ert-deftest done-file-test-move-rejects-open-task ()
  "An open task is not moved."
  (done-file-test--with-file "[ ] open\n"
    (should-error (altodo-move-done-tasks-at-point) :type 'user-error)
    (should (equal (buffer-string) "[ ] open\n"))
    (should-not (file-exists-p done-file))))

(ert-deftest done-file-test-move-requires-file ()
  "A buffer without a file cannot move tasks."
  (with-temp-buffer
    (insert "[x] done\n")
    (altodo-mode)
    (goto-char (point-min))
    (should-error (altodo-move-done-tasks-at-point) :type 'user-error)
    (should-error (altodo-move-all-done-tasks) :type 'user-error)))

(ert-deftest done-file-test-move-refuses-unfinished-children ()
  "A done task with an open subtask is not moved (unit `subtree')."
  (done-file-test--with-file "# H\n[x] parent\n    [ ] child\n"
    (forward-line 1)
    (should-error (altodo-move-done-tasks-at-point) :type 'user-error)
    (should (equal (buffer-string) "# H\n[x] parent\n    [ ] child\n"))))

(ert-deftest done-file-test-move-line-unit-keeps-children ()
  "With the unit `line', the subtasks stay in the source buffer."
  (let ((altodo-move-unit 'line))
    (done-file-test--with-file "# H\n[x] parent\n    [ ] child\n"
      (forward-line 1)
      (altodo-move-done-tasks-at-point)
      (should (equal (buffer-string) "# H\n    [ ] child\n"))
      (should-not (string-match-p "child" (done-file-test--read done-file))))))

;;; Moving all tasks

(ert-deftest done-file-test-move-all ()
  "All done and cancelled tasks move, grouped by heading."
  (done-file-test--with-file
      "# A\n[x] a1\n[ ] a2\n# B\n[~] b1\n[w] b2\n[x] b3\n"
    (altodo-move-all-done-tasks)
    (should (equal (buffer-string) "# A\n[ ] a2\n# B\n[w] b2\n"))
    (let ((content (done-file-test--read done-file)))
      (should (string-match-p "# A\n+\\[x\\] a1" content))
      (should (string-match-p "# B\n+\\[~\\] b1\n\\[x\\] b3" content)))))

(ert-deftest done-file-test-move-all-saves-when-requested ()
  "The source buffer is saved only when AUTO-SAVE is non-nil."
  (done-file-test--with-file "[x] a\n[ ] b\n"
    (altodo-move-all-done-tasks)
    (should (buffer-modified-p))
    (insert "[x] c\n")
    (altodo-move-all-done-tasks t)
    (should-not (buffer-modified-p))
    (should (equal (done-file-test--read file) "[ ] b\n"))))

;;; Automatic move

(ert-deftest done-file-test-auto-move-all-buffers ()
  "The automatic move handles every altodo buffer, but skips done files."
  (done-file-test--with-file "[x] finished\n"
    (let ((altodo-auto-save-after-move nil))
      (altodo--auto-move-all-buffers)
      (should (equal (buffer-string) ""))
      (should (string-match-p "finished" (done-file-test--read done-file))))))

(ert-deftest done-file-test-auto-move-skips-done-file ()
  "A done file is not processed when `altodo-auto-move-skip-done-files' is set."
  (altodo-test-with-temp-dir dir
    (let* ((file (expand-file-name "todo_done.altodo" dir))
           (buffer (progn (with-temp-file file (insert "[x] kept\n"))
                          (find-file-noselect file))))
      (unwind-protect
          (with-current-buffer buffer
            (altodo-mode)
            (let ((altodo-auto-move-skip-done-files t))
              (altodo--auto-move-all-buffers))
            (should (equal (buffer-string) "[x] kept\n")))
        (with-current-buffer buffer (set-buffer-modified-p nil))
        (kill-buffer buffer)))))

(ert-deftest done-file-test-timer-start-stop-toggle ()
  "The timer starts, stops and toggles."
  (unwind-protect
      (progn
        (altodo-stop-auto-move-timer)
        (should-not altodo--auto-move-timer)
        (altodo-start-auto-move-timer)
        (should (timerp altodo--auto-move-timer))
        (altodo-toggle-auto-move-timer)
        (should-not altodo--auto-move-timer)
        (altodo-toggle-auto-move-timer)
        (should (timerp altodo--auto-move-timer)))
    (altodo-stop-auto-move-timer)))

(provide 'done-file-test)
;;; done-file-test.el ends here
