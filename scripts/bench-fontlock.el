;;; bench-fontlock.el --- Benchmark of the altodo fontification  -*- lexical-binding: t; -*-

;;; Commentary:

;; Measure the time to fontify a whole buffer in `altodo-mode'.  The time
;; must grow in proportion to the number of lines; a time proportional to the
;; square of it (T20261023-2) makes a large file unusable.
;; Also measure the time to refontify one line after an edit.  It should not
;; depend on the number of lines, but it does when the tasks are not separated
;; by blank lines: `markdown-mode' treats them as one paragraph and
;; propertizes all of it (T20261024-10).
;; Run it through scripts/bench-fontlock.sh, which sets these variables:
;;   BENCH_SIZES    line counts separated by spaces
;;   BENCH_MAX      if set, fail when a case exceeds this many seconds

;;; Code:

(require 'altodo)
(load (expand-file-name "bench-filter.el"
                        (file-name-directory (or load-file-name
                                                 buffer-file-name)))
      nil t)

(defun altodo-bench-fontlock-time (line-count)
  "Return the seconds to fontify a buffer of about LINE-COUNT lines."
  (with-temp-buffer
    (altodo-bench--fill line-count)
    (altodo-mode)
    (font-lock-mode 1)
    (let ((start (float-time)))
      (font-lock-flush)
      (font-lock-ensure)
      (- (float-time) start))))

(defun altodo-bench-fontlock-edit-time (line-count)
  "Return the milliseconds to refontify one line after an edit.
The buffer has about LINE-COUNT lines; the edit is in the middle.  The result
is the mean of 20 edits."
  (with-temp-buffer
    (altodo-bench--fill line-count)
    (altodo-mode)
    (font-lock-mode 1)
    (font-lock-ensure)
    (goto-char (/ (point-max) 2))
    (forward-line 1)
    (let ((start (float-time)))
      (dotimes (_ 20)
        (insert " ")
        (delete-char -1)
        (font-lock-flush (line-beginning-position) (line-end-position))
        (font-lock-ensure (line-beginning-position) (line-end-position))
        (syntax-propertize (line-end-position)))
      (* 50 (- (float-time) start)))))

(defun altodo-bench-fontlock-run ()
  "Run the benchmark with the settings in the environment variables."
  (let* ((sizes (mapcar #'string-to-number
                        (split-string (or (getenv "BENCH_SIZES")
                                          "2000 4000 8000"))))
         (max-seconds (and (getenv "BENCH_MAX")
                           (string-to-number (getenv "BENCH_MAX"))))
         (exceeded nil))
    (message "BENCH %-8s %-8s %s" "lines" "seconds" "edit-ms")
    (dolist (size sizes)
      (let ((seconds (altodo-bench-fontlock-time size))
            (edit-ms (altodo-bench-fontlock-edit-time size)))
        (message "BENCH %-8d %-8.2f %.1f" size seconds edit-ms)
        (when (and max-seconds (> seconds max-seconds))
          (setq exceeded t))))
    (when exceeded
      (message "BENCH FAILED: a case exceeded %s seconds" max-seconds)
      (kill-emacs 1))))

(provide 'bench-fontlock)
;;; bench-fontlock.el ends here
