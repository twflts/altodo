;;; review-decisions-test.el --- Tests for the decisions of the code review  -*- lexical-binding: t; -*-

;;; Commentary:
;; T20261023-6 and later: `heading:' is a regexp (B4), the settings without an
;; effect are gone and `altodo-sidebar-focus-after-activation' works (B5), the
;; filter commands use the DSL (B7), dates are recognized by one rule (S2), and
;; the UUID follows RFC 9562 (B11).

;;; Code:

(require 'ert)
(require 'altodo)
(require 'altodo-debug)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

;;; B4 `heading:' is a regexp

(defun review-decisions--count (pattern text)
  "Return the number of tasks that match PATTERN in TEXT."
  (altodo-test-with-buffer text
    (altodo--count-matching-lines pattern t)))

(defconst review-decisions--headings
  (concat "# Work\n[ ] w1\n# Workshop\n[ ] s1\n[ ] s2\n"
          "# Work\n[ ] w2\n## Sub\n[ ] sub1\n# Other\n[ ] o1\n")
  "Two headings `Work', one `Workshop', a sub heading and `Other'.")

(ert-deftest review-decisions-heading-pattern-is-a-regexp ()
  "The text after `heading:' is a regexp searched in the heading text."
  (should (= (review-decisions--count "heading:^Other$" review-decisions--headings) 1))
  (should (= (review-decisions--count "heading:Oth.r" review-decisions--headings) 1))
  (should (= (review-decisions--count "heading:^Work$" review-decisions--headings) 3))
  (should (= (review-decisions--count "heading:Work" review-decisions--headings) 5)))

(ert-deftest review-decisions-heading-pattern-uses-every-matching-heading ()
  "Two headings with the same text both count, with their child headings."
  (should (= (review-decisions--count "heading:^Work$" review-decisions--headings) 3))
  (should (= (review-decisions--count "heading:Sub" review-decisions--headings) 1)))

(ert-deftest review-decisions-heading-pattern-follows-edits ()
  "The ranges are made again after the buffer changes."
  (altodo-test-with-buffer "# A\n[ ] a\n# B\n[ ] b\n[ ] b2\n"
    (altodo--filter-lines (lambda () t))
    (should (= (altodo--count-matching-lines "heading:^B$" t) 2))
    (goto-char (point-min))
    (insert "[ ] x1\n[ ] x2\n[ ] x3\n[ ] x4\n[ ] x5\n")
    (should (= (altodo--count-matching-lines "heading:^B$" t) 2))
    (should (= (altodo--count-matching-lines "heading:^A$" t) 1))))

(ert-deftest review-decisions-heading-pattern-with-special-characters ()
  "A special character of a regexp has its meaning; escape it to match it."
  (let ((text "# C++\n[ ] c1\n# CC\n[ ] c2\n"))
    (should (= (review-decisions--count "heading:C\\+\\+" text) 1))
    (should (= (review-decisions--count "heading:C+" text) 2))))

(ert-deftest review-decisions-heading-pattern-invalid-regexp-is-an-error ()
  "An invalid regexp is reported when the pattern is compiled."
  (should-error (altodo--compile-normalized-pattern '(arg "heading" "\\("))
                :type 'error)
  (let ((output (with-output-to-string
                  (altodo-test-with-buffer "# A\n"
                    (altodo-debug-explain-pattern "heading:\\(")))))
    (should (string-match-p "ERROR" output))))

;;; B5 Settings

(ert-deftest review-decisions-dead-settings-are-gone ()
  "The settings that had no effect are not defined."
  (dolist (symbol '(altodo-font-lock-maximum-decoration
                    altodo-move-single-line-comments-manually
                    altodo-sidebar-buffer-name
                    altodo-sidebar-auto-resize))
    (should-not (boundp symbol))))

(defun review-decisions--apply-open-filter (focus)
  "Apply the `open' filter from the sidebar with FOCUS.
Return the name of the buffer shown in the selected window afterward."
  (let ((source (generate-new-buffer " decisions-source"))
        (sidebar (generate-new-buffer " decisions-sidebar"))
        (altodo-sidebar-focus-after-activation focus))
    (unwind-protect
        (save-window-excursion
          (delete-other-windows)
          (switch-to-buffer source)
          (insert "[ ] a\n[x] b\n")
          (altodo-mode)
          (let ((window (split-window)))
            (set-window-buffer window sidebar)
            (altodo-sidebar--render
             sidebar (list :entries '((:title "Open" :type search-simple
                                              :pattern "open"))
                           :indent 2 :source-buffer source))
            (select-window window)
            (with-current-buffer sidebar
              (setq-local altodo-sidebar--source-buffer source)
              (altodo-sidebar--apply-filter (button-at 1)))
            (buffer-name (window-buffer (selected-window)))))
      (kill-buffer source)
      (kill-buffer sidebar))))

(ert-deftest review-decisions-focus-after-activation ()
  "With the option set, the source window is selected after a filter."
  (should (string-match-p "decisions-source"
                          (review-decisions--apply-open-filter t))))

(ert-deftest review-decisions-no-focus-change-by-default ()
  "By default the sidebar keeps the focus."
  (should-not altodo-sidebar-focus-after-activation)
  (should (string-match-p "decisions-sidebar"
                          (review-decisions--apply-open-filter nil))))

;;; B7 Filter commands

(defun review-decisions--hidden-lines ()
  "Return the numbers of the lines hidden by a filter."
  (let (lines)
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (when (seq-some (lambda (overlay) (overlay-get overlay 'invisible))
                        (overlays-at (point)))
          (push (line-number-at-pos) lines))
        (forward-line 1)))
    (nreverse lines)))

(ert-deftest review-decisions-filter-by-pattern ()
  "The command shows the lines that match a DSL pattern."
  (altodo-test-with-buffer "[ ] a #t\n[x] b #t\n[ ] c\n"
    (altodo-filter-by-pattern "and:open,tag:t")
    (should (equal (review-decisions--hidden-lines) '(2 3)))
    (should (eq altodo--filter-mode 'pattern:and:open\,tag:t))))

(ert-deftest review-decisions-filter-by-invalid-pattern-changes-nothing ()
  "An invalid pattern is an error and the buffer is not filtered."
  (altodo-test-with-buffer "[ ] a\n[x] b\n"
    (should-error (altodo-filter-by-pattern "bogus:x") :type 'user-error)
    (should-error (altodo-filter-by-pattern "and:") :type 'user-error)
    (should-not (review-decisions--hidden-lines))))

(ert-deftest review-decisions-show-overdue-with-another-date-format ()
  "The overdue filter works with any `altodo-date-format'."
  (let ((altodo-date-format "%d/%m/%Y"))
    (altodo-test-with-buffer "[ ] old -> 01/01/2020\n[ ] new -> 01/01/2999\n[ ] none\n"
      (altodo-filter-show-overdue)
      (should (equal (review-decisions--hidden-lines) '(2 3)))
      (should (eq altodo--filter-mode 'overdue)))))

(ert-deftest review-decisions-filter-commands-use-the-dsl ()
  "Each command shows the lines of the DSL pattern with the same name."
  (dolist (case '((altodo-filter-show-done-only . "done")
                  (altodo-filter-show-progress-only . "progress")
                  (altodo-filter-show-waiting-only . "waiting")
                  (altodo-filter-show-open-only . "open")
                  (altodo-filter-show-cancelled-only . "cancelled")
                  (altodo-filter-show-priority . "priority")
                  (altodo-filter-show-star . "star")))
    (let ((text "[ ] a\n[x] b\n[@] c\n[w] d\n[~] e\n[ ] ! f\n[ ] + g\n"))
      (altodo-test-with-buffer text
        (funcall (car case))
        (let ((from-command (review-decisions--hidden-lines)))
          (altodo-filter-clear)
          (altodo-filter-by-pattern (cdr case))
          (should (equal (review-decisions--hidden-lines) from-command)))))))

;;; S2 Dates

(defun review-decisions--dates (line-text)
  "Return (DUE . START) found by the date functions in the line LINE-TEXT."
  (altodo-test-with-buffer (concat line-text "\n")
    (cons (altodo--line-due-date-value) (altodo--line-start-date-value))))

(ert-deftest review-decisions-dates-need-the-spaces-of-the-specification ()
  "A date needs a space around it and around the arrow."
  (should (equal (review-decisions--dates "[ ] a -> 2026-01-02")
                 '("2026-01-02")))
  (should (equal (review-decisions--dates "[ ] a 2026-01-01 -> 2026-01-02")
                 '("2026-01-02" . "2026-01-01")))
  (should (equal (review-decisions--dates "[ ] -> 2026-01-02") '("2026-01-02")))
  (should (equal (review-decisions--dates "[ ] 2026-01-01 ->")
                 '(nil . "2026-01-01")))
  (should (equal (review-decisions--dates "[ ] a->2026-01-02") '(nil)))
  (should (equal (review-decisions--dates "[ ] a-> 2026-01-02") '(nil)))
  (should (equal (review-decisions--dates "[ ] a ->2026-01-02") '(nil)))
  (should (equal (review-decisions--dates "[ ] x2026-01-01 ->") '(nil)))
  (should (equal (review-decisions--dates "[ ] a -> 2026-01-02x") '(nil))))

(ert-deftest review-decisions-dates-are-recognized-in-three-kinds-of-lines ()
  "Task lines, comment lines and headings have dates; other lines do not."
  (let ((text (concat "# Milestone -> 2026-05-01\n"
                      "[ ] task -> 2026-05-02\n"
                      "/// note -> 2026-05-03\n"
                      "    multi-line comment -> 2026-05-04\n"
                      "plain text -> 2026-05-05\n"
                      "```\n[ ] in code -> 2026-05-06\n```\n")))
    (altodo-test-with-buffer text
      (let (dates)
        (while (not (eobp))
          (push (altodo--line-due-date-value) dates)
          (forward-line 1))
        (should (equal (nreverse dates)
                       '("2026-05-01" "2026-05-02" "2026-05-03"
                         nil nil nil nil nil)))))))

(ert-deftest review-decisions-due-date-filter-ignores-multi-line-comments ()
  "A date in a multi-line comment is neither colored nor found by the filter."
  (altodo-test-with-buffer "[ ] a\n    see -> 2026-05-04\n[ ] b -> 2026-05-04\n"
    (let ((predicate (altodo--compile-simple-pattern "due-date:2026-05-04")))
      (goto-char (point-min))
      (forward-line 1)
      (should-not (funcall predicate))
      (forward-line 1)
      (should (funcall predicate)))
    (font-lock-mode 1)
    (font-lock-ensure)
    (save-excursion
      (goto-char (point-min))
      (forward-line 1)
      (search-forward "2026")
      (should-not (memq (get-text-property (match-beginning 0) 'face)
                        '(altodo-date-face altodo-date-due-today-face
                          altodo-date-due-soon-face
                          altodo-date-due-overdue-face))))))

(ert-deftest review-decisions-calendar-and-filter-agree-on-the-dates ()
  "The sidebar counts the tasks that the day filter finds."
  (altodo-test-with-buffer "[ ] a -> 2026-05-04\n    note -> 2026-05-04\n# H -> 2026-05-04\n"
    (let ((counts (altodo--collect-date-counts (current-buffer) nil)))
      (should (= (car (gethash "2026-05-04" counts)) 1)))
    (should (= (altodo--count-matching-lines "due-date:2026-05-04" t) 1))))

;;; B11 UUID

(ert-deftest review-decisions-uuid-v7-follows-rfc-9562 ()
  "The first 48 bits are the Unix time in milliseconds; version 7; variant 10."
  (let* ((before (floor (* 1000 (float-time))))
         (uuid (altodo--generate-uuidv7))
         (after (floor (* 1000 (float-time))))
         (hex (replace-regexp-in-string "-" "" uuid))
         (milliseconds (string-to-number (substring hex 0 12) 16)))
    (should (string-match-p
             "\\`[0-9a-f]\\{8\\}-[0-9a-f]\\{4\\}-7[0-9a-f]\\{3\\}-[89ab][0-9a-f]\\{3\\}-[0-9a-f]\\{12\\}\\'"
             uuid))
    (should (<= before milliseconds after))))

(ert-deftest review-decisions-uuid-v7-sorts-by-time ()
  "A later UUID sorts after an earlier one."
  (let ((first (altodo--generate-uuidv7)))
    (sleep-for 0.01)
    (should (string< first (altodo--generate-uuidv7)))))

(ert-deftest review-decisions-uuid-v7-has-random-bits ()
  "The random parts differ, and they are not all zero."
  (let ((uuids (cl-loop repeat 50 collect (altodo--generate-uuidv7))))
    (should (= (length (delete-dups (copy-sequence uuids))) 50))
    (should (cl-some (lambda (uuid) (not (string-match-p "-7000-" uuid))) uuids))))

;;; P2 The default patterns use the DSL

(defun review-decisions--old-lambda-count (condition text)
  "Count the tasks that match the former `lambda' of the default pattern.
CONDITION is the symbol given to `altodo--due-date-matches-p'; `this-week'
also leaves out the tasks due today."
  (altodo-test-with-buffer text
    (altodo--count-matching-lines
     (lambda ()
       (and (altodo--due-date-matches-p condition)
            (or (not (eq condition 'this-week))
                (not (altodo--due-date-matches-p 'today)))
            (not (or (altodo--line-state-p altodo-state-done)
                     (altodo--line-state-p altodo-state-cancelled)))))
     t)))

(ert-deftest review-decisions-default-due-patterns-keep-their-counts ()
  "The DSL patterns of the default sidebar count what the lambdas counted."
  (altodo-test-with-today 2026 3 11
    (let* ((text (concat "[ ] overdue -> 2026-03-01\n"
                         "[x] overdue done -> 2026-03-01\n"
                         "[ ] today -> 2026-03-11\n"
                         "[~] today cancelled -> 2026-03-11\n"
                         "[ ] soon -> 2026-03-13\n"
                         "[@] soon progress -> 2026-03-14\n"
                         "[ ] later -> 2026-04-20\n"
                         "[ ] no date\n"
                         "# Heading -> 2026-03-12\n"))
           (patterns (seq-filter
                      (lambda (entry)
                        (string-prefix-p "Open and" (plist-get entry :title)))
                      altodo-default-filter-patterns)))
      (should (= (length patterns) 3))
      (dolist (case '(("Over Due" . overdue) ("Due Today" . today)
                      ("Due This Week" . this-week)))
        (let* ((entry (seq-find (lambda (e)
                                  (string-match-p (car case) (plist-get e :title)))
                                patterns))
               (from-dsl (altodo-test-with-buffer text
                           (altodo--count-matching-lines
                            (plist-get entry :pattern) t))))
          (should (eq (plist-get entry :type) 'search-simple))
          (should (= from-dsl (review-decisions--old-lambda-count (cdr case) text))))))))

;;; M4 The sidebar mode

(ert-deftest review-decisions-sidebar-buffer-is-in-the-sidebar-mode ()
  "The sidebar buffer has its own major mode, derived from `special-mode'."
  (let ((source (generate-new-buffer " decisions-source"))
        (sidebar (generate-new-buffer " decisions-sidebar")))
    (unwind-protect
        (progn
          (altodo-sidebar--setup-buffer sidebar (list :name "x"))
          (with-current-buffer sidebar
            (should (eq major-mode 'altodo-sidebar-mode))
            (should (derived-mode-p 'special-mode))
            (should buffer-read-only)
            (should (eq (key-binding (kbd "RET"))
                        'altodo-sidebar--apply-filter-at-point))
            (should (eq (key-binding (kbd "?")) 'altodo-sidebar-help))))
      (kill-buffer source)
      (kill-buffer sidebar))))

;;; Keys that do not depend on the line

(ert-deftest review-decisions-view-keys-work-on-every-line ()
  "The filter and sidebar keys are bound to the commands on all lines."
  (altodo-test-with-buffer "# Heading\n\nplain text\n[ ] task\n"
    (dolist (case '(("C-c C-v f c" . altodo-filter-clear)
                    ("C-c C-v s t" . altodo-sidebar-toggle)
                    ("C-c C-v s r" . altodo-sidebar-refresh)))
      (should (eq (key-binding (kbd (car case))) (cdr case))))))

;;; Default patterns

(ert-deftest review-decisions-star-entry-has-no-count-face-rules ()
  "The \"Star (+)\" entry of the default patterns does not color the count."
  (let ((entry (cl-find-if (lambda (e) (equal (plist-get e :pattern) "star"))
                           altodo-default-filter-patterns)))
    (should entry)
    (should-not (plist-member entry :count-face-rules))))

(provide 'review-decisions-test)
;;; review-decisions-test.el ends here
