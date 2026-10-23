;;; altodo-debug.el --- Investigation commands for altodo  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 altodo contributors

;; Author: twofaults
;; Maintainer: twofaults
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (markdown-mode "2.0"))
;; Keywords: tools, convenience
;; URL: https://github.com/twflts/altodo

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Commands to find out why altodo behaves as it does.  Nothing here is
;; loaded or run by altodo itself, and the commands change no setting.
;;
;; - `altodo-debug-describe-line': what altodo sees in a line (kind, state,
;;   tags, dates, dependencies, faces, filter, pattern results).
;; - `altodo-debug-explain-pattern': how a DSL pattern is parsed and which
;;   lines it matches.
;; - `altodo-debug-trace', `altodo-debug-untrace-all': trace the calls of
;;   altodo functions with `trace-function-background'.
;; - `altodo-debug-profile': profile the fontification, a sidebar drawing or a
;;   filter.
;; - `altodo-debug-report': the versions and settings to put in a bug report.
;;
;; The reports go to the buffer *altodo-debug*, or to the standard output in
;; batch mode.  The batch commands `altodo-debug-batch-line' (arguments FILE
;; and LINE) and `altodo-debug-batch-pattern' (arguments FILE and PATTERN)
;; take their arguments from the command line, after `-f COMMAND'.
;; scripts/debug-line.sh and scripts/debug-pattern.sh wrap them.  For stepping
;; use `edebug-defun'; for errors use `toggle-debug-on-error'.

;;; Code:

(require 'altodo)
(require 'cl-lib)
(require 'subr-x)
(require 'trace)

(declare-function profiler-start "profiler")
(declare-function profiler-stop "profiler")
(declare-function profiler-report "profiler")

(defconst altodo-debug-buffer-name "*altodo-debug*"
  "Name of the buffer that has the reports.")

(defconst altodo-debug--pattern-line-limit 20
  "Number of matching line numbers that `altodo-debug-explain-pattern' lists.")

;;; Output

(defun altodo-debug--emit (title text)
  "Show TEXT under TITLE: in the report buffer, or on stdout in batch mode."
  (if noninteractive
      (princ (format "== %s\n%s\n" title text))
    (with-current-buffer (get-buffer-create altodo-debug-buffer-name)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "== %s\n%s\n" title text))
        (goto-char (point-min)))
      (special-mode)
      (pop-to-buffer (current-buffer)))))

(defmacro altodo-debug--safely (&rest body)
  "Return the value of BODY, or the text of the error that BODY signals.
A check that fails is part of what a report must show."
  (declare (indent 0))
  `(condition-case err
       (progn ,@body)
     (error (format "ERROR %s" (error-message-string err)))))

(defun altodo-debug--format-facts (facts)
  "Return FACTS, an alist of (LABEL . VALUE), as lines of text."
  (mapconcat (lambda (fact)
               (format "%-22s %s" (car fact)
                       (let ((value (cdr fact)))
                         (if (stringp value) value (format "%S" value)))))
             facts "\n"))

;;; Line

(defun altodo-debug--line-kind ()
  "Return the kind of the current line as a string."
  (cond
   ((altodo--in-fenced-code-block-p) "inside a fenced code block")
   ((altodo--task-p) "task")
   ((altodo--comment-p) "comment (///)")
   ((altodo--multiline-comment-p) "multi-line comment")
   ((altodo--line-heading-p) (format "heading (level %s)" (altodo--heading-level)))
   ((altodo--line-empty-p) "empty")
   (t "other text")))

(defun altodo-debug--date-fact (value)
  "Describe the date string VALUE (YYYY-MM-DD) and its distance to today."
  (if (null value)
      "none"
    (let ((time (altodo--parse-normalized-date value)))
      (if time
          (format "%s (%+d days from today)" value
                  (round (altodo--days-diff time)))
        (format "%s (not a date that exists)" value)))))

(defun altodo-debug--heading-chain (position)
  "Return the headings that contain POSITION, outermost first, as a string."
  (let ((chain nil))
    (dolist (heading (altodo--collect-headings nil))
      (when (< (nth 2 heading) position)
        (while (and chain (>= (nth 1 (car chain)) (nth 1 heading)))
          (pop chain))
        (push heading chain)))
    (if chain
        (mapconcat (lambda (heading)
                     (format "%s %s" (make-string (nth 1 heading) ?#)
                             (nth 0 heading)))
                   (reverse chain) " > ")
      "none")))

(defun altodo-debug--faces-at (line-beginning line-end)
  "Return the faces of the first non-space character and of the last one.
LINE-BEGINNING and LINE-END delimit the line, which is fontified first."
  (font-lock-ensure line-beginning line-end)
  (save-excursion
    (goto-char line-beginning)
    (skip-chars-forward " \t")
    (let ((first (point)))
      (list (cons "face (first char)" (get-text-property first 'face))
            (cons "face (last char)"
                  (and (> line-end line-beginning)
                       (get-text-property (1- line-end) 'face)))))))

(defun altodo-debug--pattern-results ()
  "Return an alist of the results of the simple patterns on the current line."
  (mapcar (lambda (name)
            (cons (format "pattern %s" name)
                  (altodo-debug--safely
                    (save-excursion
                      (beginning-of-line)
                      (and (funcall (altodo--compile-normalized-pattern
                                     (list 'simple name)))
                           t)))))
          altodo--dsl-simple-patterns))

(defun altodo-debug--state-name (state)
  "Return the name of the task STATE, a string such as \"x\"."
  (format "%s (%s)"
          (pcase state
            ((pred (equal altodo-state-done)) "done")
            ((pred (equal altodo-state-progress)) "in progress")
            ((pred (equal altodo-state-waiting)) "waiting")
            ((pred (equal altodo-state-cancelled)) "cancelled")
            (_ "open"))
          state))

(defun altodo-debug--line-facts ()
  "Return the facts about the current line as an alist of (LABEL . VALUE)."
  (let* ((beginning (line-beginning-position))
         (end (line-end-position))
         (task (and (altodo--task-p) t)))
    (save-excursion
      (beginning-of-line)
      (append
       (list (cons "line" (line-number-at-pos))
             (cons "text" (buffer-substring-no-properties beginning end))
             (cons "kind" (altodo-debug--safely (altodo-debug--line-kind)))
             (cons "indent" (altodo--get-current-indent))
             (cons "heading chain"
                   (altodo-debug--safely
                     (altodo-debug--heading-chain beginning))))
       (when (or task (altodo--comment-p))
         (list
          (cons "state"
                (altodo-debug--safely
                  (and task
                       (looking-at altodo-task-regex)
                       (altodo-debug--state-name
                        (altodo--normalize-state (match-string 2))))))
          (cons "flags (star priority)"
                (altodo-debug--safely
                  (and (looking-at altodo-task-regex)
                       (butlast (altodo--parse-flags (match-string 3))))))
          (cons "tags"
                (altodo-debug--safely (altodo--line-extract-all-tags "all")))
          (cons "persons"
                (altodo-debug--safely (altodo--line-extract-all-persons)))
          (cons "due date"
                (altodo-debug--safely
                  (altodo-debug--date-fact (altodo--line-due-date-value))))
          (cons "start date"
                (altodo-debug--safely
                  (altodo-debug--date-fact (altodo--line-start-date-value))))
          (cons "#done"
                (altodo-debug--safely (altodo--line-done-tag-value)))
          (cons "#id" (altodo-debug--safely (altodo--get-task-id beginning)))
          (cons "#dep"
                (altodo-debug--safely
                  (let ((deps (altodo--get-task-deps beginning)))
                    (and deps
                         (save-excursion
                           (end-of-line)
                           (format "%S -> %s" deps
                                   (altodo--check-all-deps-completed
                                    deps)))))))
          (cons "seq-tasks (child)"
                (altodo-debug--safely
                  (and (altodo--is-seq-tasks-child-blocked-p)
                       "blocked by the sibling above")))))
       (altodo-debug--faces-at beginning end)
       (list (cons "hidden by a filter"
                   (and (seq-some (lambda (overlay)
                                    (and (eq (overlay-get overlay 'category)
                                             'altodo-filter)
                                         (overlay-get overlay 'invisible)))
                                  (overlays-at beginning))
                        t)))
       (altodo-debug--pattern-results)))))

;;;###autoload
(defun altodo-debug-describe-line (&optional line)
  "Report what altodo sees in LINE, by default the current line.
It shows the kind, state, flags, tags, dates, dependencies, faces, whether a
filter hides the line, and the result of each simple DSL pattern."
  (interactive (list (and current-prefix-arg
                          (prefix-numeric-value current-prefix-arg))))
  (save-excursion
    (when line
      (goto-char (point-min))
      (forward-line (1- line)))
    (altodo-debug--emit
     (format "%s line %d" (buffer-name) (line-number-at-pos))
     (altodo-debug--format-facts (altodo-debug--line-facts)))))

;;; Pattern

(defun altodo-debug--match-lines (predicate)
  "Return the number of the lines where PREDICATE is true, in buffer order."
  (let ((lines nil))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (when (funcall predicate)
          (push (line-number-at-pos) lines))
        (forward-line 1)))
    (nreverse lines)))

;;;###autoload
(defun altodo-debug-explain-pattern (pattern)
  "Report how the DSL PATTERN is parsed and which lines it matches.
Unlike the sidebar, which hides a pattern that cannot be compiled, this
shows the reason."
  (interactive "sDSL pattern: ")
  (let* ((normalized (condition-case err
                         (altodo--normalize-pattern pattern)
                       (error (format "ERROR %s" (error-message-string err)))))
         (valid (and (consp normalized)
                     (altodo--validate-pattern normalized)))
         (predicate (and valid
                         (condition-case err
                             (altodo--compile-normalized-pattern normalized)
                           (error (format "ERROR %s"
                                          (error-message-string err))))))
         facts)
    (push (cons "pattern" pattern) facts)
    (push (cons "normalized" normalized) facts)
    (push (cons "valid" (and valid t)) facts)
    (if (functionp predicate)
        (let* ((start (float-time))
               (lines (altodo-debug--safely
                        (altodo-debug--match-lines predicate)))
               (seconds (- (float-time) start)))
          (if (stringp lines)
              (push (cons "matching" lines) facts)
            (push (cons "matching lines" (length lines)) facts)
            (push (cons "first lines"
                        (seq-take lines altodo-debug--pattern-line-limit))
                  facts)
            (push (cons "time" (format "%.3f seconds" seconds)) facts)))
      (push (cons "compile" (or predicate "skipped: the pattern is not valid"))
            facts))
    (altodo-debug--emit (format "%s pattern" (buffer-name))
                        (altodo-debug--format-facts (nreverse facts)))))

;;; Trace

(defvar altodo-debug--traced nil
  "The functions traced by `altodo-debug-trace'.")

(defun altodo-debug--function-names ()
  "Return the names of the functions that start with altodo."
  (let (names)
    (mapatoms (lambda (symbol)
                (when (and (fboundp symbol)
                           (string-prefix-p "altodo" (symbol-name symbol)))
                  (push (symbol-name symbol) names))))
    (sort names #'string<)))

;;;###autoload
(defun altodo-debug-trace (function)
  "Trace FUNCTION, an altodo function, in the buffer *trace-output*.
Each call shows its arguments and its value, indented by its depth."
  (interactive
   (list (intern (completing-read "Trace function: "
                                  (altodo-debug--function-names) nil t))))
  (trace-function-background function)
  (cl-pushnew function altodo-debug--traced)
  (message "Tracing %s (output: *trace-output*)" function))

;;;###autoload
(defun altodo-debug-untrace-all ()
  "Stop tracing the functions traced by `altodo-debug-trace'."
  (interactive)
  (mapc #'untrace-function altodo-debug--traced)
  (setq altodo-debug--traced nil)
  (message "Stopped tracing"))

;;; Profile

(defun altodo-debug--profile-thunk (operation)
  "Return the function to run for OPERATION, a string from the profile menu."
  (pcase operation
    ("fontify" (lambda () (font-lock-flush) (font-lock-ensure)))
    ("sidebar" (lambda ()
                 (let ((sidebar (generate-new-buffer " altodo-debug-sidebar"))
                       (config (altodo-sidebar-make-config)))
                   (unwind-protect (altodo-sidebar--render sidebar config)
                     (kill-buffer sidebar)))))
    ("filter" (let ((predicate (altodo--compile-simple-pattern
                                (read-string "DSL pattern: " "done"))))
                (lambda () (altodo--filter-lines predicate))))
    (_ (user-error "Unknown operation: %s" operation))))

;;;###autoload
(defun altodo-debug-profile (operation)
  "Profile OPERATION on the current buffer and show the CPU report.
OPERATION is \"fontify\" (fontify the whole buffer), \"sidebar\" (draw the
sidebar) or \"filter\" (apply a DSL pattern).  The time is also reported."
  (interactive
   (list (completing-read "Profile: " '("fontify" "sidebar" "filter") nil t)))
  (require 'profiler)
  (let ((thunk (altodo-debug--profile-thunk operation))
        (start nil)
        (seconds nil))
    (profiler-start 'cpu)
    (unwind-protect
        (progn (setq start (float-time))
               (funcall thunk)
               (setq seconds (- (float-time) start)))
      (profiler-stop))
    (message "altodo-debug: %s took %.3f seconds" operation seconds)
    (profiler-report)))

;;; Report

(defun altodo-debug--changed-options ()
  "Return the altodo options that differ from their standard value."
  (let (changed)
    (mapatoms
     (lambda (symbol)
       (when (and (string-prefix-p "altodo-" (symbol-name symbol))
                  (boundp symbol)
                  (custom-variable-p symbol)
                  (not (equal (symbol-value symbol)
                              (eval (car (get symbol 'standard-value)) t))))
         (push (cons (symbol-name symbol) (symbol-value symbol)) changed))))
    (sort changed (lambda (a b) (string< (car a) (car b))))))

(defun altodo-debug--locals-fact ()
  "Describe the .altodo-locals.el of the current buffer."
  (let ((file (and buffer-file-name
                   (expand-file-name ".altodo-locals.el"
                                     (file-name-directory buffer-file-name)))))
    (cond
     ((null file) "the buffer has no file")
     ((not (file-exists-p file)) (format "none (%s)" file))
     (t (let ((data (altodo--load-locals-file)))
          (format "%s: %d settings, %d filter patterns" file (length data)
                  (length (altodo--get-filter-patterns))))))))

(defun altodo-debug--sidebar-fact ()
  "Describe the sidebar of the current buffer."
  (let ((sidebar (altodo--get-sidebar-buffer)))
    (if (null sidebar)
        "not created"
      (with-current-buffer sidebar
        (format "%s; mode %s; selection %s; selected %d; active %d"
                (if (get-buffer-window sidebar t) "shown" "hidden")
                altodo-sidebar--combine-mode altodo-sidebar--selection-mode
                (length altodo-sidebar--selected-filters)
                (length altodo-sidebar--active-entries))))))

;;;###autoload
(defun altodo-debug-report ()
  "Report the versions and settings to put in a bug report."
  (interactive)
  (let ((library (locate-library "altodo")))
    (altodo-debug--emit
     "altodo report"
     (concat
      (altodo-debug--format-facts
       (list (cons "Emacs" emacs-version)
             (cons "system" (symbol-name system-type))
             (cons "markdown-mode" (and (boundp 'markdown-mode-version)
                                        markdown-mode-version))
             (cons "altodo.el" (and library
                                    (format "%s (modified %s)" library
                                            (format-time-string
                                             "%Y-%m-%d %H:%M:%S"
                                             (file-attribute-modification-time
                                              (file-attributes library))))))
             (cons "buffer" (buffer-name))
             (cons "major mode" major-mode)
             (cons "lines" (count-lines (point-min) (point-max)))
             (cons "filter overlays" (length altodo--filter-overlays))
             (cons "locals file" (altodo-debug--locals-fact))
             (cons "sidebar" (altodo-debug--sidebar-fact))))
      "\n\nOptions that differ from the standard value:\n"
      (let ((changed (altodo-debug--changed-options)))
        (if changed
            (altodo-debug--format-facts changed)
          "none"))))))

;;; Batch commands

(defun altodo-debug--visit (file)
  "Visit FILE in `altodo-mode' and return its buffer."
  (let ((buffer (find-file-noselect file)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'altodo-mode)
        (altodo-mode)))
    buffer))

(defun altodo-debug-batch-line ()
  "Batch command: report a line.  The arguments are FILE and LINE."
  (let ((file (pop command-line-args-left))
        (line (string-to-number (or (pop command-line-args-left) "1"))))
    (unless file
      (error "Usage: -f altodo-debug-batch-line FILE LINE"))
    (with-current-buffer (altodo-debug--visit file)
      (altodo-debug-describe-line line))))

(defun altodo-debug-batch-pattern ()
  "Batch command: explain a pattern.  The arguments are FILE and PATTERN."
  (let ((file (pop command-line-args-left))
        (pattern (pop command-line-args-left)))
    (unless (and file pattern)
      (error "Usage: -f altodo-debug-batch-pattern FILE PATTERN"))
    (with-current-buffer (altodo-debug--visit file)
      (altodo-debug-explain-pattern pattern))))

(provide 'altodo-debug)
;;; altodo-debug.el ends here
