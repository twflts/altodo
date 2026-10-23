;;; altodo-debug-test.el --- Tests for the investigation commands  -*- lexical-binding: t; -*-

;;; Commentary:
;; T20261023-3: `altodo-debug-describe-line', `altodo-debug-explain-pattern',
;; the report, the trace and the batch commands.

;;; Code:

(require 'ert)
(require 'altodo-debug)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defconst altodo-debug-test--text
  (concat "# Proj\n"
          "## Sub\n"
          "[ ] parent #seq-tasks #id:p1\n"
          "    [ ] one @bob -> 2026-03-01 #t:5\n"
          "    [ ] two #dep:p1\n"
          "[x] done https://x.com/a@b #done:2026-03-01\n")
  "Sample with a heading chain, a seq-tasks parent, a dependency and a URL.")

(defun altodo-debug-test--facts (line)
  "Return the facts of LINE of the sample text as an alist."
  (altodo-test-with-buffer altodo-debug-test--text
    (altodo-test-with-today 2026 3 10
      (forward-line (1- line))
      (altodo-debug--line-facts))))

(defun altodo-debug-test--fact (facts label)
  "Return the value of LABEL in FACTS."
  (cdr (assoc label facts)))

(ert-deftest altodo-debug-line-task-facts ()
  "A task line shows its kind, state, tags, persons, date and heading chain."
  (let ((facts (altodo-debug-test--facts 4)))
    (should (equal (altodo-debug-test--fact facts "kind") "task"))
    (should (string-prefix-p "open" (altodo-debug-test--fact facts "state")))
    (should (equal (altodo-debug-test--fact facts "tags") '("t:5")))
    (should (equal (altodo-debug-test--fact facts "persons") '("bob")))
    (should (string-match-p "2026-03-01 (-9 days from today)"
                            (altodo-debug-test--fact facts "due date")))
    (should (equal (altodo-debug-test--fact facts "heading chain")
                   "# Proj > ## Sub"))
    (should (eq (altodo-debug-test--fact facts "pattern task") t))
    (should (eq (altodo-debug-test--fact facts "pattern open") t))
    (should-not (altodo-debug-test--fact facts "pattern done"))))

(ert-deftest altodo-debug-line-url-at-sign-is-not-a-person ()
  "The @ of a URL is not shown as a person."
  (let ((facts (altodo-debug-test--facts 6)))
    (should (string-prefix-p "done" (altodo-debug-test--fact facts "state")))
    (should-not (altodo-debug-test--fact facts "persons"))
    (should (equal (altodo-debug-test--fact facts "#done") "2026-03-01"))))

(ert-deftest altodo-debug-line-dependency-and-seq-tasks ()
  "A blocked dependency and a blocked child are explained."
  (let ((facts (altodo-debug-test--facts 5)))
    (should (string-match-p "blocked"
                            (altodo-debug-test--fact facts "#dep")))
    (should (altodo-debug-test--fact facts "seq-tasks (child)")))
  (let ((facts (altodo-debug-test--facts 3)))
    (should (equal (altodo-debug-test--fact facts "#id") "p1"))))

(ert-deftest altodo-debug-line-heading-and-other-kinds ()
  "The kind of a heading line and of a line in a code block."
  (should (string-match-p
           "heading (level 2)"
           (altodo-debug-test--fact (altodo-debug-test--facts 2) "kind")))
  (altodo-test-with-buffer "```\n[ ] in code\n```\n"
    (forward-line 1)
    (should (equal (cdr (assoc "kind" (altodo-debug--line-facts)))
                   "inside a fenced code block"))))

(ert-deftest altodo-debug-line-reports-a-failing-check ()
  "A check that signals an error is shown as text, not raised."
  (cl-letf (((symbol-function 'altodo--line-due-date-value)
             (lambda () (error "boom"))))
    (let ((facts (altodo-debug-test--facts 4)))
      (should (string-match-p "ERROR boom"
                              (altodo-debug-test--fact facts "due date"))))))

(ert-deftest altodo-debug-line-hidden-by-a-filter ()
  "A line hidden by a filter is reported."
  (altodo-test-with-buffer altodo-debug-test--text
    (altodo--filter-lines (lambda () (looking-at "\\[x\\]")) t 'none)
    (goto-char (point-min))
    (forward-line 3)
    (should (cdr (assoc "hidden by a filter" (altodo-debug--line-facts))))
    (altodo-filter-clear)))

(ert-deftest altodo-debug-line-does-not-move-point ()
  "The command leaves point where it was, and prints in batch mode."
  (altodo-test-with-buffer altodo-debug-test--text
    (goto-char 5)
    (let ((output (with-output-to-string (altodo-debug-describe-line 4))))
      (should (string-match-p "== .* line 4" output))
      (should (string-match-p "kind +task" output)))
    (should (= (point) 5))))

(ert-deftest altodo-debug-explain-valid-pattern ()
  "A valid pattern shows its structure and the matching lines."
  (altodo-test-with-buffer altodo-debug-test--text
    (let ((output (with-output-to-string
                    (altodo-debug-explain-pattern "and:open,tag:t"))))
      (should (string-match-p "(logic and (\"open\" \"tag:t\"))" output))
      (should (string-match-p "valid +t" output))
      (should (string-match-p "matching lines +1" output))
      (should (string-match-p "first lines +(4)" output)))))

(ert-deftest altodo-debug-explain-invalid-pattern ()
  "An invalid pattern is explained, not hidden."
  (altodo-test-with-buffer altodo-debug-test--text
    (let ((output (with-output-to-string
                    (altodo-debug-explain-pattern "bogus:x"))))
      (should (string-match-p "valid +nil" output))
      (should (string-match-p "not valid" output))))
  (altodo-test-with-buffer altodo-debug-test--text
    (let ((output (with-output-to-string
                    (altodo-debug-explain-pattern "due-date:garbage"))))
      (should (string-match-p "compile +ERROR\\|matching +ERROR" output)))))

(ert-deftest altodo-debug-report-lists-changed-options ()
  "The report has the versions and the options that differ from the standard."
  (altodo-test-with-buffer altodo-debug-test--text
    (let* ((altodo-week-start-day 3)
           (output (with-output-to-string (altodo-debug-report))))
      (should (string-match-p (regexp-quote emacs-version) output))
      (should (string-match-p "major mode +altodo-mode" output))
      (should (string-match-p "altodo-week-start-day +3" output)))))

(ert-deftest altodo-debug-trace-and-untrace ()
  "Tracing adds advice, and `altodo-debug-untrace-all' removes it."
  (let ((altodo-debug--traced nil))
    (unwind-protect
        (progn
          (let ((inhibit-message t))
            (altodo-debug-trace 'altodo--normalize-state))
          (should (advice--p (symbol-function 'altodo--normalize-state))))
      (altodo-debug-untrace-all))
    (should-not altodo-debug--traced)
    (should-not (advice--p (symbol-function 'altodo--normalize-state)))))

(ert-deftest altodo-debug-function-names-start-with-altodo ()
  "The completion list has only altodo functions."
  (let ((names (altodo-debug--function-names)))
    (should (member "altodo-debug-trace" names))
    (should (cl-every (lambda (name) (string-prefix-p "altodo" name)) names))))

(ert-deftest altodo-debug-batch-commands-take-arguments-from-the-command-line ()
  "The batch commands pop FILE and LINE or PATTERN from the arguments."
  (altodo-test-with-temp-dir dir
    (let ((file (expand-file-name "t.altodo" dir)))
      (with-temp-file file (insert altodo-debug-test--text))
      (let ((command-line-args-left (list file "4")))
        (should (string-match-p "kind +task"
                                (with-output-to-string
                                  (altodo-debug-batch-line)))))
      (let ((command-line-args-left (list file "tag:t")))
        (should (string-match-p "matching lines +1"
                                (with-output-to-string
                                  (altodo-debug-batch-pattern)))))
      (let ((command-line-args-left nil))
        (should-error (altodo-debug-batch-line)))
      (dolist (buffer (buffer-list))
        (when (equal (buffer-file-name buffer) (file-truename file))
          (kill-buffer buffer))))))

(ert-deftest altodo-debug-altodo-does-not-depend-on-the-debug-file ()
  "Loading altodo does not load or redefine anything for debugging."
  (should-not (fboundp 'debug-helper-setup))
  (should-not (boundp 'altodo-debug-mode))
  (should (subrp (symbol-function 'message))))

(provide 'altodo-debug-test)
;;; altodo-debug-test.el ends here
