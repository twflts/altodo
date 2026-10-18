;;; filter-large-buffer-test.el --- Tests for filtering large buffers  -*- lexical-binding: t; -*-

;;; Commentary:
;; `altodo--filter-lines' must process every line, however many there are.

;;; Code:

(require 'ert)
(require 'altodo)

(defun filter-large-buffer-test--hidden-p (line)
  "Return non-nil if LINE (1-based) is hidden by a filter overlay."
  (save-excursion
    (goto-char (point-min))
    (forward-line (1- line))
    (cl-some (lambda (ov) (eq (overlay-get ov 'invisible) t))
             (overlays-at (point)))))

(defun filter-large-buffer-test--fill (line-count done-every)
  "Insert LINE-COUNT task lines; every DONE-EVERY-th line is done."
  (dotimes (i line-count)
    (insert (format "%s task %d\n"
                    (if (= 0 (% (1+ i) done-every)) "[x]" "[ ]")
                    (1+ i)))))

(ert-deftest filter-large-buffer-test-all-lines-processed ()
  "Lines beyond 10000 are hidden or shown according to the predicate."
  (with-temp-buffer
    (filter-large-buffer-test--fill 10050 1000)
    (altodo-mode)
    (altodo--filter-lines #'altodo--line-done-p t 'none)
    ;; Lines 1000, 2000, ..., 10000 are done and stay visible.
    (should-not (filter-large-buffer-test--hidden-p 1000))
    (should-not (filter-large-buffer-test--hidden-p 10000))
    ;; Lines after 10000 do not match, so they are hidden.
    (should (filter-large-buffer-test--hidden-p 10001))
    (should (filter-large-buffer-test--hidden-p 10050))
    (should (= (length altodo--filter-overlays) (- 10050 10)))))

(ert-deftest filter-large-buffer-test-matches-after-limit ()
  "A matching line after line 10000 is shown."
  (with-temp-buffer
    (filter-large-buffer-test--fill 10050 10040)
    (altodo-mode)
    (altodo--filter-lines #'altodo--line-done-p t 'none)
    (should-not (filter-large-buffer-test--hidden-p 10040))
    (should (filter-large-buffer-test--hidden-p 10039))
    (should (filter-large-buffer-test--hidden-p 10041))))

(ert-deftest filter-large-buffer-test-heading-only-context ()
  "The heading of a match after line 10000 is shown with heading-only."
  (with-temp-buffer
    (insert "# First\n\n")
    (filter-large-buffer-test--fill 10050 100000)
    (insert "\n# Last\n\n[x] last done\n")
    (altodo-mode)
    (altodo--filter-lines #'altodo--line-done-p t 'heading-only)
    (let ((last-line (line-number-at-pos (point-max))))
      ;; "[x] last done" is the final line; its heading "# Last" is shown.
      (should-not (filter-large-buffer-test--hidden-p (- last-line 1)))
      (should-not (filter-large-buffer-test--hidden-p (- last-line 3)))
      ;; A task line in the middle does not match and is hidden.
      (should (filter-large-buffer-test--hidden-p 5000)))))

(ert-deftest filter-large-buffer-test-goto-line ()
  "`altodo--goto-line' returns the same position in either direction."
  (with-temp-buffer
    (dotimes (i 100) (insert (format "line %d\n" (1+ i))))
    (let ((altodo--goto-line-cache nil))
      (dolist (n '(1 10 10 50 20 100 1 99))
        (altodo--goto-line n)
        (should (= (line-number-at-pos) n))
        (should (bolp))))))

(provide 'filter-large-buffer-test)
;;; filter-large-buffer-test.el ends here
