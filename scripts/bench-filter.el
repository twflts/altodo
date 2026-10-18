;;; bench-filter.el --- Benchmark of the altodo filter  -*- lexical-binding: t; -*-

;;; Commentary:

;; Measure the time of `altodo--filter-lines' on generated buffers.
;; Run it through scripts/bench-filter.sh, which sets these variables:
;;   BENCH_SIZES    line counts separated by spaces
;;   BENCH_REPEAT   number of runs per case (the median is reported)
;;   BENCH_MAX      if set, fail when a case exceeds this many seconds

;;; Code:

(require 'altodo)
(require 'cl-lib)

(defconst altodo-bench--patterns
  '(("done" . "done")
    ("tag" . "tag:work")
    ("and" . "and:open,priority"))
  "Alist of (LABEL . PATTERN) measured for each buffer size.")

(defconst altodo-bench--contexts '(none heading-only all)
  "Display contexts measured for each pattern.")

(defun altodo-bench--fill (line-count)
  "Insert about LINE-COUNT lines of a typical altodo file."
  (let ((count 0) (section 0))
    (while (< count line-count)
      (setq section (1+ section))
      (insert (format "## Section %d\n\n" section))
      (setq count (+ count 2))
      (dotimes (i 48)
        (when (< count line-count)
          (insert (format "[%s] %stask %d-%d #work @bob%s\n"
                          (nth (% i 5) '(" " "x" "@" "w" "~"))
                          (if (= 0 (% i 7)) "! " "")
                          section i
                          (if (= 0 (% i 3)) " -> 2026-12-31" "")))
          (setq count (1+ count))
          (when (and (= 0 (% i 5)) (< count line-count))
            (insert "    description of the task\n")
            (setq count (1+ count))))))))

(defun altodo-bench--time (line-count pattern context repeat)
  "Return the median seconds of REPEAT runs of PATTERN in CONTEXT.
The buffer holds about LINE-COUNT lines."
  (let (times)
    (dotimes (_ repeat)
      (with-temp-buffer
        (altodo-bench--fill line-count)
        (altodo-mode)
        (let ((predicate (altodo--compile-simple-pattern pattern))
              (start (float-time)))
          (altodo--filter-lines predicate t context)
          (push (- (float-time) start) times))))
    (nth (/ (length times) 2) (sort times #'<))))

(defun altodo-bench-run ()
  "Run the benchmark with the settings in the environment variables."
  (let* ((sizes (mapcar #'string-to-number
                        (split-string (or (getenv "BENCH_SIZES")
                                          "5000 10000 20000"))))
         (repeat (string-to-number (or (getenv "BENCH_REPEAT") "1")))
         (max-seconds (and (getenv "BENCH_MAX")
                           (string-to-number (getenv "BENCH_MAX"))))
         (exceeded nil))
    (message "BENCH %-8s %-6s %-13s %s" "lines" "case" "context" "seconds")
    (dolist (size sizes)
      (dolist (entry altodo-bench--patterns)
        (dolist (context altodo-bench--contexts)
          (let ((seconds (altodo-bench--time size (cdr entry) context
                                             (max repeat 1))))
            (message "BENCH %-8d %-6s %-13s %.2f" size (car entry) context
                     seconds)
            (when (and max-seconds (> seconds max-seconds))
              (setq exceeded t))))))
    (when exceeded
      (message "BENCH FAILED: a case exceeded %s seconds" max-seconds)
      (kill-emacs 1))))

(provide 'bench-filter)
;;; bench-filter.el ends here
