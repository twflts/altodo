;;; altodo-test-helper.el --- Shared helpers for the altodo tests  -*- lexical-binding: t; -*-

;;; Commentary:

;; Load this file from a test with:
;;   (add-to-list 'load-path
;;                (file-name-directory (or load-file-name buffer-file-name)))
;;   (require 'altodo-test-helper)
;;
;; It provides the project paths, temporary buffers and directories, a copy
;; of the sample `.altodo-locals.el', and a fixed "today" for date tests.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'altodo)

(defconst altodo-test-root
  (expand-file-name
   ".." (file-name-directory (or load-file-name buffer-file-name)))
  "Root directory of the altodo project.")

(defun altodo-test-file (relative-path)
  "Return the absolute path of RELATIVE-PATH under the project root."
  (expand-file-name relative-path altodo-test-root))

(defmacro altodo-test-with-buffer (text &rest body)
  "Run BODY in a temporary `altodo-mode' buffer containing TEXT.
Point is at the beginning of the buffer."
  (declare (indent 1))
  `(with-temp-buffer
     (insert ,text)
     (altodo-mode)
     (goto-char (point-min))
     ,@body))

(defmacro altodo-test-with-temp-dir (var &rest body)
  "Run BODY with VAR bound to a new temporary directory, deleted afterward."
  (declare (indent 1))
  `(let ((,var (make-temp-file "altodo-test-" t)))
     (unwind-protect
         (progn ,@body)
       (delete-directory ,var t))))

(defmacro altodo-test-with-locals (&rest body)
  "Run BODY in a buffer visiting a file next to a copy of the sample locals.
The sample is `testfiles/.altodo-locals.el_'.  It is copied to a temporary
directory as `.altodo-locals.el', so the project directory is not touched."
  (declare (indent 0))
  `(altodo-test-with-temp-dir altodo-test--dir
     (copy-file (altodo-test-file "testfiles/.altodo-locals.el_")
                (expand-file-name ".altodo-locals.el" altodo-test--dir))
     (with-temp-buffer
       (setq buffer-file-name (expand-file-name "test.altodo" altodo-test--dir))
       ,@body)))

(defmacro altodo-test-with-today (year month day &rest body)
  "Run BODY as if the current time were YEAR-MONTH-DAY at noon."
  (declare (indent 3))
  `(cl-letf (((symbol-function 'current-time)
              (lambda ()
                (encode-time (list 0 0 12 ,day ,month ,year nil nil nil)))))
     ,@body))

(defun altodo-test-date-offset (offset)
  "Return today's date plus OFFSET days as a YYYY-MM-DD string."
  (format-time-string "%Y-%m-%d"
                      (time-add (current-time) (* offset 24 60 60))))

(provide 'altodo-test-helper)
;;; altodo-test-helper.el ends here
