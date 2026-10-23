;;; move-subtree-test.el --- Tests for moving done tasks with their subtasks  -*- lexical-binding: t; -*-

;;; Commentary:
;; B06 (T20261018-11): done tasks move to the done file with their subtasks.
;; `altodo-move-unit' `line' and `altodo-move-done-task-alone' keep the older
;; behavior: only the task line moves, and the subtasks stay.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defun move-subtree-test--run (content line action)
  "Visit a file with CONTENT, go to LINE, call ACTION and return the result.
The result is a list of the buffer text and the done file text (nil if the
done file was not created), followed by the value of ACTION."
  (altodo-test-with-temp-dir dir
    (let ((file (expand-file-name "t.altodo" dir))
          (done (expand-file-name "t_done.altodo" dir)))
      (with-temp-file file (insert content))
      (let ((buffer (find-file-noselect file)))
        (unwind-protect
            (with-current-buffer buffer
              (altodo-mode)
              (goto-char (point-min))
              (forward-line (1- line))
              (let ((value (funcall action)))
                (list (buffer-string)
                      (and (file-exists-p done)
                           (with-temp-buffer (insert-file-contents done)
                                             (buffer-string)))
                      value)))
          (with-current-buffer buffer (set-buffer-modified-p nil))
          (kill-buffer buffer))))))

;;; Helpers

(ert-deftest move-subtree-end-of-subtree ()
  "The subtree ends before the next line that is not indented deeper."
  (altodo-test-with-buffer "[x] a\n    n\n    [ ] b\n        c\n[ ] d\n"
    (should (= (altodo--task-subtree-end)
               (save-excursion (goto-char (point-min)) (forward-line 4) (point))))
    (forward-line 2)
    (should (= (altodo--task-subtree-end)
               (save-excursion (goto-char (point-min)) (forward-line 4) (point))))))

(ert-deftest move-subtree-end-includes-blank-line-before-deeper-task ()
  "A blank line belongs to the subtree only if a deeper task follows."
  (altodo-test-with-buffer "[x] a\n    [x] b\n\n    [x] c\n\n[ ] d\n"
    (should (= (altodo--task-subtree-end)
               (save-excursion (goto-char (point-min)) (forward-line 4) (point))))))

(ert-deftest move-subtree-end-stops-at-heading ()
  "A heading ends the subtree."
  (altodo-test-with-buffer "[x] a\n    [x] b\n# H\n    text\n"
    (should (= (altodo--task-subtree-end)
               (save-excursion (goto-char (point-min)) (forward-line 2) (point))))))

(ert-deftest move-subtree-has-parent ()
  "A task has a parent if the nearest shallower line is a task."
  (altodo-test-with-buffer "[ ] a\n    [x] b\n        [x] c\n[x] d\n"
    (should-not (altodo--task-has-parent-p))
    (forward-line 1)
    (should (altodo--task-has-parent-p))
    (forward-line 1)
    (should (altodo--task-has-parent-p))
    (forward-line 1)
    (should-not (altodo--task-has-parent-p))))

;;; Moving by subtree

(ert-deftest move-subtree-moves-done-parent-with-done-children ()
  "A done parent moves with its done subtasks, comments and notes."
  (let ((result (move-subtree-test--run
                 "# H\n[x] a\n    note\n    [x] b\n        /// n\n    [~] c\n[ ] d\n"
                 2 #'altodo-move-done-tasks-at-point)))
    (should (equal (nth 0 result) "# H\n[ ] d\n"))
    (should (equal (nth 1 result)
                   "# H\n\n[x] a\n    note\n    [x] b\n        /// n\n    [~] c\n"))
    (should-not (nth 2 result))))

(ert-deftest move-subtree-refuses-unfinished-subtask ()
  "A done parent with an open subtask is not moved by hand."
  (let ((err nil))
    (let ((result (move-subtree-test--run
                   "# H\n[x] a\n    [ ] b\n"
                   2 (lambda ()
                       (setq err (should-error (altodo-move-done-tasks-at-point)
                                               :type 'user-error))))))
      (should (equal (nth 0 result) "# H\n[x] a\n    [ ] b\n"))
      (should-not (nth 1 result))
      (should (string-match-p "subtasks that are not done" (cadr err))))))

(ert-deftest move-subtree-hand-move-of-child-of-open-parent ()
  "By hand, a done subtask of an open parent moves with its indent removed."
  (let ((result (move-subtree-test--run
                 "# H\n[ ] p\n    [x] a\n        c\n        [x] b\n    [ ] q\n"
                 3 #'altodo-move-done-tasks-at-point)))
    (should (equal (nth 0 result) "# H\n[ ] p\n    [ ] q\n"))
    (should (equal (nth 1 result) "# H\n\n[x] a\n    c\n    [x] b\n"))))

(ert-deftest move-subtree-batch-skips-subtask-of-open-parent ()
  "The batch move leaves a done subtask under an open parent."
  (let ((result (move-subtree-test--run
                 "# H\n[ ] p\n    [x] a\n[x] b\n"
                 1 #'altodo-move-all-done-tasks)))
    (should (equal (nth 0 result) "# H\n[ ] p\n    [x] a\n"))
    (should (equal (nth 1 result) "# H\n\n[x] b\n"))))

(ert-deftest move-subtree-batch-skips-parent-with-open-subtask ()
  "The batch move leaves a done parent with an open subtask, and moves others."
  (let ((result (move-subtree-test--run
                 "# H\n[x] a\n[x] b\n    [ ] open\n[x] c\n"
                 1 #'altodo-move-all-done-tasks)))
    (should (equal (nth 0 result) "# H\n[x] b\n    [ ] open\n"))
    (should (equal (nth 1 result) "# H\n\n[x] a\n[x] c\n"))))

(ert-deftest move-subtree-batch-moves-nested-done-tree-once ()
  "The batch move moves a fully done tree as one subtree, with blank lines."
  (let ((result (move-subtree-test--run
                 "# H\n[x] a\n    [x] b\n\n    [x] c\n[ ] d\n"
                 1 #'altodo-move-all-done-tasks)))
    (should (equal (nth 0 result) "# H\n[ ] d\n"))
    (should (equal (nth 1 result) "# H\n\n[x] a\n    [x] b\n\n    [x] c\n"))))

(ert-deftest move-subtree-message-counts-tasks ()
  "The batch move reports the number of tasks, not of subtrees."
  (let ((messages nil))
    (cl-letf (((symbol-function 'message)
               (lambda (format &rest args)
                 (push (apply #'format format args) messages))))
      (move-subtree-test--run "# H\n[x] a\n    [x] b\n[x] c\n"
                              1 #'altodo-move-all-done-tasks))
    (should (member "Moved 3 task(s) to done file" messages))))

;;; Moving by line

(ert-deftest move-subtree-line-unit-keeps-subtasks ()
  "With `line', only the task line and its comments move."
  (let* ((altodo-move-unit 'line)
         (result (move-subtree-test--run
                  "# H\n[x] a\n    note\n    [ ] child\n"
                  2 #'altodo-move-done-tasks-at-point)))
    (should (equal (nth 0 result) "# H\n    [ ] child\n"))
    (should (equal (nth 1 result) "# H\n\n[x] a\n    note\n"))))

(ert-deftest move-subtree-line-unit-batch-moves-done-subtask ()
  "With `line', the batch move takes a done subtask away from an open parent."
  (let* ((altodo-move-unit 'line)
         (result (move-subtree-test--run
                  "# H\n[ ] p\n    [x] a\n    [ ] q\n"
                  1 #'altodo-move-all-done-tasks)))
    (should (equal (nth 0 result) "# H\n[ ] p\n    [ ] q\n"))
    (should (equal (nth 1 result) "# H\n\n    [x] a\n"))))

(ert-deftest move-subtree-alone-command-ignores-the-unit ()
  "`altodo-move-done-task-alone' moves one task even if the unit is `subtree'."
  (let* ((altodo-move-unit 'subtree)
         (result (move-subtree-test--run
                  "# H\n[x] a\n    [ ] child\n"
                  2 #'altodo-move-done-task-alone)))
    (should (equal (nth 0 result) "# H\n    [ ] child\n"))
    (should (equal (nth 1 result) "# H\n\n[x] a\n"))))

(ert-deftest move-subtree-default-unit-is-subtree ()
  "The default unit is the subtree."
  (should (eq (default-value 'altodo-move-unit) 'subtree)))

;;; Abnormal cases

(ert-deftest move-subtree-read-only-buffer-moves-nothing ()
  "A read-only buffer is refused before anything is appended."
  (let ((result (move-subtree-test--run
                 "# H\n[x] a\n    [x] b\n"
                 2 (lambda ()
                     (setq buffer-read-only t)
                     (should-error (altodo-move-done-tasks-at-point)
                                   :type 'user-error)))))
    (should (equal (nth 0 result) "# H\n[x] a\n    [x] b\n"))
    (should-not (nth 1 result))))

(provide 'move-subtree-test)
;;; move-subtree-test.el ends here
