;;; bench-fontlock.el --- Benchmark of the altodo fontification  -*- lexical-binding: t; -*-

;;; Commentary:

;; Measure the time to fontify a whole buffer in `altodo-mode'.  The time
;; must grow in proportion to the number of lines; a time proportional to the
;; square of it (T20261023-2) makes a large file unusable.
;; Also measure the time to refontify one line after an edit.  It should not
;; depend on the number of lines, but it does when the tasks are not separated
;; by blank lines: `markdown-mode' treats them as one paragraph and
;; propertizes all of it (T20261024-10).
;; Two kinds of buffers are measured.  "sections" has a blank line after every
;; 48 tasks.  "contiguous" has few blank lines: tasks with many `///' lines
;; and identifiers with underscores, so a text block of `markdown-mode' has
;; hundreds of lines.  That shape made the time grow with the square of the
;; length of the block (T20261026-3), which "sections" does not show.
;; Run it through scripts/bench-fontlock.sh, which sets these variables:
;;   BENCH_SIZES    line counts separated by spaces
;;   BENCH_MAX      if set, fail when a case exceeds this many seconds

;;; Code:

(require 'altodo)
(load (expand-file-name "bench-filter.el"
                        (file-name-directory (or load-file-name
                                                 buffer-file-name)))
      nil t)

(defun altodo-bench-fontlock--fill-contiguous (line-count)
  "Insert about LINE-COUNT lines of tasks with `///' lines and few blank lines.
There is a blank line after every 60 tasks, and an identifier with an
underscore in every third line."
  (let ((count 0) (task 0))
    (while (< count line-count)
      (setq task (1+ task))
      (insert (format "[ ] task %d pii_detector #id:T%d%s\n" task task
                      (if (and (> task 1) (= 0 (% task 4)))
                          (format " #dep:T%d" (1- task))
                        "")))
      (setq count (1+ count))
      (dotimes (i (1+ (% task 6)))
        (when (< count line-count)
          (insert (format "    /// note %d of check_rule %s\n" i
                          (if (= 0 (% i 3)) "foo_bar and `code`" "text")))
          (setq count (1+ count))))
      (when (and (= 0 (% task 60)) (< count line-count))
        (insert "\n")
        (setq count (1+ count))))))

(defun altodo-bench-fontlock--fill (sample line-count)
  "Insert about LINE-COUNT lines of the SAMPLE (sections or contiguous)."
  (if (eq sample 'contiguous)
      (altodo-bench-fontlock--fill-contiguous line-count)
    (altodo-bench--fill line-count)))

(defun altodo-bench-fontlock-time (line-count &optional sample)
  "Return the seconds to fontify a buffer of about LINE-COUNT lines.
SAMPLE is `contiguous' or, by default, `sections'."
  (with-temp-buffer
    (altodo-bench-fontlock--fill sample line-count)
    (altodo-mode)
    (font-lock-mode 1)
    (let ((start (float-time)))
      (font-lock-flush)
      (font-lock-ensure)
      (- (float-time) start))))

(defun altodo-bench-fontlock-edit-time (line-count &optional sample)
  "Return the milliseconds to refontify one line after an edit.
The buffer has about LINE-COUNT lines of SAMPLE (see
`altodo-bench-fontlock-time'); the edit is in the middle.  The result is the
mean of 20 edits."
  (with-temp-buffer
    (altodo-bench-fontlock--fill sample line-count)
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
    (message "BENCH %-11s %-8s %-8s %s" "sample" "lines" "seconds" "edit-ms")
    (dolist (sample '(sections contiguous))
      (dolist (size sizes)
        (let ((seconds (altodo-bench-fontlock-time size sample))
              (edit-ms (altodo-bench-fontlock-edit-time size sample)))
          (message "BENCH %-11s %-8d %-8.2f %.1f" sample size seconds edit-ms)
          (when (and max-seconds (> seconds max-seconds))
            (setq exceeded t)))))
    (when exceeded
      (message "BENCH FAILED: a case exceeded %s seconds" max-seconds)
      (kill-emacs 1))))

(provide 'bench-fontlock)
;;; bench-fontlock.el ends here
