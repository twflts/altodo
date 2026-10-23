;;; move-after-days-test.el --- Tests for moving done tasks after some days  -*- lexical-binding: t; -*-

;;; Commentary:
;; T20261018-87: with `altodo-move-after-days', the batch and automatic move
;; take only tasks whose `#done' date is old enough.  Today is fixed at
;; 2026-03-10.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defun move-after-days-test--batch (content days &optional unit)
  "Run the batch move on CONTENT with DAYS and UNIT; return the buffer text."
  (altodo-test-with-temp-dir dir
    (let ((file (expand-file-name "t.altodo" dir))
          (altodo-move-after-days days)
          (altodo-move-unit (or unit 'subtree)))
      (with-temp-file file (insert content))
      (let ((buffer (find-file-noselect file)))
        (unwind-protect
            (with-current-buffer buffer
              (altodo-mode)
              (altodo-test-with-today 2026 3 10
                (altodo-move-all-done-tasks))
              (buffer-string))
          (with-current-buffer buffer (set-buffer-modified-p nil))
          (kill-buffer buffer))))))

;;; The age of a `#done' tag

(ert-deftest move-after-days-line-done-tag-value ()
  "The value of the `#done' tag is read from the line."
  (altodo-test-with-buffer "[x] a #done:2026-03-01T10:00:00+09:00 #id:x\n[x] b\n"
    (should (equal (altodo--line-done-tag-value) "2026-03-01T10:00:00+09:00"))
    (forward-line 1)
    (should-not (altodo--line-done-tag-value))))

(ert-deftest move-after-days-days-ago-for-each-format ()
  "ISO 8601, a date only, and Unix time give the days since the date."
  (altodo-test-with-today 2026 3 10
    (altodo-test-with-buffer
        (format "[x] a #done:2026-03-01T10:00:00+09:00\n[x] b #done:2026-03-09\n[x] c #done:%d\n[x] d #done:garbage\n[x] e\n"
                (floor (float-time (encode-time (list 0 0 12 5 3 2026 nil -1 nil)))))
      (should (= (altodo--done-tag-days-ago) 9))
      (forward-line 1)
      (should (= (altodo--done-tag-days-ago) 1))
      (forward-line 1)
      (should (= (altodo--done-tag-days-ago) 5))
      (forward-line 1)
      (should-not (altodo--done-tag-days-ago))
      (forward-line 1)
      (should-not (altodo--done-tag-days-ago)))))

(ert-deftest move-after-days-days-ago-in-custom-date-format ()
  "A `#done' value in `altodo-date-format' is read."
  (altodo-test-with-today 2026 3 10
    (let ((altodo-date-format "%Y/%m/%d"))
      (altodo-test-with-buffer "[x] a #done:2026/03/05\n"
        (should (= (altodo--done-tag-days-ago) 5))))))

;;; The batch move

(ert-deftest move-after-days-nil-moves-at-once ()
  "Without the option, all done tasks move, with or without `#done'."
  (should (equal (move-after-days-test--batch
                  "# H\n[x] a #done:2026-03-09\n[x] b\n[ ] c\n" nil)
                 "# H\n[ ] c\n")))

(ert-deftest move-after-days-moves-only-old-tasks ()
  "Only tasks with a `#done' date of 7 or more days ago move (7 days: yes, 6: no)."
  (should (equal (move-after-days-test--batch
                  (concat "# H\n[x] old #done:2026-03-03\n"
                          "[x] almost #done:2026-03-04\n"
                          "[x] recent #done:2026-03-05\n"
                          "[x] no tag\n[~] bad #done:garbage\n")
                  7)
                 "# H\n[x] almost #done:2026-03-04\n[x] recent #done:2026-03-05\n[x] no tag\n[~] bad #done:garbage\n")))

(ert-deftest move-after-days-zero-moves-today ()
  "With 0 days, a task done today moves, a task without a date does not."
  (should (equal (move-after-days-test--batch
                  "# H\n[x] a #done:2026-03-10\n[x] b\n" 0)
                 "# H\n[x] b\n")))

(ert-deftest move-after-days-subtree-needs-every-task-old ()
  "With the unit `subtree', every task of the subtree must be old enough."
  (should (equal (move-after-days-test--batch
                  (concat "# H\n[x] p1 #done:2026-03-01\n    [x] c1 #done:2026-03-02\n"
                          "[x] p2 #done:2026-03-01\n    [x] c2 #done:2026-03-09\n")
                  7)
                 "# H\n[x] p2 #done:2026-03-01\n    [x] c2 #done:2026-03-09\n")))

(ert-deftest move-after-days-line-unit-checks-only-the-line ()
  "With the unit `line', only the task line itself is checked."
  (should (equal (move-after-days-test--batch
                  "# H\n[x] p #done:2026-03-01\n    [x] c #done:2026-03-09\n"
                  7 'line)
                 "# H\n    [x] c #done:2026-03-09\n")))

(ert-deftest move-after-days-manual-move-ignores-the-option ()
  "The manual move does not check the age."
  (altodo-test-with-temp-dir dir
    (let ((file (expand-file-name "t.altodo" dir))
          (altodo-move-after-days 30))
      (with-temp-file file (insert "# H\n[x] a #done:2026-03-09\n"))
      (let ((buffer (find-file-noselect file)))
        (unwind-protect
            (with-current-buffer buffer
              (altodo-mode)
              (goto-char (point-min))
              (forward-line 1)
              (altodo-test-with-today 2026 3 10
                (altodo-move-done-tasks-at-point))
              (should (equal (buffer-string) "# H\n")))
          (with-current-buffer buffer (set-buffer-modified-p nil))
          (kill-buffer buffer))))))

(provide 'move-after-days-test)
;;; move-after-days-test.el ends here
