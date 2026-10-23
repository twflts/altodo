;;; bench-fontlock.el --- Benchmark of the altodo fontification  -*- lexical-binding: t; -*-

;;; Commentary:

;; Measure the time to fontify a whole buffer in `altodo-mode'.  The time
;; must grow in proportion to the number of lines; a time proportional to the
;; square of it (T20261023-2) makes a large file unusable.
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

(defun altodo-bench-fontlock-run ()
  "Run the benchmark with the settings in the environment variables."
  (let* ((sizes (mapcar #'string-to-number
                        (split-string (or (getenv "BENCH_SIZES")
                                          "2000 4000 8000"))))
         (max-seconds (and (getenv "BENCH_MAX")
                           (string-to-number (getenv "BENCH_MAX"))))
         (exceeded nil))
    (message "BENCH %-8s %s" "lines" "seconds")
    (dolist (size sizes)
      (let ((seconds (altodo-bench-fontlock-time size)))
        (message "BENCH %-8d %.2f" size seconds)
        (when (and max-seconds (> seconds max-seconds))
          (setq exceeded t))))
    (when exceeded
      (message "BENCH FAILED: a case exceeded %s seconds" max-seconds)
      (kill-emacs 1))))

(provide 'bench-fontlock)
;;; bench-fontlock.el ends here
