;;; done-file-abnormal-test.el --- Tests for abnormal cases of moving done tasks  -*- lexical-binding: t; -*-

;;; Commentary:
;; T20261018-36: read-only buffers, unwritable done files, a buffer that
;; visits the done file, and an error in one buffer of the auto-move.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defun done-file-abnormal-test--read-file (file)
  "Return the content of FILE as a string."
  (with-temp-buffer (insert-file-contents file) (buffer-string)))

(defmacro done-file-abnormal-test--with-source (content &rest body)
  "Run BODY in a buffer visiting src.altodo with CONTENT in a temp directory.
`done-file-abnormal-test--dir' is the directory."
  (declare (indent 1))
  `(altodo-test-with-temp-dir done-file-abnormal-test--dir
     (let ((file (expand-file-name "src.altodo" done-file-abnormal-test--dir)))
       (with-temp-file file (insert ,content))
       (let ((buffer (find-file-noselect file)))
         (unwind-protect
             (with-current-buffer buffer
               (altodo-mode)
               (goto-char (point-min))
               (forward-line 1)
               ,@body)
           (with-current-buffer buffer (set-buffer-modified-p nil))
           (kill-buffer buffer))))))

(ert-deftest done-file-abnormal-read-only-does-not-append ()
  "A read-only buffer is refused before anything is appended."
  (done-file-abnormal-test--with-source "# H\n[x] a\n[ ] b\n"
    (setq buffer-read-only t)
    (should-error (altodo-move-done-tasks-at-point) :type 'user-error)
    (should-error (altodo-move-done-tasks-at-point) :type 'user-error)
    (should-not (file-exists-p
                 (expand-file-name "src_done.altodo"
                                   done-file-abnormal-test--dir)))
    (should (equal (buffer-string) "# H\n[x] a\n[ ] b\n"))))

(ert-deftest done-file-abnormal-done-file-is-directory ()
  "A done file path that is a directory gives a clear error."
  (done-file-abnormal-test--with-source "# H\n[x] a\n[ ] b\n"
    (make-directory (expand-file-name "src_done.altodo"
                                      done-file-abnormal-test--dir))
    (let ((err (should-error (altodo-move-done-tasks-at-point)
                             :type 'user-error)))
      (should (string-match-p "Cannot write the done file" (cadr err))))
    (should (equal (buffer-string) "# H\n[x] a\n[ ] b\n"))))

(ert-deftest done-file-abnormal-move-creates-done-file-atomically ()
  "A move writes the done file and leaves no temporary file."
  (done-file-abnormal-test--with-source "# H\n[x] a\n[ ] b\n"
    (altodo-move-done-tasks-at-point)
    (should (string-match-p
             "\\[x\\] a"
             (done-file-abnormal-test--read-file
              (expand-file-name "src_done.altodo"
                                done-file-abnormal-test--dir))))
    (should-not (cl-remove-if-not
                 (lambda (name) (string-prefix-p ".altodo-done-" name))
                 (directory-files done-file-abnormal-test--dir)))
    (should (equal (buffer-string) "# H\n[ ] b\n"))))

(ert-deftest done-file-abnormal-failed-write-keeps-done-file ()
  "If the write fails, the done file keeps its content."
  (done-file-abnormal-test--with-source "# H\n[x] a\n[ ] b\n"
    (let ((done (expand-file-name "src_done.altodo"
                                  done-file-abnormal-test--dir)))
      (with-temp-file done (insert "# H\n\n[x] old\n"))
      (cl-letf (((symbol-function 'rename-file)
                 (lambda (&rest _) (error "Disk full"))))
        (should-error (altodo-move-done-tasks-at-point)))
      (should (equal (done-file-abnormal-test--read-file done)
                     "# H\n\n[x] old\n"))
      (should (equal (buffer-string) "# H\n[x] a\n[ ] b\n"))
      (should-not (cl-remove-if-not
                   (lambda (name) (string-prefix-p ".altodo-done-" name))
                   (directory-files done-file-abnormal-test--dir))))))

(ert-deftest done-file-abnormal-appends-to-visiting-buffer ()
  "A buffer that visits the done file receives the entry; it is saved if clean."
  (done-file-abnormal-test--with-source "# H\n[x] a\n[ ] b\n"
    (let* ((done (expand-file-name "src_done.altodo"
                                   done-file-abnormal-test--dir))
           (done-buffer (progn (with-temp-file done (insert "# H\n\n[x] old\n"))
                               (find-file-noselect done))))
      (unwind-protect
          (progn
            (altodo-move-done-tasks-at-point)
            (with-current-buffer done-buffer
              (should (string-match-p "\\[x\\] a" (buffer-string)))
              (should-not (buffer-modified-p)))
            (should (string-match-p "\\[x\\] a"
                                    (done-file-abnormal-test--read-file done))))
        (kill-buffer done-buffer)))))

(ert-deftest done-file-abnormal-visiting-buffer-with-unsaved-changes ()
  "Unsaved changes in the done buffer are not saved by the move."
  (done-file-abnormal-test--with-source "# H\n[x] a\n[ ] b\n"
    (let* ((done (expand-file-name "src_done.altodo"
                                   done-file-abnormal-test--dir))
           (done-buffer (progn (with-temp-file done (insert "# H\n\n[x] old\n"))
                               (find-file-noselect done))))
      (unwind-protect
          (progn
            (with-current-buffer done-buffer
              (goto-char (point-max)) (insert "unsaved\n"))
            (altodo-move-done-tasks-at-point)
            (with-current-buffer done-buffer
              (should (buffer-modified-p))
              (should (string-match-p "unsaved" (buffer-string)))
              (should (string-match-p "\\[x\\] a" (buffer-string))))
            (should-not (string-match-p
                         "unsaved" (done-file-abnormal-test--read-file done)))
            (should-not (string-match-p
                         "\\[x\\] a" (done-file-abnormal-test--read-file done))))
        (with-current-buffer done-buffer (set-buffer-modified-p nil))
        (kill-buffer done-buffer)))))

(ert-deftest done-file-abnormal-auto-move-continues-after-error ()
  "An error in one buffer does not stop the auto-move of the others."
  (altodo-test-with-temp-dir dir
    (let* ((file-a (expand-file-name "a.altodo" dir))
           (file-b (expand-file-name "b.altodo" dir))
           buffer-a buffer-b)
      (with-temp-file file-a (insert "# H\n[x] a\n"))
      (with-temp-file file-b (insert "# H\n[x] b\n"))
      (setq buffer-a (find-file-noselect file-a)
            buffer-b (find-file-noselect file-b))
      (unwind-protect
          (progn
            (with-current-buffer buffer-a (altodo-mode) (setq buffer-read-only t))
            (with-current-buffer buffer-b (altodo-mode))
            (let ((altodo-auto-save-after-move t))
              (altodo--auto-move-all-buffers))
            (should (equal (with-current-buffer buffer-a (buffer-string))
                           "# H\n[x] a\n"))
            (should (equal (with-current-buffer buffer-b (buffer-string))
                           "# H\n"))
            (should-not (file-exists-p (expand-file-name "a_done.altodo" dir)))
            (should (file-exists-p (expand-file-name "b_done.altodo" dir))))
        (dolist (buffer (list buffer-a buffer-b))
          (with-current-buffer buffer (set-buffer-modified-p nil))
          (kill-buffer buffer))))))

(provide 'done-file-abnormal-test)
;;; done-file-abnormal-test.el ends here
