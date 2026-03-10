;;; altodo.el --- Major mode for editing altodo files -*- lexical-binding: t; -*-

;; Copyright (C) 2026 altodo contributors

;; Author: twofaults
;; Maintainer: twofaults
;; Created: January 27, 2026
;; Version: 0.1.0
;; Package-Requires: ((emacs "26.1") (markdown-mode "2.0"))
;; Keywords: text, todo, markdown

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

;; altodo-mode is a major mode for editing altodo files, which are
;; Markdown-based TODO files with enhanced task management features.
;;
;; Features:
;; - Syntax highlighting for task states, flags, tags, and dates
;; - Task state management with keyboard shortcuts
;; - Nested task support with proper indentation
;; - Integration with markdown-mode for Markdown compatibility
;;
;; Usage:
;; Add the following to your init file:
;;   (require 'altodo)
;;   (add-to-list 'auto-mode-alist '("\\.altodo\\'" . altodo-mode))

;;; Code:

(require 'markdown-mode)
(require 'cl-lib)

;;; Constants and Variables

;; Source code update timestamp
(defconst altodo--updatedtime 1771120742
  "Unix timestamp of last source code update.")

;; Task state constants
(defconst altodo-state-done "x"
  "Character for completed tasks.")

(defconst altodo-state-progress "@"
  "Character for tasks in progress.")

(defconst altodo-state-waiting "w"
  "Character for waiting tasks.")

(defconst altodo-state-cancelled "~"
  "Character for cancelled tasks.")

(defconst altodo-state-open " "
  "Character for open tasks (space).")

;; Flag constants
(defconst altodo-flag-star "+"
  "Character for star flag.")

(defconst altodo-flag-priority "!"
  "Character for priority flag.")

;; Comment marker
(defconst altodo-comment-marker "///"
  "Marker for single-line comments.")

;; Special tag names
(defconst altodo-special-tag-names '("id" "group-start" "group-due" "done")
  "List of special tag names that get special highlighting.
Note: 'dep' is handled separately by altodo--dep-tag-matcher.")

;; Dynamic task regex based on defined state constants
(defconst altodo-task-state-chars
  (concat altodo-state-done altodo-state-progress altodo-state-waiting altodo-state-cancelled)
  "All valid task state characters.")

(defconst altodo-task-regex
  (format "^\\([ ]*\\)\\[\\([%s ]?\\)\\]\\(.*\\)$" 
          (regexp-quote altodo-task-state-chars))
  "Regular expression for matching task lines, dynamically generated from state constants.")

(defconst altodo-comment-regex
  (format "^\\([ \t]*\\)%s \\(.*\\)$" (regexp-quote altodo-comment-marker))
  "Regular expression for matching comment lines, dynamically generated from comment marker.")

;; Dynamic special tag regex
(defconst altodo-special-tag-regex
  (format "\\(?:^\\|[ ]\\)\\(#\\(?:%s\\)\\)\\(?::\\([^[:space:]]+\\)\\)?"
          (mapconcat 'identity altodo-special-tag-names "\\|"))
  "Regular expression for matching special tags, dynamically generated from special tag names.")

;; DSL pattern constants
(defconst altodo--dsl-simple-patterns
  '("done" "progress" "waiting" "open" "cancelled" "priority" "star" "has-multiline-comment")
  "List of valid simple DSL patterns.")

(defconst altodo--dsl-logic-operators-regex
  "\\(and\\|or\\|not\\):"
  "Regular expression for matching DSL logic operators.")

(defconst altodo--dsl-arg-types
  '("tag" "person" "text" "regexp" "level" "heading" "multiline-comment-contains" "due-date" "start-date" "tag-value" "parent-task-regexp" "root-task-regexp")
  "List of valid DSL argument types.")

(defgroup altodo nil
  "Major mode for editing altodo files."
  :prefix "altodo-"
  :group 'text)

;;; Customizable Variables

(defcustom altodo-indent-size 4
  "Number of spaces for indentation."
  :type 'integer
  :group 'altodo)

(defcustom altodo-enable-markdown-in-multiline-comments t
  "When non-nil, enable Markdown formatting in multiline comments.
This includes inline elements (italic, bold, code), lists, and code blocks.
When nil, multiline comments are displayed in a single face without Markdown formatting.

After changing this option, you may need to run \\[font-lock-fontify-buffer]
to see the changes take effect."
  :type 'boolean
  :group 'altodo)

(defcustom altodo-auto-save nil
  "Automatically save file when task state changes."
  :type 'boolean
  :group 'altodo)

(defcustom altodo-skk-wrap-newline t
  "Wrap newline command for SKK compatibility.
When non-nil, check SKK state before executing newline commands.
This prevents unwanted task insertion when using SKK input method."
  :type 'boolean
  :group 'altodo)

(defcustom altodo-sidebar-modeline-enabled t
  "Whether to display filter state in sidebar modeline.
When non-nil, shows current AND/OR mode and selection mode (Single/Multiple)."
  :type 'boolean
  :group 'altodo)

(defcustom altodo-sidebar-dynamic-count-enabled t
  "Whether to dynamically update count when multiple filters are selected.
When t, count is recalculated based on selected filters.
When nil, count shows total matches in buffer."
  :type 'boolean
  :group 'altodo)

(defcustom altodo-debug-mode nil
  "Enable debug mode for altodo.
When non-nil, debug-helper functions are available and debug-helper.el is loaded."
  :type 'boolean
  :group 'altodo
  :set (lambda (symbol value)
         (set-default symbol value)
         ;; Load debug-helper if debug-mode is enabled
         (when value
           (unless (featurep 'debug-helper)
             (let ((debug-helper-path (expand-file-name "debug-helper"
                                                         (file-name-directory (or load-file-name buffer-file-name)))))
               (when (file-exists-p (concat debug-helper-path ".el"))
                 (load debug-helper-path)))))))

(defcustom altodo-font-lock-maximum-decoration t
  "Enable maximum font-lock decoration for altodo-mode."
  :type 'boolean
  :group 'altodo)

(defcustom altodo-done-tag-datetime-format nil
  "Date format for #done tag timestamp.
If nil, uses ISO 8601 format with timezone (YYYY-MM-DDTHH:MM:SS+HH:MM).
If non-nil, uses the same format as `altodo-date-format'.

Examples:
  nil         - 2026-02-10T14:34:00+09:00
  \"%Y/%m/%d\"  - 2026/02/10
  \"%d-%m-%Y\"  - 10-02-2026"
  :type '(choice (const :tag "ISO 8601 with timezone (YYYY-MM-DDTHH:MM:SS+HH:MM)" nil)
                 (string :tag "Custom format (same as altodo-date-format)"))
  :group 'altodo)

(defcustom altodo-use-local-timezone t
  "Whether to use local timezone for #done tag timestamp.
If t, use local timezone (from `current-time-zone').
If nil, use UTC."
  :type 'boolean
  :group 'altodo)

(defcustom altodo-insert-id-format 'tiny-random
  "Format for generated IDs when inserting #id: tag.
  'uuid         - Full UUIDv7 (36 chars): 0698bf56-7d70-7000-aebc-0a374ec80ec5
  'base62       - Base62 encoded UUID (21 chars): CRl6Njdf8iwWyyc32HW2H
  'short        - Short ID, sortable (15 chars): eBnPYIBatZhU1lG
  'short-random - Short ID, random first (15 chars): atZhU1lGeBnPYIB
  'tiny         - Tiny ID, sortable (10 chars): 2C47gz6WJT
  'tiny-random  - Tiny ID, random first (10 chars): 6WJT2C47gz"
  :type '(choice (const :tag "Full UUIDv7 (36 chars)" uuid)
                 (const :tag "Base62 encoded (21 chars)" base62)
                 (const :tag "Short ID, sortable (15 chars)" short)
                 (const :tag "Short ID, random first (15 chars)" short-random)
                 (const :tag "Tiny ID, sortable (10 chars)" tiny)
                 (const :tag "Tiny ID, random first (10 chars)" tiny-random))
  :group 'altodo)

;;; Modeline Variables

(defvar altodo-sidebar-modeline-string ""
  "Current filter state for sidebar modeline display.")

;;; Debug Helper Function

(defun altodo--debug-log (format-string &rest args)
  "Log debug message if `altodo-debug-mode' is non-nil.
Writes directly to log file and *Messages* buffer.

Arguments:
  format-string - format string
  args - format arguments

Returns nil."
  (when altodo-debug-mode
    (let ((message-text (apply #'format format-string args)))
      ;; Write to file
      (when altodo-debug-log-file
        (condition-case err
            (let* ((log-file (substitute-in-file-name altodo-debug-log-file))
                   (log-dir (file-name-directory log-file)))
              (unless (file-exists-p log-dir)
                (let ((inhibit-message t))
                  (make-directory log-dir t)))
              (with-temp-buffer
                (insert (format "[%s] %s\n" (format-time-string "%Y-%m-%dT%H:%M:%S%z") message-text))
                (let ((inhibit-message t))
                  (append-to-file (point-min) (point-max) log-file))))
          (error
           (let ((inhibit-message t))
             (message "DEBUG LOG ERROR: %s (file: %s)" (error-message-string err) altodo-debug-log-file)))))
      ;; Log to *Messages*
      (when altodo-debug-log-to-messages
        (let ((inhibit-message t))
          (message "DEBUG: %s" message-text))))))

;;; Regular Expressions

(defconst altodo-tag-with-value-regex
  "\\(?:^\\|[ \t]\\)\\(#[a-zA-Z0-9_-]+\\):\\(\"[^\"]*\"\\|[^[:space:]]+\\)"
  "Regular expression for matching tags with values.
Matches #tag:value or #tag:\"value with spaces\".
Matches # only when preceded by whitespace or at beginning of line.")

(defconst altodo-tag-without-value-regex
  "\\(?:^\\|[ \t]\\)\\(#[a-zA-Z0-9_-]+\\)\\b"
  "Regular expression for matching tags without values.
Matches # only when preceded by whitespace or at beginning of line.")

(defconst altodo-person-tag-regex
  "\\(?:^\\|[[:space:]]\\)\\(@[^[:space:]]+\\)"
  "Regular expression for matching person/place tags like @smith, @田中.
Matches @ only when preceded by whitespace or at beginning of line.")

(defcustom altodo-date-format nil
  "Date format string for parsing dates.
If nil, uses YYYY-MM-DD format (ISO 8601).
If non-nil, should be a format-time-string compatible format.

Supported format specifiers:
  %Y - 4-digit year
  %m - 2-digit month (01-12)
  %d - 2-digit day (01-31)

Examples:
  nil         - YYYY-MM-DD (2026-02-10)
  \"%Y/%m/%d\"  - YYYY/MM/DD (2026/02/10)
  \"%d-%m-%Y\"  - DD-MM-YYYY (10-02-2026)
  \"%m/%d/%Y\"  - MM/DD/YYYY (02/10/2026)"
  :type '(choice (const :tag "YYYY-MM-DD" nil)
                 (string :tag "Custom format"))
  :group 'altodo)

(defcustom altodo-week-start-day 1
  "Day of week that starts the week (0=Sunday, 1=Monday, ..., 6=Saturday).
Used for 'this-week' filter condition in due-date and start-date filters."
  :type '(choice (const :tag "Sunday" 0)
                 (const :tag "Monday" 1)
                 (const :tag "Tuesday" 2)
                 (const :tag "Wednesday" 3)
                 (const :tag "Thursday" 4)
                 (const :tag "Friday" 5)
                 (const :tag "Saturday" 6))
  :group 'altodo)

;;; Font Lock Keywords

(defface altodo-task-open-face
  '((t :inherit font-lock-function-name-face))
  "Face for open tasks."
  :group 'altodo)

(defface altodo-task-done-face
  '((t :inherit shadow))
  "Face for completed tasks."
  :group 'altodo)

(defface altodo--task-progress-face
  '((t :inherit warning))
  "Face for tasks in progress."
  :group 'altodo)

(defface altodo-task-waiting-face
  '((t :inherit font-lock-builtin-face))
  "Face for waiting tasks."
  :group 'altodo)

(defface altodo-task-cancelled-face
  '((t :inherit shadow))
  "Face for cancelled tasks."
  :group 'altodo)

(defface altodo-task-bracket-face
  '((t :inherit font-lock-keyword-face))
  "Face for task brackets [ ]."
  :group 'altodo)

(defface altodo-task-open-text-face
  '((t :inherit default))
  "Face for open task text."
  :group 'altodo)

;; Sidebar faces
(defface altodo-sidebar-group-header-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for sidebar group headers."
  :group 'altodo)

(defface altodo-sidebar-search-simple-face
  '((t :inherit font-lock-function-name-face))
  "Face for sidebar search-simple entries."
  :group 'altodo)

(defface altodo-sidebar-search-lambda-face
  '((t :inherit font-lock-variable-name-face))
  "Face for sidebar search-lambda entries."
  :group 'altodo)

(defface altodo-sidebar-command-face
  '((t :inherit font-lock-builtin-face))
  "Face for sidebar command entries."
  :group 'altodo)

(defface altodo-sidebar-separator-face
  '((t :inherit shadow))
  "Face for sidebar separators."
  :group 'altodo)

(defface altodo-sidebar-comment-face
  '((t :inherit font-lock-comment-face))
  "Face for sidebar comment entries."
  :group 'altodo)

(defface altodo-sidebar-active-filter-face
  '((t :inherit highlight :weight bold))
  "Face for active filter in sidebar."
  :group 'altodo)

(defface altodo-sidebar-selected-filter-face
  '((t :background "#4a90e2" :foreground "white"))
  "Face for selected filter in multiple selection mode."
  :group 'altodo)

(defface altodo-task-done-text-face
  '((t :inherit shadow :strike-through t))
  "Face for completed task text."
  :group 'altodo)

(defface altodo--task-progress-text-face
  '((t :inherit font-lock-variable-name-face))
  "Face for progress task text."
  :group 'altodo)

(defface altodo-task-waiting-text-face
  '((t :inherit shadow))
  "Face for waiting task text."
  :group 'altodo)

(defface altodo-task-cancelled-text-face
  '((t :inherit shadow :strike-through t))
  "Face for cancelled task text."
  :group 'altodo)

(defface altodo-comment-face
  '((t :inherit font-lock-comment-face))
  "Face for comment lines."
  :group 'altodo)

(defface altodo-flag-star-face
  '((t :inherit warning :weight bold))
  "Face for star flag."
  :group 'altodo)

(defface altodo-flag-priority-face
  '((t :inherit error :weight bold))
  "Face for priority flags."
  :group 'altodo)

;; 優先度レベル別のface定義
(defface altodo-flag-priority1-face
  '((t :inherit warning))
  "Face for single priority flag (!)."
  :group 'altodo)

(defface altodo-flag-priority1-text-face
  '((t :inherit default))
  "Face for text with single priority flag (!)."
  :group 'altodo)

(defface altodo-flag-priority2-face
  '((t :inherit warning :weight bold))
  "Face for double priority flag (!!)."
  :group 'altodo)

(defface altodo-flag-priority2-text-face
  '((t :inherit warning))
  "Face for text with double priority flag (!!)."
  :group 'altodo)

(defface altodo-flag-priority3-face
  '((t :inherit error :weight bold))
  "Face for triple priority flag (!!!)."
  :group 'altodo)

(defface altodo-flag-priority3-text-face
  '((t :inherit error :weight bold))
  "Face for text with triple priority flag (!!!)."
  :group 'altodo)

(defface altodo-flag-star-text-face
  '((t :inherit warning :weight bold))
  "Face for text in starred tasks."
  :group 'altodo)

(defface altodo-flag-priority-text-face
  '((t :inherit error :weight bold))
  "Face for text in priority tasks."
  :group 'altodo)

(defface altodo-tag-face
  '((t :inherit font-lock-keyword-face))
  "Face for tags."
  :group 'altodo)

(defface altodo-tag-value-face
  '((t :inherit font-lock-constant-face))
  "Face for tag values in #name:value format."
  :group 'altodo)

(defface altodo-person-tag-face
  '((t :inherit font-lock-variable-name-face :weight bold))
  "Face for person/place tags like @smith, @田中."
  :group 'altodo)

(defface altodo-dep-blocked-text-face
  '((t :inherit shadow))
  "Face for task text when dependency is not completed (blocked)."
  :group 'altodo)

(defface altodo-dep-blocked-tag-face
  '((t :inherit shadow))
  "Face for #dep: value when dependency is not completed (blocked)."
  :group 'altodo)

(defface altodo-dep-ready-text-face
  '((t :inherit default))
  "Face for task text when all dependencies are completed (ready)."
  :group 'altodo)

(defface altodo-dep-ready-tag-face
  '((t :inherit success))
  "Face for #dep: value when all dependencies are completed (ready)."
  :group 'altodo)

(defface altodo-dep-error-tag-face
  '((t :inherit error :weight bold))
  "Face for #dep: value when circular dependency is detected."
  :group 'altodo)

(defface altodo-special-tag-face
  '((t :inherit font-lock-keyword-face))
  "Face for special tags like #id, #dep, #done."
  :group 'altodo)

(defface altodo-multiline-comment-face
  '((t :inherit font-lock-comment-face))
  "Face for multiline comment lines."
  :group 'altodo)

(defface altodo-multiline-comment-list-marker-face
  '((t :inherit font-lock-type-face :weight bold))
  "Face for list markers in multiline comments."
  :group 'altodo)

(defface altodo-multiline-comment-list-text-face
  '((t :inherit font-lock-comment-face))
  "Face for list text in multiline comments."
  :group 'altodo)

(defface altodo-date-face
  '((t :inherit font-lock-string-face))
  "Face for dates (default)."
  :group 'altodo)

(defface altodo-date-start-active-face
  '((t :inherit warning))
  "Face for active start dates (today or later)."
  :group 'altodo)

(defface altodo-start-not-yet-text-face
  '((t :inherit shadow))
  "Face for task text with start date in the future (not yet started)."
  :group 'altodo)

(defface altodo-date-arrow-face
  '((t :inherit font-lock-builtin-face))
  "Face for date arrow (->)."
  :group 'altodo)

(defface altodo-date-due-overdue-face
  '((t :inherit error :weight bold))
  "Face for overdue due dates."
  :group 'altodo)

(defface altodo-date-due-today-face
  '((t :inherit warning :weight bold))
  "Face for due dates today."
  :group 'altodo)

(defface altodo-date-due-soon-face
  '((t :inherit warning :weight bold))
  "Face for due dates within 3 days (but not today)."
  :group 'altodo)

(defface altodo-due-overdue-severe-text-face
  '((t :inherit error :weight bold))
  "Face for task text with severely overdue due date (3+ days)."
  :group 'altodo)

;; UUID generation
(defconst altodo--base62-chars "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  "Base62 character set.")

(defun altodo--uuid-to-base62 (uuid)
  "Convert UUID string to Base62 encoded string.
UUID can be in format with or without hyphens."
  (let* ((hex (replace-regexp-in-string "-" "" uuid))
         (num (string-to-number hex 16))
         (result ""))
    (while (> num 0)
      (setq result (concat (substring altodo--base62-chars (% num 62) (1+ (% num 62))) result))
      (setq num (/ num 62)))
    (if (string= result "") "0" result)))

(defun altodo--base62-to-uuid (base62)
  "Convert Base62 encoded string back to UUID format."
  (let ((num 0))
    (dotimes (i (length base62))
      (let* ((char (aref base62 i))
             (char-str (char-to-string char))
             (pos (cl-position char altodo--base62-chars)))
        (setq num (+ (* num 62) pos))))
    (let ((hex (format "%032x" num)))
      (format "%s-%s-%s-%s-%s"
              (substring hex 0 8)
              (substring hex 8 12)
              (substring hex 12 16)
              (substring hex 16 20)
              (substring hex 20 32)))))

(defun altodo--generate-uuidv7 ()
  "Generate a UUIDv7 string.
UUIDv7 format (128 bits):
  - 36 bits: Unix timestamp (seconds)
  - 12 bits: millisecond precision (subsec_a)
  - 4 bits: version (0111 = 7)
  - 12 bits: millisecond precision (subsec_b)
  - 2 bits: variant (10)
  - 62 bits: random data

Returns a string in the format: xxxxxxxx-xxxx-7xxx-xxxx-xxxxxxxxxxxx"
  (let* ((time (current-time))
         (unix-sec (truncate (time-to-seconds time)))
         (usec (nth 2 time))
         (msec (/ usec 1000))
         (ts-36 (logand unix-sec #xFFFFFFFFF))
         (msec-12 (logand (/ (* msec 4096) 1000) #xFFF))
         (ts-high (ash ts-36 -4))
         (ts-low-subsec-a (logior (ash (logand ts-36 #xF) 12) msec-12))
         (ver-subsec-b (ash 7 12))
         (var-rand-14 (logior (ash 2 14) (random (expt 2 14))))
         (rand-48 (+ (random (expt 2 16))
                     (ash (random (expt 2 16)) 16)
                     (ash (random (expt 2 16)) 32))))
    (format "%08x-%04x-%04x-%04x-%012x"
            ts-high
            ts-low-subsec-a
            ver-subsec-b
            var-rand-14
            rand-48)))

(defun altodo--generate-custom-short-id ()
  "Generate a custom short ID (12-16 characters).
Format: timestamp (42 bits, 8 chars) + random (48 bits, 9 chars) in Base62.
Total: 12-16 characters depending on value."
  (let* ((time (current-time))
         (unix-ms (+ (* (truncate (time-to-seconds time)) 1000)
                     (/ (nth 2 time) 1000)))
         ;; 42-bit timestamp (milliseconds, ~139 years from epoch)
         (ts-42 (logand unix-ms #x3FFFFFFFFFF))
         ;; 48-bit random
         (rand-48 (+ (random (expt 2 16))
                     (ash (random (expt 2 16)) 16)
                     (ash (random (expt 2 16)) 32)))
         ;; Combine: 90 bits total
         (combined (+ (ash ts-42 48) rand-48))
         (result ""))
    ;; Convert to Base62
    (while (> combined 0)
      (setq result (concat (substring altodo--base62-chars (% combined 62) (1+ (% combined 62))) result))
      (setq combined (/ combined 62)))
    (if (string= result "") "0" result)))

(defun altodo--generate-short-id-sortable ()
  "Generate a sortable short ID (15 characters).
Format: timestamp (42 bits) + random (48 bits) in Base62.
Timestamp comes first for chronological sorting."
  (let* ((time (current-time))
         (unix-ms (+ (* (truncate (time-to-seconds time)) 1000)
                     (/ (nth 2 time) 1000)))
         (ts-42 (logand unix-ms #x3FFFFFFFFFF))
         (rand-48 (+ (random (expt 2 16))
                     (ash (random (expt 2 16)) 16)
                     (ash (random (expt 2 16)) 32)))
         (combined (+ (ash ts-42 48) rand-48))
         (result ""))
    (while (> combined 0)
      (setq result (concat (substring altodo--base62-chars (% combined 62) (1+ (% combined 62))) result))
      (setq combined (/ combined 62)))
    (if (string= result "") "0" result)))

(defun altodo--generate-short-id-random ()
  "Generate a short ID with random first (15 characters).
Format: random (48 bits) + timestamp (42 bits) in Base62.
Random part comes first for better visual distinction."
  (let* ((time (current-time))
         (unix-ms (+ (* (truncate (time-to-seconds time)) 1000)
                     (/ (nth 2 time) 1000)))
         (ts-42 (logand unix-ms #x3FFFFFFFFFF))
         (rand-48 (+ (random (expt 2 16))
                     (ash (random (expt 2 16)) 16)
                     (ash (random (expt 2 16)) 32)))
         (combined (+ (ash rand-48 42) ts-42))
         (result ""))
    (while (> combined 0)
      (setq result (concat (substring altodo--base62-chars (% combined 62) (1+ (% combined 62))) result))
      (setq combined (/ combined 62)))
    (if (string= result "") "0" result)))

(defun altodo--generate-tiny-id-sortable ()
  "Generate a sortable tiny ID (10 characters).
Format: timestamp (32 bits) + random (24 bits) in Base62.
Timestamp comes first for chronological sorting."
  (let* ((unix-sec (truncate (time-to-seconds (current-time))))
         (ts-32 (logand unix-sec #xFFFFFFFF))
         (rand-24 (random (expt 2 24)))
         (combined (+ (ash ts-32 24) rand-24))
         (result ""))
    (while (> combined 0)
      (setq result (concat (substring altodo--base62-chars (% combined 62) (1+ (% combined 62))) result))
      (setq combined (/ combined 62)))
    (if (string= result "") "0" result)))

(defun altodo--generate-tiny-id-random ()
  "Generate a tiny ID with random first (10 characters).
Format: random (24 bits) + timestamp (32 bits) in Base62.
Random part comes first for better visual distinction."
  (let* ((unix-sec (truncate (time-to-seconds (current-time))))
         (ts-32 (logand unix-sec #xFFFFFFFF))
         (rand-24 (random (expt 2 24)))
         (combined (+ (ash rand-24 32) ts-32))
         (result ""))
    (while (> combined 0)
      (setq result (concat (substring altodo--base62-chars (% combined 62) (1+ (% combined 62))) result))
      (setq combined (/ combined 62)))
    (if (string= result "") "0" result)))

(defun altodo--generate-id ()
  "Generate an ID based on `altodo-insert-id-format' setting.
Returns a string in the format specified by `altodo-insert-id-format':
  - uuid: Full UUIDv7 (36 chars)
  - base62: Base62 encoded UUID (21 chars)
  - short: Short ID, sortable (15 chars)
  - short-random: Short ID, random first (15 chars)
  - tiny: Tiny ID, sortable (10 chars)
  - tiny-random: Tiny ID, random first (10 chars)"
  (pcase altodo-insert-id-format
    ('uuid (altodo--generate-uuidv7))
    ('base62 (altodo--uuid-to-base62 (altodo--generate-uuidv7)))
    ('short (altodo--generate-short-id-sortable))
    ('short-random (altodo--generate-short-id-random))
    ('tiny (altodo--generate-tiny-id-sortable))
    ('tiny-random (altodo--generate-tiny-id-random))
    (_ (altodo--generate-tiny-id-random))))

(defun altodo-insert-id ()
  "Insert #id: tag with generated ID at the end of current line.
Returns nil."
  (interactive)
  (if (or (altodo--task-p) (altodo--comment-p))
      (progn
        (save-excursion
          (end-of-line)
          (unless (looking-back " " 1)
            (insert " "))
          (insert "#id:" (altodo--generate-id)))
        (message "Inserted #id tag"))
    (message "Not on a task or comment line")))

;; Dependency checking functions
(defun altodo--find-task-by-id (id)
  "Find task with #id:ID and return its state.
Returns nil if not found, or state character (x, @, w, ~, or space) if found."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward (format "#id:%s\\b" (regexp-quote id)) nil t)
      (beginning-of-line)
      (when (looking-at altodo-task-regex)
        (let ((state (altodo--normalize-state (match-string 2))))
          state)))))

(defun altodo--task-is-completed (state)
  "Check if task state is completed (x or ~).
Returns t if completed, nil otherwise."
  (or (string= state altodo-state-done)
      (string= state altodo-state-cancelled)))

(defun altodo--get-task-id (pos)
  "Get #id: value of task at POS. Returns nil if no #id: tag."
  (save-excursion
    (goto-char pos)
    (beginning-of-line)
    (when (re-search-forward "#id:\\([^[:space:]]+\\)" (line-end-position) t)
      (match-string 1))))

(defun altodo--get-task-deps (pos)
  "Get list of #dep: values from task at POS."
  (save-excursion
    (goto-char pos)
    (beginning-of-line)
    (let ((deps '())
          (line-end (line-end-position)))
      (while (re-search-forward "#dep:\\([^[:space:]]+\\)" line-end t)
        (push (match-string 1) deps))
      (nreverse deps))))

(defun altodo--check-circular-dependency (id &optional visited)
  "Check if ID has circular dependency.
VISITED is a list of IDs already visited in the dependency chain.
Returns t if circular dependency detected, nil otherwise."
  ;; Strip text properties for comparison
  (let ((id-clean (substring-no-properties id)))
    (when (cl-some (lambda (v) (string= id-clean (substring-no-properties v))) visited)
      (throw 'circular 'circular))
    (let ((new-visited (cons id-clean visited)))
      (save-excursion
        (goto-char (point-min))
        (when (re-search-forward (format "#id:%s\\b" (regexp-quote id-clean)) nil t)
          (let ((deps (altodo--get-task-deps (point))))
            (dolist (dep deps)
              (altodo--check-circular-dependency dep new-visited))))))))

(defun altodo--check-all-deps-completed (deps)
  "Check if all dependencies in DEPS list are completed.
Returns:
  'circular - if circular dependency detected
  'blocked  - if any dependency is not completed
  'ready    - if all dependencies are completed or not found"
  (catch 'circular
    (let ((current-id (altodo--get-task-id (point))))
      (when current-id
        (dolist (dep deps)
          (when (altodo--check-circular-dependency dep (list current-id))
            (throw 'circular 'circular)))))
    (catch 'blocked
      (dolist (dep deps)
        (let ((state (altodo--find-task-by-id dep)))
          (when (and state (not (altodo--task-is-completed state)))
            (throw 'blocked 'blocked))))
      'ready)))

;; Simplified helper function for bracket state
(defun altodo--normalize-state (state-str)
  "Normalize task state string, treating space as empty.
Returns normalized state string."
  (if (or (null state-str) (string= state-str " ") (string= state-str ""))
      altodo-state-open
    state-str))

;; Helper function to trim whitespace
;; Helper function for task state faces
(defun altodo--get-state-face (state)
  "Get face for task state.
STATE should be one of the altodo-state-* constants or empty string.
Returns face symbol."
  (unless (stringp state)
    (error "State must be a string, got %s" (type-of state)))
  (cond
   ((string= state altodo-state-done) 'altodo-task-done-face)
   ((string= state altodo-state-progress) 'altodo--task-progress-face)
   ((string= state altodo-state-waiting) 'altodo-task-waiting-face)
   ((string= state altodo-state-cancelled) 'altodo-task-cancelled-face)
   (t 'altodo-task-open-face)))

(defun altodo--get-state-text-face (state)
  "Get text face for task state.
STATE should be one of the altodo-state-* constants or empty string.
Returns face symbol."
  (unless (stringp state)
    (error "State must be a string, got %s" (type-of state)))
  (cond
   ((string= state altodo-state-done) 'altodo-task-done-text-face)
   ((string= state altodo-state-progress) 'altodo--task-progress-text-face)
   ((string= state altodo-state-waiting) 'altodo-task-waiting-text-face)
   ((string= state altodo-state-cancelled) 'altodo-task-cancelled-text-face)
   (t 'altodo-task-open-text-face)))

(defun altodo--get-flag-text-face (flag state)
  "Get combined flag and state text face.
FLAG should contain altodo-flag-* characters.
STATE should be one of the altodo-state-* constants or empty string.
Returns face symbol or face list."
  (unless (stringp flag)
    (error "Flag must be a string, got %s" (type-of flag)))
  (unless (stringp state)
    (error "State must be a string, got %s" (type-of state)))
  (let ((base-face (altodo--get-state-text-face state))
        (flag-face (cond
                    ((string-match-p (regexp-quote altodo-flag-star) flag) 'altodo-star-text-face)
                    ((string-match-p (regexp-quote altodo-flag-priority) flag) 'altodo-priority-text-face)
                    (t nil))))
    (if flag-face
        (list flag-face base-face)
      base-face)))

;;; ============================================================================
;;; Date-based face functions (REWRITTEN 2026-02-10)
;;; ============================================================================
;;; ロールバック方法:
;;; このセクション全体を .kiro/backup/altodo.el.20260210065603 の
;;; 行 379-502 の内容で置き換える
;;; ============================================================================

(defun altodo--format-to-regex (format-str)
  "Convert format-time-string format to regex.
Returns (regex-parse regex-match year-idx month-idx day-idx).
regex-parse: with capture groups for parsing
regex-match: without capture groups for font-lock matching"
  (let ((regex format-str)
        (year-idx 0)
        (month-idx 0)
        (day-idx 0)
        (group-count 0))
    (when (string-match "%Y" regex)
      (setq group-count (1+ group-count))
      (setq year-idx group-count)
      (setq regex (replace-regexp-in-string "%Y" "\\\\([0-9]\\\\{4\\\\}\\\\)" regex t t)))
    (when (string-match "%m" regex)
      (setq group-count (1+ group-count))
      (setq month-idx group-count)
      (setq regex (replace-regexp-in-string "%m" "\\\\([0-9]\\\\{2\\\\}\\\\)" regex t t)))
    (when (string-match "%d" regex)
      (setq group-count (1+ group-count))
      (setq day-idx group-count)
      (setq regex (replace-regexp-in-string "%d" "\\\\([0-9]\\\\{2\\\\}\\\\)" regex t t)))
    (let ((regex-match (replace-regexp-in-string "\\\\(" "\\\\(?:" regex nil t)))
      (list regex regex-match year-idx month-idx day-idx))))

(defun altodo--date-regex-info ()
  "Return date regex info (regex-parse regex-match year-idx month-idx day-idx)."
  (if altodo-date-format
      (altodo--format-to-regex altodo-date-format)
    '("\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)"
      "\\(?:[0-9]\\{4\\}\\)-\\(?:[0-9]\\{2\\}\\)-\\(?:[0-9]\\{2\\}\\)"
      1 2 3)))

(defun altodo--date-regex-match ()
  "Return date regex for matching (for font-lock, without capture groups)."
  (nth 1 (altodo--date-regex-info)))

(defun altodo--parse-date (date-str)
  "Parse date string and return time value.
Returns time value (for use with encode-time/decode-time) or nil if parsing fails."
  (condition-case nil
      (let* ((regex-info (altodo--date-regex-info))
             (regex (nth 0 regex-info))
             (year-idx (nth 2 regex-info))
             (month-idx (nth 3 regex-info))
             (day-idx (nth 4 regex-info)))
        (when (string-match regex date-str)
          (let ((year (string-to-number (match-string year-idx date-str)))
                (month (string-to-number (match-string month-idx date-str)))
                (day (string-to-number (match-string day-idx date-str))))
            (encode-time (list 0 0 0 day month year nil nil nil)))))
    (error nil)))

(defun altodo--today-start ()
  "Return today's start time (00:00:00) in local timezone.
Returns time value."
  (let ((today-decoded (decode-time (current-time))))
    (encode-time (list 0 0 0 
                       (nth 3 today-decoded)
                       (nth 4 today-decoded)
                       (nth 5 today-decoded)
                       nil nil nil))))

(defun altodo--days-diff (date-time)
  "Calculate days difference between DATE-TIME and today.
Positive means future, negative means past.
Returns number (float)."
  (/ (- (time-to-seconds date-time)
        (time-to-seconds (altodo--today-start)))
     86400.0))

(defun altodo--determine-start-date-face (date-str)
  "Determine face for start date.
Returns yellow if started, blue if not yet started.
Returns face symbol."
  (let ((date-time (altodo--parse-date date-str)))
    (if (and date-time (<= (altodo--days-diff date-time) 0))
        'altodo-date-start-active-face
      'altodo-date-face)))

(defun altodo--determine-due-date-face (date-str)
  "Determine face for due date.
Returns appropriate face based on how close the deadline is.
Returns face symbol."
  (let ((date-time (altodo--parse-date date-str)))
    (if (not date-time)
        'altodo-date-face
      (let ((days-diff (altodo--days-diff date-time)))
        (cond
         ((< days-diff 0) 'altodo-date-due-overdue-face)
         ((< days-diff 1) 'altodo-date-due-today-face)
         ((<= days-diff 3) 'altodo-date-due-soon-face)
         (t 'altodo-date-face))))))

(defun altodo--start-date-matcher (limit)
  "Match start dates (DATE ->) up to LIMIT.
Requires exactly one space before ->, and space or end-of-line after ->."
  (let ((regex (concat "\\(" (altodo--date-regex-match) "\\) " (regexp-quote "->") "\\(?: \\|$\\)")))
    (re-search-forward regex limit t)))

(defun altodo--due-date-matcher (limit)
  "Match due dates (-> DATE) up to LIMIT.
Requires exactly one space before and after ->, or end-of-line after DATE."
  (let ((regex (concat " " (regexp-quote "->") " \\(" (altodo--date-regex-match) "\\)\\(?: \\|$\\)")))
    (re-search-forward regex limit t)))

(defun altodo--arrow-matcher (limit)
  "Match arrows (->) up to LIMIT.
Requires exactly one space before ->, and space or end-of-line after ->.
Matches 'DATE -> DATE', 'DATE -> ', or ' -> DATE' pattern.
Does NOT match bare '->' without dates."
  (let ((date-regex (altodo--date-regex-match)))
    (re-search-forward 
     (concat "\\(" date-regex " " (regexp-quote "->") "\\|" (regexp-quote "->") " " date-regex "\\)")
     limit t)))


(defun altodo--tag-matcher (limit)
  "Match tags on task/comment/multiline-comment lines only up to LIMIT."
  (catch 'found
    (let ((max-iterations 1000)
          (iterations 0))
      (while (and (< (point) limit) (not (eobp)) (< iterations max-iterations))
        (setq iterations (1+ iterations))
        (if (re-search-forward "\\(?:^\\|[ \t]\\)\\(#[a-zA-Z0-9_-]+\\)\\b" limit t)
            (let ((on-valid-line
                   (save-match-data
                     (save-excursion
                       (beginning-of-line)
                       (or (looking-at altodo-task-regex)
                           (looking-at altodo-comment-regex)
                           (altodo--multiline-comment-p))))))
              (if on-valid-line
                  (throw 'found t)
                ;; Not on valid line, continue searching
                nil))
          ;; No more matches
          (goto-char limit)
          (throw 'found nil)))
      (when (>= iterations max-iterations)
        (goto-char limit)))
    nil))

(defun altodo--tag-with-value-matcher (limit)
  "Match tags with values on task/comment/multiline-comment lines only up to LIMIT."
  (catch 'found
    (let ((max-iterations 1000)
          (iterations 0))
      (while (and (< (point) limit) (not (eobp)) (< iterations max-iterations))
        (setq iterations (1+ iterations))
        (if (re-search-forward "\\(?:^\\|[ \t]\\)\\(#[a-zA-Z0-9_-]+\\):\\([^[:space:]]+\\)" limit t)
            (let ((on-valid-line
                   (save-match-data
                     (save-excursion
                       (beginning-of-line)
                       (or (looking-at altodo-task-regex)
                           (looking-at altodo-comment-regex)
                           (altodo--multiline-comment-p))))))
              (if on-valid-line
                  (throw 'found t)
                ;; Not on valid line, continue searching
                nil))
          ;; No more matches
          (goto-char limit)
          (throw 'found nil)))
      (when (>= iterations max-iterations)
        (goto-char limit)))
    nil))

(defun altodo--dep-tag-matcher (limit)
  "Match #dep: tags and determine their state (blocked/ready/error) up to LIMIT.
Applies face to the tag name (#dep:) and value separately."
  (catch 'found
    (let ((start-point (point))
          (max-iterations 1000)
          (iterations 0))
      (while (and (< (point) limit) (not (eobp)) (< iterations max-iterations))
        (setq iterations (1+ iterations))
        (when (re-search-forward "#dep:\\([^[:space:]]+\\)" limit t)
          (let* ((tag-start (match-beginning 0))
                 (tag-end (match-end 0))
                 (value-start (match-beginning 1))
                 (value-end (match-end 1))
                 (line-start (save-excursion (beginning-of-line) (point)))
                 (deps (altodo--get-task-deps line-start))
                 (status (altodo--check-all-deps-completed deps)))
            ;; Set match data for the value part only
            (set-match-data (list value-start value-end value-start value-end))
            (put-text-property value-start value-end 'altodo-dep-status status)
            (throw 'found t))))
      (when (>= iterations max-iterations)
        (goto-char limit)))
    nil))

(defun altodo--dep-blocked-text-matcher (limit)
  "Match task text with blocked dependencies up to LIMIT."
  (catch 'found
    (let ((max-iterations 1000)
          (iterations 0))
      (while (and (< (point) limit) (not (eobp)) (< iterations max-iterations))
        (setq iterations (1+ iterations))
        (when (re-search-forward "^[ ]*\\[.\\][ ]*\\(.*\\)$" limit t)
          (let* ((text-start (match-beginning 1))
                 (text-end (match-end 1))
                 (line-start (save-excursion (beginning-of-line) (point)))
                 (deps (altodo--get-task-deps line-start)))
            (if (and deps (eq (altodo--check-all-deps-completed deps) 'blocked))
                (progn
                  (set-match-data (list text-start text-end text-start text-end))
                  (throw 'found t))
              (goto-char (1+ text-end))))))
      (when (>= iterations max-iterations)
        (goto-char limit)))
    nil))

(defun altodo--is-valid-person-tag-position (match-start)
  "Check if MATCH-START is a valid position for a person tag.
Returns t if:
  - @ is at line start, or
  - @ is preceded by whitespace
  - @ is not in a URL"
  (let* ((prev-char (char-before match-start))
         (face-at-point (get-text-property match-start 'face))
         (face-list (if (listp face-at-point) face-at-point (list face-at-point))))
    (and (not (memq 'markdown-url-face face-list))
         (not (memq 'markdown-plain-url-face face-list))
         (or (not prev-char)
             (memq prev-char '(?\s ?\t ?\n))))))

(defun altodo--person-tag-matcher (limit)
  "Match @person tags up to LIMIT.
Only matches @ when preceded by whitespace or at beginning of line.
Skips @ in URLs (where markdown-url-face or markdown-plain-url-face is applied)."
  (catch 'found
    (let ((max-iterations 1000)
          (iterations 0)
          (regex (altodo--person-tag-regex)))
      (while (and (< (point) limit) (< iterations max-iterations))
        (setq iterations (1+ iterations))
        (if (re-search-forward regex limit t)
            (let ((match-start (match-beginning 0))
                  (match-end (match-end 0)))
              (if (altodo--is-valid-person-tag-position match-start)
                  (progn
                    (set-match-data (list match-start match-end match-start match-end))
                    (throw 'found t))))
          (goto-char limit)
          (throw 'found nil)))
      (when (>= iterations max-iterations)
        (goto-char limit)
        nil))))


(defun altodo--due-overdue-severe-text-matcher (limit)
  "Match task lines with severely overdue due dates (3+ days) up to LIMIT."
  (catch 'found
    (while (and (< (point) limit) (not (eobp)))
      (if (re-search-forward "^[ ]*\\[.\\][ ]*\\(.*\\)$" limit t)
          (let ((line-text (match-string 1))
                (text-start (match-beginning 1))
                (text-end (match-end 1)))
            ;; Check for valid format: " -> DATE"
            (if (string-match (concat " " (regexp-quote "->") " \\(" (altodo--date-regex-match) "\\)") line-text)
                (let ((due-time (altodo--parse-date (match-string 1 line-text))))
                  (if (and due-time (< (altodo--days-diff due-time) -2))
                      (progn
                        (set-match-data (list text-start text-end text-start text-end))
                        (throw 'found t))
                    (goto-char (1+ text-end))))
              (goto-char (1+ text-end))))
        (goto-char limit)))
    nil))

(defun altodo--start-not-yet-text-matcher (limit)
  "Match task lines with start date in the future (not yet started) up to LIMIT."
  (catch 'found
    (while (and (< (point) limit) (not (eobp)))
      (if (re-search-forward "^[ ]*\\[.\\][ ]*" limit t)
          (let ((text-start (point))
                (line-end (line-end-position)))
            (goto-char text-start)
            ;; Search for "DATE -> " or "DATE ->" pattern anywhere in the line
            (if (re-search-forward (concat "\\(" (altodo--date-regex-match) "\\) " (regexp-quote "->") "\\(?: \\|$\\)") line-end t)
                (let ((start-time (altodo--parse-date (match-string 1))))
                  (if (and start-time (> (altodo--days-diff start-time) 0))
                      (progn
                        (set-match-data (list text-start line-end text-start line-end))
                        (goto-char (1+ line-end))
                        (throw 'found t))
                    (goto-char (1+ line-end))))
              (goto-char (1+ line-end))))
        (goto-char limit)))
    nil))

;;; ============================================================================
;;; End of Date-based face functions
;;; ============================================================================

;;; ============================================================================
;;; End of Date-based face functions
;;; ============================================================================

(defun altodo--restore-code-block-faces (beg end)
  "Restore markdown faces in code blocks between BEG and END.
Overwrites altodo faces with markdown-pre-face and markdown-code-face."
  (save-excursion
    (goto-char beg)
    (while (< (point) end)
      (when (markdown-code-block-at-point-p)
        (put-text-property (line-beginning-position) (line-end-position)
                           'face '(markdown-pre-face markdown-code-face)))
      (forward-line 1))))

;; Font-lock keywords for altodo-mode
(defun altodo-font-lock-keywords ()
  "Generate font lock keywords for altodo-mode.
Processing order: brackets -> base text -> tags/dates -> emphasis/flags -> priority.
Flags override tags to ensure consistent highlighting."
  `(
    ;; ========================================
    ;; Layer 1: タスクブラケット
    ;; ========================================
    
    ;; 1. タスクブラケットと状態文字
    ("^[ ]*\\(\\[\\)\\(.\\)\\(\\]\\)"
     (1 'altodo-task-bracket-face t)
     (2 (let ((state-char (match-string 2)))
          (let ((blocked-p (save-match-data
                             (or (altodo--line-seq-tasks-blocked-p)
                                 (altodo--is-seq-tasks-child-blocked-p)))))
            (if blocked-p
                'altodo-dep-blocked-text-face
              (altodo--get-state-face (altodo--normalize-state state-char)))))
        t)
     (3 'altodo-task-bracket-face t))
    
    ;; ========================================
    ;; Layer 2: ベース（本文全体）- 広い範囲
    ;; ========================================
    
    ;; 2.5. seq-tasks blocked タスク本文（先に処理）
    ("^[ ]*\\[ \\][ ]*\\(.*\\)$" .
     (1 (let ((blocked-p (save-match-data
                           (or (altodo--line-seq-tasks-blocked-p)
                               (altodo--is-seq-tasks-child-blocked-p)))))
          (if blocked-p
              'altodo-task-waiting-text-face
            nil))
        append))
    
    ;; 2. 通常タスク本文（フラグなし）（後に処理）
    ("^[ ]*\\[ \\][ ]*\\(.*\\)$" . 
     (1 'altodo-task-open-text-face append))
    
    ;; 3. 待機タスク本文
    (,(format "^[ ]*\\[%s\\][ ]*\\(.*\\)$" (regexp-quote altodo-state-waiting)) . 
     (1 'altodo-task-waiting-text-face append))

    ;; 4. 進行中タスク本文
    (,(format "^[ ]*\\[%s\\][ ]*\\(.*\\)$" (regexp-quote altodo-state-progress)) . 
     (1 'altodo--task-progress-text-face append))
    
    ;; ========================================
    ;; Layer 3: 部分要素（タグ、日付など）- 狭い範囲
    ;; ========================================
    
    ;; （タグは Layer 4 に移動）
    
    ;; ========================================
    ;; Layer 4: 強調要素（日付ベーステキスト、フラグ本文、タグ）
    ;; タグより後に配置してタグを上書き
    ;; ========================================
    
    ;; 5. 日付ベーステキスト（本文全体の色変更）
    (altodo--dep-blocked-text-matcher . (1 'altodo-dep-blocked-text-face prepend))
    (altodo--due-overdue-severe-text-matcher . (1 'altodo-due-overdue-severe-text-face prepend))
    (altodo--start-not-yet-text-matcher . (1 'altodo-start-not-yet-text-face prepend))
    
    ;; 6. 優先度フラグ（3段階）
    (,(format "^[ ]*\\[.\\][ ]*\\(%s\\{3,\\}\\) \\(.*\\)" (regexp-quote altodo-flag-priority)) .
     ((1 'altodo-flag-priority3-face t)
      (2 'altodo-flag-priority3-text-face prepend)))
    
    (,(format "^[ ]*\\[.\\][ ]*\\(%s\\{2\\}\\) \\(.*\\)" (regexp-quote altodo-flag-priority)) .
     ((1 'altodo-flag-priority2-face t)
      (2 'altodo-flag-priority2-text-face prepend)))
    
    (,(format "^[ ]*\\[.\\][ ]*\\(%s\\) \\(.*\\)" (regexp-quote altodo-flag-priority)) .
     ((1 'altodo-flag-priority1-face t)
      (2 'altodo-flag-priority1-text-face prepend)))
    
    ;; 7. スターフラグ
    (,(format "^[ ]*\\[.\\][ ]*\\(%s\\) \\(.*\\)" (regexp-quote altodo-flag-star)) .
     ((1 'altodo-flag-star-face t)
      (2 'altodo-flag-star-text-face prepend)))
    
    ;; 8. 一般タグ（値付き）- 日付ベーステキストとフラグの後に配置
    (altodo--tag-with-value-matcher . ((1 'altodo-tag-face t)
                                       (2 'altodo-tag-value-face t)))
    
    ;; 9. 一般タグ（値なし）- 日付ベーステキストとフラグの後に配置
    (altodo--tag-matcher . (1 'altodo-tag-face t))
    
    ;; 10. @person タグ - 日付ベーステキストとフラグの後に配置
    (altodo--person-tag-matcher (0 'altodo-person-tag-face t))
    
    ;; 11. 特殊タグ - 日付ベーステキストとフラグの後に配置
    (,altodo-special-tag-regex . ((1 'altodo-special-tag-face t)
                                  (2 'altodo-tag-value-face t t)))

    ;; 12. #dep: タグ名部分 - 日付ベーステキストとフラグの後に配置
    ("#dep:" . (0 'altodo-special-tag-face t))
    
    ;; 13. 依存関係タグの値部分 - 日付ベーステキストとフラグの後に配置
    (altodo--dep-tag-matcher . 
     (0 (let ((status (get-text-property (match-beginning 0) 'altodo-dep-status)))
          (cond
           ((eq status 'circular) 'altodo-dep-error-tag-face)
           ((eq status 'blocked) 'altodo-dep-blocked-tag-face)
           ((eq status 'ready) 'altodo-dep-ready-tag-face)
           (t 'altodo-tag-value-face)))
        t))
    
    ;; 14. 日付の矢印（日付の前に配置して矢印を先に処理）
    (altodo--arrow-matcher . (0 'altodo-date-arrow-face t))
    
    ;; 15. 開始日（フラグの後に配置してフラグ本文を上書き）
    (altodo--start-date-matcher . (1 (altodo--determine-start-date-face (match-string 1)) t))
    
    ;; 16. 期限（フラグの後に配置してフラグ本文を上書き）
    (altodo--due-date-matcher . (1 (altodo--determine-due-date-face (match-string 1)) t))
    
    ;; ========================================
    ;; Layer 5: 最優先（コメント全体、斜線）
    ;; ========================================
    
    ;; 18. 複数行コメント
    (altodo--multiline-comment-matcher-new . (0 'altodo-multiline-comment-face prepend))

    ;; 19. 複数行コメント内リスト
    (altodo--multiline-comment-list-matcher .
     ((1 'altodo-multiline-comment-list-marker-face prepend)
      (2 'altodo-multiline-comment-list-text-face prepend)))
    
    ;; 20. 1行コメント全体
    (,(format "^\\([ \t]*\\)\\(%s\\) \\(.*\\)$" (regexp-quote altodo-comment-marker)) .
     ((1 'altodo-comment-face prepend)
      (2 'altodo-comment-face prepend)
      (3 'altodo-comment-face prepend)))
    
    ;; 21. 完了・廃止タスクの斜線
    (,(format "^[ ]*\\[%s\\][ ]*\\(.*\\)$" (regexp-quote altodo-state-done)) . 
     (1 'altodo-task-done-text-face t))
    (,(format "^[ ]*\\[%s\\][ ]*\\(.*\\)$" (regexp-quote altodo-state-cancelled)) . 
     (1 'altodo-task-cancelled-text-face t))))

;;; Keymap

(defvar-keymap altodo-mode-map
  :doc "Keymap for altodo-mode."
  :parent markdown-mode-map
  "TAB" #'altodo-indent-line
  "RET" #'altodo-enter
  "<backtab>" #'outline-cycle
  "C-c C-x" (lambda () (interactive) (if (altodo--task-p) (altodo-toggle-task-state) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-t o" (lambda () (interactive) (if (altodo--task-p) (altodo-set-task-open) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-t x" (lambda () (interactive) (if (altodo--task-p) (altodo-set-task-done) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-t @" (lambda () (interactive) (if (altodo--task-p) (altodo-set-task-progress) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-t w" (lambda () (interactive) (if (altodo--task-p) (altodo-set-task-waiting) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-t ~" (lambda () (interactive) (if (altodo--task-p) (altodo-set-task-cancelled) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-t d" (lambda () (interactive) (if (altodo--task-p) (altodo-move-done-tasks-at-point) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-a" (lambda () (interactive) (if (or (altodo--task-p) (altodo--comment-p)) (altodo-add-task) (altodo--call-parent-command (this-command-keys-vector))))
  "M-RET" (lambda () (interactive) (if (or (altodo--task-p) (altodo--comment-p)) (altodo-add-subtask) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-m" (lambda () (interactive) (if (or (altodo--task-p) (altodo--comment-p)) (altodo-start-multiline-comment) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-s" (lambda () (interactive) (if (or (altodo--task-p) (altodo--comment-p)) (altodo-toggle-star-flag) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-f 1" (lambda () (interactive) (if (or (altodo--task-p) (altodo--comment-p)) (altodo-set-priority-1) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-f 2" (lambda () (interactive) (if (or (altodo--task-p) (altodo--comment-p)) (altodo-set-priority-2) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-f 3" (lambda () (interactive) (if (or (altodo--task-p) (altodo--comment-p)) (altodo-set-priority-3) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-i" (lambda () (interactive) (if (or (altodo--task-p) (altodo--comment-p)) (altodo-insert-id) (altodo--call-parent-command (this-command-keys-vector))))
  "M-<right>" (lambda () (interactive) (if (or (altodo--task-p) (altodo--comment-p) (altodo--multiline-comment-p)) (altodo-indent-increase) (altodo--call-parent-command (this-command-keys-vector))))
  "M-<left>" (lambda () (interactive) (if (or (altodo--task-p) (altodo--comment-p) (altodo--multiline-comment-p)) (altodo-indent-decrease) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-v f c" (lambda () (interactive) (if (or (altodo--task-p) (altodo--comment-p)) (altodo-filter-clear) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-v s t" (lambda () (interactive) (if (or (altodo--task-p) (altodo--comment-p)) (altodo-sidebar-toggle) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-v s r" (lambda () (interactive) (if (or (altodo--task-p) (altodo--comment-p)) (altodo-sidebar-refresh) (altodo--call-parent-command (this-command-keys-vector))))
  "C-c C-j" (lambda () (interactive) (if (or (altodo--task-p) (altodo--comment-p)) (altodo-goto-dependency) (altodo--call-parent-command (this-command-keys-vector)))))

;;; Mode Definition

;;;###autoload
(define-derived-mode altodo-mode markdown-mode "altodo"
  "Major mode for editing altodo files.

altodo-mode is derived from markdown-mode and provides additional
functionality for managing TODO items with task states, flags,
tags, and dates.

\\{altodo-mode-map}"
  :group 'altodo
  
  ;; === markdown-mode の GFM チェックボックス機能を完全に無効化 ===
  
  ;; 1. 変数を無効化（将来の動作を防ぐ）
  (setq-local markdown-make-gfm-checkboxes-buttons nil)
  
  ;; 2. フックを削除（動的更新を防ぐ）
  (remove-hook 'after-change-functions 
               #'markdown-gfm-checkbox-after-change-function t)
  
  ;; 3. 既存のオーバーレイを削除（既に作成されたボタンを削除）
  (remove-overlays (point-min) (point-max) 
                   'type 'markdown-gfm-checkbox-button)
  
  ;; === その他の markdown-mode 設定 ===
  (setq-local markdown-hide-markup nil)
  
  ;; === altodo-mode の設定 ===
  ;;; ロールバック方法:
  ;;; このセクションを .kiro/backup/altodo.el.20260210065603 の該当部分で置き換える
  
  ;; Add altodo font-lock keywords after markdown keywords
  ;; This allows markdown inline elements (bold, italic, etc.) to be applied first,
  ;; then altodo faces are added as base colors
  (font-lock-add-keywords nil (altodo-font-lock-keywords) 'append)
  (setq-local indent-line-function #'altodo-indent-line)
  
  ;; Enable font-lock-multiline (already set by markdown-mode, but ensure it)
  (setq-local font-lock-multiline t)
  
  ;; Disable markdown-mode's indented code block highlighting
  ;; markdown-mode treats 4-space indented lines as code blocks (markdown-pre-face)
  ;; which conflicts with altodo's indented task/comment lines
  (font-lock-remove-keywords nil '((markdown-match-pre-blocks (0 'markdown-pre-face))))
  
  ;; Restore markdown faces in code blocks after altodo fontification
  (let ((orig-fn font-lock-fontify-region-function))
    (setq-local font-lock-fontify-region-function
                (lambda (beg end &optional loudly)
                  (funcall orig-fn beg end loudly)
                  (altodo--restore-code-block-faces beg end))))
  
  ;; Restart font-lock-mode to ensure keywords are applied immediately
  ;; This is the standard pattern for derived modes that add font-lock keywords
  (when (and (boundp 'font-lock-mode) font-lock-mode)
    (font-lock-mode -1)
    (font-lock-mode 1)
    ;; Force refontification
    (font-lock-fontify-buffer))
  
  ;; Set up outline mode for folding (extends markdown-mode's outline)
  
  ;; Add auto-move status to mode line
  (when altodo-show-auto-move-in-mode-line
    (setq-local mode-line-misc-info
                (append mode-line-misc-info
                        '((:eval (when altodo--auto-move-timer " [auto-move]"))))))
  ;; Support both markdown headers and altodo tasks/comments/multiline-comments
  (setq-local outline-regexp
              (concat "\\(?:" markdown-regex-header "\\)"
                      "\\|"
                      "\\(?:^[ ]*\\[.\\]\\)"      ; Task lines
                      "\\|"
                      "\\(?:^[ ]*///\\)"          ; Comment lines
                      "\\|"
                      "\\(?:^[ \t]+[^ \t\n]\\)")) ; Multiline comment first line
  (setq-local outline-level #'altodo--outline-level)
  (setq-local outline-heading-end-regexp "\n")
  (outline-minor-mode 1)
  (setq-local minor-mode-alist
              (delete '(outline-minor-mode " Outl") minor-mode-alist))
  
  ;; Force font-lock refresh after all configurations
  (when font-lock-mode
    (font-lock-mode -1)
    (font-lock-mode 1))
  
  ;; Initialize filter system
  (altodo--filter-init)
  
  ;; Phase 2-1: Clean up sidebar buffer when source buffer is killed
  (add-hook 'kill-buffer-hook #'altodo-sidebar--on-source-buffer-kill nil t)
  
  ;; Phase 2-2: Update sidebar when file is saved
  (add-hook 'after-save-hook #'altodo-sidebar-refresh nil t))

;;; Interactive Commands

;;; Helper function for keymap fallback

(defun altodo--call-parent-command (key)
  "Call parent mode command for KEY.
If parent binding is a keymap (prefix key), read next key and execute.
If no parent binding exists, do nothing."
  (let* ((parent-map (keymap-parent (current-local-map)))
         (parent-binding (when parent-map (lookup-key parent-map key))))
    (cond
     ;; Parent binding is a command
     ((commandp parent-binding)
      (call-interactively parent-binding))
     ;; Parent binding is a keymap (prefix key)
     ((keymapp parent-binding)
      (let* ((next-key (read-key-sequence 
                        (format "%s " (key-description key))))
             (full-key (vconcat key next-key))
             (cmd (lookup-key parent-map full-key)))
        (when (commandp cmd)
          (call-interactively cmd))))
     ;; No parent binding - do nothing
     (t nil))))
(defun altodo-toggle-task-state ()
  "Toggle task state between open and done.
Returns nil."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (if (looking-at altodo-task-regex)
        (let ((state (match-string 2)))
          (cond
           ((or (string= state altodo-state-open) (string= state " "))
            (altodo-set-task-done))
           ((string= state altodo-state-done)
            (altodo-set-task-open))
           (t
            (altodo-set-task-done))))
      (message "Not on a task line"))))

(defun altodo-set-task-open ()
  "Set current task to open state.
Returns nil."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (if (looking-at altodo-task-regex)
        (progn
          (altodo--set-task-state altodo-state-open)
          (altodo--remove-done-tag))
      (message "Not on a task line"))))

(defun altodo-set-task-done ()
  "Set current task to done state.
Returns nil."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (if (looking-at altodo-task-regex)
        (progn
          (altodo--set-task-state altodo-state-done)
          (altodo--add-done-tag))
      (message "Not on a task line"))))

(defun altodo-set-task-progress ()
  "Set current task to progress state.
Returns nil."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (if (looking-at altodo-task-regex)
        (altodo--set-task-state altodo-state-progress)
      (message "Not on a task line"))))

(defun altodo-set-task-waiting ()
  "Set current task to waiting state.
Returns nil."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (if (looking-at altodo-task-regex)
        (altodo--set-task-state altodo-state-waiting)
      (message "Not on a task line"))))

(defun altodo-set-task-cancelled ()
  "Set current task to cancelled state.
Returns nil."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (if (looking-at altodo-task-regex)
        (progn
          (altodo--set-task-state altodo-state-cancelled)
          (altodo--add-done-tag))
      (message "Not on a task line"))))

(defun altodo-indent-increase ()
  "Increase indentation of current line or region.
Returns value."
  (interactive)
  (if (or (altodo--task-p) (altodo--comment-p) (altodo--multiline-comment-p))
      (if (use-region-p)
          (let ((start (region-beginning))
                (end (region-end)))
            (save-excursion
              (goto-char start)
              (while (< (point) end)
                (beginning-of-line)
                (insert (make-string altodo-indent-size ?\s))
                (forward-line 1)
                (setq end (+ end altodo-indent-size))))
            (altodo--reset-indent-flags))
        (beginning-of-line)
        (insert (make-string altodo-indent-size ?\s))
        (altodo--reset-indent-flags))
    (message "Not on a task, comment, or multiline comment line")))

(defun altodo-indent-decrease ()
  "Decrease indentation of current line or region.
Returns value."
  (interactive)
  (if (or (altodo--task-p) (altodo--comment-p) (altodo--multiline-comment-p))
      (if (use-region-p)
          (let ((start (region-beginning))
                (end (region-end)))
            (save-excursion
              (goto-char start)
              (while (< (point) end)
                (let ((current-indent (altodo--get-current-indent)))
                  (when (>= current-indent altodo-indent-size)
                    (beginning-of-line)
                    (delete-char altodo-indent-size)
                    (setq end (- end altodo-indent-size))))
                (forward-line 1)))
            (altodo--reset-indent-flags))
        (let ((current-indent (altodo--get-current-indent)))
          (when (>= current-indent altodo-indent-size)
            (beginning-of-line)
            (delete-char altodo-indent-size)
            (altodo--reset-indent-flags))))
    (message "Not on a task, comment, or multiline comment line")))

;;; Utility Functions

;; === Outline 関数 ===

(defun altodo--outline-level ()
  "Return the outline level for the current line.
Supports both markdown headers and altodo tasks/comments/multiline-comments."
  (save-excursion
    (beginning-of-line)
    (cond
     ;; Markdown headers (# ## ### etc.)
     ((looking-at markdown-regex-header)
      (markdown-outline-level))
     ;; Altodo tasks or comments (indentation-based)
     ((looking-at "^\\([ ]*\\)\\(?:\\[.\\]\\|///\\)")
      (1+ (/ (length (match-string 1)) altodo-indent-size)))
     ;; Multiline comment lines (indentation-based, simple check)
     ((and (looking-at "^\\([ \t]+\\)")
           (not (looking-at altodo-task-regex))
           (not (looking-at altodo-comment-regex)))
      (1+ (/ (length (match-string 1)) altodo-indent-size)))
     ;; Default
     (t 1))))

;; === 複数行コメント判定関数 ===

(defun altodo--has-task-or-comment-above ()
  "Check if there is a task or comment line above.
Recursively checks through empty lines and multiline comments."
  (save-excursion
    (let ((max-depth 100)
          (depth 0))
      (forward-line -1)
      (while (and (not (bobp)) 
                  (< depth max-depth)
                  (looking-at "^[ \t]+"))
        (cond
         ;; 空行（インデントのみ）をスキップ
         ((looking-at "^[ \t]*$")
          (forward-line -1)
          (setq depth (1+ depth)))
         ;; タスク行・コメント行でない = 複数行コメント
         ((and (not (looking-at altodo-task-regex))
               (not (looking-at altodo-comment-regex)))
          (forward-line -1)
          (setq depth (1+ depth)))
         ;; それ以外は終了
         (t
          (setq depth max-depth))))
      (or (looking-at altodo-task-regex)
          (looking-at altodo-comment-regex)))))

(defun altodo--multiline-comment-matcher-new (limit)
  "Match multiline comments up to LIMIT using direct pattern matching.
Excludes markdown list items."
  (catch 'found
    (while (and (< (point) limit) (not (eobp)))
      (if (and (looking-at "^[ \t]+[^ \t\n[]")
               (not (looking-at altodo-task-regex))
               (not (looking-at altodo-comment-regex))
               (not (looking-at "^[ \t]*[-*+][ \t]"))      ; markdown unordered list
               (not (looking-at "^[ \t]*[0-9]+\\.[ \t]"))) ; markdown ordered list
          (if (altodo--has-task-or-comment-above)
              (let ((line-start (point))
                    (line-end (line-end-position)))
                (set-match-data (list line-start line-end))
                (goto-char (1+ line-end))
                (throw 'found t))
            (forward-line 1))
        (forward-line 1)))
    nil))

;; === Helper functions ===

(defun altodo--multiline-comment-p ()
  "Check if current line is a multiline comment.
Includes empty lines with indentation that belong to a multiline comment block.
Returns nil if in a code block.
Returns t if current line is a multiline comment, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (and (not (markdown-code-block-at-point-p))
         (not (looking-at altodo-task-regex))
         (not (looking-at altodo-comment-regex))
         (looking-at "^[ \t]+")
         (not (looking-at "^[ \t]*[-*+][ \t]"))      ; exclude markdown list
         (not (looking-at "^[ \t]*[0-9]+\\.[ \t]"))  ; exclude markdown list
         (altodo--has-task-or-comment-above))))

(defun altodo--multiline-comment-matcher (limit)
  "Font-lock matcher for multiline comments up to LIMIT."
  (altodo--multiline-comment-matcher-new limit))

(defun altodo--multiline-comment-list-matcher (limit)
  "Match list items in multiline comments up to LIMIT.
Only matches when `altodo-enable-markdown-in-multiline-comments' is non-nil."
  (when altodo-enable-markdown-in-multiline-comments
    (catch 'found
      (while (and (< (point) limit) (not (eobp)))
        (if (re-search-forward "^[ \t]+\\([-*+]\\|[0-9]+\\.\\)[ \t]+\\(.*\\)$" limit t)
            (save-excursion
              (beginning-of-line)
              (if (and (not (looking-at altodo-task-regex))
                       (not (looking-at altodo-comment-regex))
                       (altodo--multiline-comment-p))  ; 複数行コメント内のみ
                  (throw 'found t)
                (goto-char (match-end 0))))
          (goto-char limit)))
      nil)))

(defun altodo--set-task-state (state)
  "Set task state at current point to STATE."
  (save-excursion
    (beginning-of-line)
    (when (looking-at altodo-task-regex)
      (replace-match state nil nil nil 2)
      (when altodo-auto-save
        (save-buffer)))))

(defun altodo--add-done-tag ()
  "Add #done tag with current timestamp in ISO 8601 format with timezone."
  (save-excursion
    (end-of-line)
    (unless (looking-back "#done:[0-9/:T+-]+" (line-beginning-position))
      (let* ((now (current-time))
             (use-local altodo-use-local-timezone)
             (tz-info (when use-local (current-time-zone now)))
             (offset-seconds (if use-local (car tz-info) 0))
             (offset-hours (/ offset-seconds 3600))
             (offset-minutes (abs (/ (% offset-seconds 3600) 60)))
             (offset-string (format "%+03d:%02d" offset-hours offset-minutes))
             (format (or altodo-done-tag-datetime-format "%Y-%m-%dT%H:%M:%S"))
             (timestamp-base (format-time-string format now (if use-local nil t)))
             (timestamp (concat timestamp-base offset-string)))
        (insert (format " #done:%s" timestamp))))))

(defun altodo--remove-done-tag ()
  "Remove #done tag from current line."
  (save-excursion
    (beginning-of-line)
    (when (re-search-forward " #done:\\([0-9/:T+-]+\\)?" (line-end-position) t)
      (replace-match ""))))

(defun altodo--find-previous-task-line ()
  "Find the previous task or comment line, skipping multiline comments."
  (save-excursion
    (forward-line -1)
    ;; Skip empty lines and indented lines (multiline comments)
    (while (and (not (bobp))
                (or (looking-at "^$")
                    (and (looking-at "^[ \t]+")
                         (not (looking-at altodo-task-regex))
                         (not (looking-at altodo-comment-regex)))))
      (forward-line -1))
    (when (or (altodo--task-p) (altodo--comment-p))
      (point))))

(defun altodo--task-p ()
  "Check if current line is a task line.
Returns nil if in a code block.
Returns t if current line is a task line, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (and (not (markdown-code-block-at-point-p))
         (looking-at altodo-task-regex))))

(defun altodo--comment-p ()
  "Check if current line is a single-line comment.
Returns nil if in a code block.
Returns t if current line is a single-line comment, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (and (not (markdown-code-block-at-point-p))
         (looking-at altodo-comment-regex))))

(defun altodo--empty-task-line-p ()
  "Check if current line is an empty task line ([ ] only).
Returns the indentation string if true, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (when (looking-at "^\\([ ]*\\)\\[.\\][ ]*$")
      (match-string 1))))

(defun altodo--get-current-indent ()
  "Get current line indentation level."
  (save-excursion
    (beginning-of-line)
    (looking-at "^[ ]*")
    (length (match-string 0))))

(defun altodo--get-line-indent (pos)
  "Get indentation level of line at position POS.
Returns value or nil."
  (save-excursion
    (goto-char pos)
    (altodo--get-current-indent)))

(defun altodo--normalize-indent (indent)
  "Normalize INDENT to next multiple of `altodo-indent-size`.
Returns value."
  (let ((remainder (mod indent altodo-indent-size)))
    (if (zerop remainder)
        indent
      (+ indent (- altodo-indent-size remainder)))))

(defun altodo--previous-line-empty-p ()
  "Check if previous line is empty (not task/comment/multiline-comment)."
  (save-excursion
    (forward-line -1)
    (not (or (altodo--task-p) (altodo--comment-p) (altodo--multiline-comment-p)))))

(defun altodo--get-previous-task-indent ()
  "Get indent of previous task line, or 0 if none."
  (let ((prev-task-pos (altodo--find-previous-task-line)))
    (if prev-task-pos
        (altodo--get-line-indent prev-task-pos)
      0)))

(defun altodo--set-line-indent (indent)
  "Set current line indentation to INDENT spaces.
Returns value."
  (save-excursion
    (beginning-of-line)
    (delete-horizontal-space)
    (indent-to indent)))

(defvar-local altodo--last-indent-action nil
  "Track last indent action: 'adjust, 'increase, 'same, 'decrease.")

(defvar-local altodo--last-indent-line nil
  "Track line number of last indent action.")

(defvar-local altodo--original-indent nil
  "Track original indent level before first action.")

;;; Filter Variables

(defvar-local altodo--filter-overlays nil
  "List of overlays used for filtering.")

(defvar-local altodo--filter-mode nil
  "Current filter mode symbol (e.g., 'done, 'progress, 'tag).")


;;; Filter Helper Functions

(defun altodo--filter-find-overlay (line-start line-end)
  "Find existing filter overlay for the line from LINE-START to LINE-END.
Returns the overlay if found, nil otherwise."
  (seq-find (lambda (ov)
              (and (eq (overlay-get ov 'category) 'altodo-filter)
                   (= (overlay-start ov) line-start)
                   (= (overlay-end ov) line-end)))
            altodo--filter-overlays))

(defun altodo--filter-invert-visibility (overlay)
  "Invert the visibility of OVERLAY.
If visible, make invisible. If invisible, make visible."
  (let ((invisible (overlay-get overlay 'invisible)))
    (overlay-put overlay 'invisible (not invisible))))

(defun altodo--filter-create-overlay (line-start line-end invisible)
  "Create a new filter overlay from LINE-START to LINE-END.
If INVISIBLE is non-nil, the overlay is initially invisible.
Returns the created overlay."
  (let ((ov (make-overlay line-start line-end)))
    (overlay-put ov 'category 'altodo-filter)
    (overlay-put ov 'invisible invisible)
    (overlay-put ov 'evaporate t)
    (push ov altodo--filter-overlays)
    ov))

(defun altodo--filter-remove-overlay (line-start line-end)
  "Remove overlay for line from LINE-START to LINE-END.
Returns t if overlay was removed, nil otherwise."
  (let ((ov (altodo--filter-find-overlay line-start line-end)))
    (when ov
      (delete-overlay ov)
      (setq altodo--filter-overlays (delq ov altodo--filter-overlays))
      t)))

(defun altodo--filter-show-multiline-comments (comment-start comment-end)
  "Show multiline comments in range from COMMENT-START to COMMENT-END.
Removes overlays for all lines in the range to make them visible."
  (save-excursion
    (goto-char comment-start)
    (while (< (point) comment-end)
      (altodo--filter-remove-overlay (line-beginning-position)
                                     (1+ (line-end-position)))
      (forward-line 1))))


;;; Filter Heading Cache (Phase 1 Optimization)

(defvar-local altodo--heading-cache nil
  "Cache of heading ranges for optimization.
Format: ((heading-regexp . (start . end)) ...)")

(defun altodo--get-cached-heading-range (heading-regexp)
  "Get heading range from cache.
Returns (start . end) or nil if not found.
Matches if heading-regexp is a substring of cached heading text."
  (let ((result nil)
        (pattern (regexp-quote heading-regexp)))
    (dolist (entry altodo--heading-cache)
      (when (and (not result)
                 (string-match-p pattern (car entry)))
        (setq result (cdr entry))))
    result))


;;; Modeline Helper Functions

(defvar altodo--mode-line-keymap nil
  "Cached keymap for mode-line AND/OR toggle.")

(defun altodo--get-mode-line-keymap ()
  "Get or create cached keymap for mode-line AND/OR toggle."
  (unless altodo--mode-line-keymap
    (let ((map (make-sparse-keymap)))
      (define-key map [mode-line mouse-1] 'altodo-sidebar--toggle-filter-mode)
      (setq altodo--mode-line-keymap map)))
  altodo--mode-line-keymap)

(defun altodo-sidebar--toggle-filter-mode (event)
  "Toggle between AND and OR filter modes.
EVENT is the mouse event.
NOTE: Current implementation clears selected filters.
Future versions may support keeping filters via defcustom option."
  (interactive "e")
  (altodo--with-sidebar-buffer
   (lambda ()
     ;; Toggle mode
     (setq altodo-sidebar--combine-mode
           (if (eq altodo-sidebar--combine-mode 'and) 'or 'and))
     
     ;; Clear filters (current behavior)
     (altodo-filter-clear)
     
     ;; Update modeline
     (altodo--update-sidebar-modeline))))

(defun altodo--get-sidebar-modeline-string ()
  "Get modeline string for sidebar with clickable AND/OR toggle.
Returns string like '[AND] (Single)' or '[OR] (Multiple)'."
  (when (and (boundp 'altodo-sidebar--combine-mode)
             (boundp 'altodo-sidebar--selection-mode))
    (let ((mode-str (if (eq altodo-sidebar--combine-mode 'or) "[OR]" "[AND]"))
          (selection-str (if (eq altodo-sidebar--selection-mode 'multiple)
                             "(Multiple)"
                           "(Single)")))
      (concat (propertize mode-str
                          'local-map (altodo--get-mode-line-keymap)
                          'help-echo "Click to toggle AND/OR mode"
                          'mouse-face 'mode-line-highlight)
              " "
              selection-str))))

(defun altodo--update-sidebar-modeline ()
  "Update sidebar modeline with current filter state."
  (when altodo-sidebar-modeline-enabled
    (setq altodo-sidebar-modeline-string
          (or (altodo--get-sidebar-modeline-string) ""))
    (force-mode-line-update)))

;;; Phase 2-1: Multiple sidebar buffer support

(defun altodo-sidebar--get-buffer (&optional source-buffer)
  "Return sidebar buffer for SOURCE-BUFFER from alist.
If SOURCE-BUFFER is nil, use current buffer."
  (let ((buf (cdr (assoc (or source-buffer (current-buffer)) altodo-sidebar--buffer-alist))))
    (when (and buf (buffer-live-p buf)) buf)))

(defun altodo-sidebar--get-or-create-buffer (source-buffer)
  "Get or create sidebar buffer for SOURCE-BUFFER.
Returns created value."
  (or (altodo-sidebar--get-buffer source-buffer)
      (let ((buf (generate-new-buffer
                  (format "*altodo-sidebar<%s>*" (buffer-name source-buffer)))))
        (with-current-buffer buf
          (setq-local altodo-sidebar--source-buffer source-buffer))
        (push (cons source-buffer buf) altodo-sidebar--buffer-alist)
        buf)))

(defun altodo-sidebar--cleanup-buffer (source-buffer)
  "Clean up sidebar buffer for SOURCE-BUFFER.
Returns value."
  (when-let ((buf (altodo-sidebar--get-buffer source-buffer)))
    (kill-buffer buf))
  (setq altodo-sidebar--buffer-alist
        (assoc-delete-all source-buffer altodo-sidebar--buffer-alist)))

(defun altodo-sidebar--on-source-buffer-kill ()
  "Clean up sidebar buffer when source buffer is killed.
Returns value."
  (altodo-sidebar--cleanup-buffer (current-buffer)))

(defun altodo--get-sidebar-buffer (&optional source-buffer)
  "Get sidebar buffer if it exists and is live.
Returns buffer or nil.
Can be called from either source or sidebar buffer."
  (let ((src (or source-buffer (current-buffer))))
    ;; If called from sidebar buffer, return current buffer
    (if (buffer-local-value 'altodo-sidebar--source-buffer src)
        (when (buffer-live-p src) src)
      (altodo-sidebar--get-buffer src))))

(defun altodo--with-sidebar-buffer (body-fn)
  "Execute BODY-FN in sidebar buffer context if it exists.
Returns result of BODY-FN or nil if sidebar buffer doesn't exist."
  (let ((sidebar-buf (altodo--get-sidebar-buffer)))
    (when sidebar-buf
      (with-current-buffer sidebar-buf
        (funcall body-fn)))))


;;; Filter Main Functions

(defun altodo--compile-filter-predicate (entry)
  "Compile filter ENTRY to predicate function.
Returns a predicate function that can be used with altodo--filter-lines."
  (let ((pattern (plist-get entry :pattern))
        (type (plist-get entry :type)))
    (cond
     ((eq type 'search-lambda) pattern)
     ((eq type 'search-simple)
      (altodo--compile-simple-pattern pattern))
     (t (lambda () nil)))))

(defun altodo--combine-predicates (predicates combine-mode)
  "Combine multiple PREDICATES with COMBINE-MODE.
COMBINE-MODE is 'and or 'or.
Returns a new predicate function that combines all predicates."
  (cond
   ((eq combine-mode 'and)
    (lambda ()
      (catch 'found
        (dolist (pred predicates)
          (unless (funcall pred)
            (throw 'found nil)))
        t)))
   ((eq combine-mode 'or)
    (lambda ()
      (catch 'found
        (dolist (pred predicates)
          (when (funcall pred)
            (throw 'found t)))
        nil)))
   (t
    (error "Invalid combine-mode: %s" combine-mode))))

(defun altodo--filter-lines (predicate &optional show-multiline-comment display-context)
  "Apply filter using PREDICATE function.
PREDICATE is called at the beginning of each line.
If PREDICATE returns t, the line is shown; otherwise, it is hidden.
SHOW-MULTILINE-COMMENT (default t) controls whether to show multiline comments
attached to matching task/comment lines.
DISPLAY-CONTEXT (default 'heading-only) controls display of heading and comment lines:
  - 'all: show heading and multiline comments
  - 'heading-only: show heading only
  - 'none: show matched lines only"
  (let ((max-iterations 10000)
        (iterations 0)
        (show-multiline (if show-multiline-comment show-multiline-comment t))
        (ctx (or display-context 'heading-only))
        (matched-line-numbers nil)
        (start-time (current-time)))
    
    ;; Phase 1 Optimization: Initialize heading cache
    (altodo--compute-all-heading-ranges)
    
    (save-excursion
      ;; First pass: create overlays for all lines
      (goto-char (point-min))
      (while (and (not (eobp)) (< iterations max-iterations))
        (let* ((line-start (line-beginning-position))
               (line-end (1+ (line-end-position))))
          (unless (altodo--filter-find-overlay line-start line-end)
            (altodo--filter-create-overlay line-start line-end t)))
        (forward-line 1)
        (setq iterations (1+ iterations)))
      
      ;; Second pass: remove overlays for matched lines and collect line numbers
      (setq iterations 0)
      (goto-char (point-min))
      (while (and (not (eobp)) (< iterations max-iterations))
        (let* ((line-start (line-beginning-position))
               (line-end (1+ (line-end-position)))
               (line-num (line-number-at-pos))
               (match (funcall predicate)))
          (if match
              ;; Show line: remove overlay if exists
              (progn
                (altodo--filter-remove-overlay line-start line-end)
                ;; Collect matched line numbers for display-context processing
                (push line-num matched-line-numbers)
                
                ;; Handle multiline comments if show-multiline is t
                (when show-multiline
                  (let ((comment-range (altodo--get-multiline-comment-range)))
                    (when comment-range
                      (altodo--filter-show-multiline-comments (car comment-range) (cdr comment-range))))))))
        
        (forward-line 1)
        (setq iterations (1+ iterations)))
      
      ;; Third pass: apply display-context option
      (when (and matched-line-numbers (not (eq ctx 'none)))
        (let ((display-lines (altodo--compute-display-lines (nreverse matched-line-numbers) ctx)))
          (dolist (line-num display-lines)
            (save-excursion
              (goto-char (point-min))
              (forward-line (1- line-num))
              (let* ((line-start (line-beginning-position))
                     (line-end (1+ (line-end-position))))
                (altodo--filter-remove-overlay line-start line-end)))))))
    
    ;; Force redisplay after all overlays are processed
    (redisplay t)
    (when (>= iterations max-iterations)
      (message "Warning: altodo--filter-lines reached max iterations"))))

;;; Display Context Helper Functions

(defun altodo--get-heading-range-lines (heading-ranges current-pos)
  "Get list of line numbers in heading range that contains CURRENT-POS."
  (let ((result nil))
    (dolist (entry heading-ranges)
      (let ((range (cdr entry)))
        (when (and (>= current-pos (car range))
                   (<= current-pos (cdr range)))
          ;; Get start and end line numbers
          (save-excursion
            (goto-char (car range))
            (let ((start-line (line-number-at-pos)))
              (goto-char (cdr range))
              (let ((end-line (line-number-at-pos)))
                ;; Add normal text lines in range
                (dotimes (i (- end-line start-line -1))
                  (let ((line-num (+ start-line i)))
                    (when (altodo--normal-text-p line-num)
                      (push line-num result))))))))))
    result))

(defun altodo--normal-text-p (line-num)
  "Check if line at LINE-NUM is normal text (not task, comment, heading, or blank)."
  (save-excursion
    (goto-char (point-min))
    (forward-line (1- line-num))
    (beginning-of-line)
    (and (not (altodo--task-p))
         (not (altodo--comment-p))
         (not (altodo--multiline-comment-p))
         (not (looking-at "^#+[ \t]"))  ;; not ATX heading
         (not (looking-at "^[ \t]*$"))  ;; not blank
         ;; Check if next line is Setext underline
         (not (save-excursion
                 (forward-line 1)
                 (looking-at "^\\(=+\\|-+\\)[ \t]*$"))))))

(defun altodo--collapse-blank-lines (display-lines)
  "Collapse consecutive blank lines to single blank line.
Returns new display-lines with consecutive blank lines reduced to one."
  (let ((sorted-lines (sort (copy-sequence display-lines) #'<))
        (result nil)
        (prev-blank-p nil))
    (dolist (line sorted-lines)
      ;; Inline blank-line-p check
      (let ((blank-p (save-excursion
                       (goto-char (point-min))
                       (forward-line (1- line))
                       (looking-at "^[ \t]*$"))))
        (if (and blank-p prev-blank-p)
            ;; Skip consecutive blank lines
            nil
          ;; Add line
          (push line result)
          (setq prev-blank-p blank-p))))
    (nreverse result)))

(defun altodo--add-heading-spacing (display-lines heading-line)
  "Add spacing lines before/after heading.
Always add line after heading.
Add line before heading only if there are already lines after this heading in display-lines."
  ;; Always add line after heading
  (let ((next-line (1+ heading-line)))
    (unless (member next-line display-lines)
      (push next-line display-lines)))
  ;; Add line before heading only if not first heading
  ;; (i.e., if there are lines after this heading already in display-lines)
  (when (seq-some (lambda (line) (> line heading-line)) display-lines)
    (let ((prev-line (1- heading-line)))
      (when (and (> prev-line 0)
                 (not (member prev-line display-lines)))
        (push prev-line display-lines))))
  ;; Always add heading line
  (unless (member heading-line display-lines)
    (push heading-line display-lines))
  display-lines)

(defun altodo--compute-display-lines (matched-lines display-context)
  "Compute display lines based on DISPLAY-CONTEXT option.
MATCHED-LINES: list of line numbers that match the filter
DISPLAY-CONTEXT: 'all, 'heading-only, or 'none
Returns: list of line numbers to display (including heading and comment lines)"
  ;; Optimization 2: Cache heading-ranges to avoid repeated calls
  (let ((display-lines matched-lines)
        (heading-ranges (altodo--compute-all-heading-ranges)))
    (cond
      ((eq display-context 'all)
       ;; Add heading lines and multiline comment lines
       (dolist (line-num matched-lines)
         (save-excursion
           (goto-char (point-min))
           (forward-line (1- line-num))
           (let ((current-pos (point)))
             ;; Add heading line if exists
             (dolist (entry heading-ranges)
                 (let ((range (cdr entry)))
                   (when (and (>= current-pos (car range))
                              (<= current-pos (cdr range)))
                     ;; Find heading line number by searching backwards
                     (save-excursion
                       (goto-char (car range))
                       (forward-line -1)
                       (let ((heading-line (line-number-at-pos)))
                         (unless (member heading-line display-lines)
                           (setq display-lines (altodo--add-heading-spacing display-lines heading-line))))))))
             (let ((comment-range (altodo--get-multiline-comment-range)))
               (when comment-range
                 (save-excursion
                   (goto-char (car comment-range))
                   (let ((max-iter 1000) (iter 0))
                     (while (and (<= (point) (cdr comment-range)) (< iter max-iter))
                       (let ((comment-line (line-number-at-pos)))
                         (unless (member comment-line display-lines)
                           (push comment-line display-lines)))
                       (forward-line 1)
                       (setq iter (1+ iter))))))))))
       display-lines)
      
      ((eq display-context 'heading-only)
       ;; Add heading lines only
       (dolist (line-num matched-lines)
         (save-excursion
           (goto-char (point-min))
           (forward-line (1- line-num))
           (let ((current-pos (point)))
             (dolist (entry heading-ranges)
               (let ((range (cdr entry)))
                 (when (and (>= current-pos (car range))
                            (<= current-pos (cdr range)))
                   ;; Find heading line number by searching backwards
                   (save-excursion
                     (goto-char (car range))
                     (forward-line -1)
                     (let ((heading-line (line-number-at-pos)))
                       (unless (member heading-line display-lines)
                         (setq display-lines (altodo--add-heading-spacing display-lines heading-line)))))))))))
       (altodo--collapse-blank-lines display-lines))
      
      ((eq display-context 'none)
       ;; Show only matched lines
       matched-lines)
      
      (t display-lines))))

;;; Filter Predicate Functions

(defun altodo--line-state-p (state)
  "Return t if current line has STATE.
STATE should be one of the altodo-state-* constants."
  (looking-at (format "^[ \t]*\\[%s\\]" (regexp-quote state))))

(defun altodo--line-done-p ()
  "Return t if current line is a done task, nil otherwise."
  (altodo--line-state-p altodo-state-done))

(defun altodo--line-progress-p ()
  "Return t if current line is a progress task, nil otherwise."
  (altodo--line-state-p altodo-state-progress))

(defun altodo--line-open-p ()
  "Return t if current line is an open task, nil otherwise."
  (altodo--line-state-p altodo-state-open))

(defun altodo--line-has-tag-p (tag)
  "Return t if current line contains TAG.
TAG should be a string like \"important\" (without #)."
  (save-excursion
    (beginning-of-line)
    (and (or (altodo--task-p) (altodo--comment-p))
         (re-search-forward (concat "#" (regexp-quote tag) "\\>")
                            (line-end-position)
                            t))))

(defun altodo--string-to-valid-number (str)
  "Convert STR to number if valid, otherwise return nil.
Uses only standard Emacs Lisp functions.
Supports integers, floats, and scientific notation."
  (when (and (stringp str) (not (string-empty-p str)))
    (when (string-match-p "^[+-]?\\([0-9]+\\(\\.[0-9]*\\)?\\|\\.[0-9]+\\)\\([eE][+-]?[0-9]+\\)?$" str)
      (string-to-number str))))

(defun altodo--extract-tag-value (match-string)
  "Extract tag value from MATCH-STRING, removing quotes if present.
Returns value."
  (let ((value match-string))
    (if (and (string-prefix-p "\"" value)
             (string-suffix-p "\"" value))
        (substring value 1 -1)
      value)))

(defun altodo--line-get-tag-value (tag)
  "Get value of TAG on current line.
Returns value string or nil if tag not found.
TAG should be a string like \"priority\" (without #)."
  (save-excursion
    (beginning-of-line)
    (when (or (altodo--task-p) (altodo--comment-p))
      (when (re-search-forward (concat "#" (regexp-quote tag) ":\\(\"[^\"]*\"\\|[^[:space:]]+\\)")
                                (line-end-position)
                                t)
        (altodo--extract-tag-value (match-string 1))))))

(defun altodo--line-has-tag-value-p (tag value)
  "Return t if current line has TAG with VALUE.
TAG should be a string like \"priority\" (without #).
VALUE should be a string."
  (let ((actual-value (altodo--line-get-tag-value tag)))
    (and actual-value (string= actual-value value))))

(defun altodo--line-has-tag-value-any-p (tag values)
  "Return t if current line has TAG with any of VALUES.
TAG should be a string like \"priority\" (without #).
VALUES should be a list of strings."
  (let ((actual-value (altodo--line-get-tag-value tag)))
    (and actual-value (member actual-value values))))

(defun altodo--line-has-tag-value-numeric-p (tag op value)
  "Return t if current line has TAG with numeric value matching OP VALUE.
TAG should be a string like \"estimate\" (without #).
OP should be a comparison operator: >, <, =, >=, <=.
VALUE should be a number."
  (let* ((actual-value (altodo--line-get-tag-value tag))
         (actual-num (and actual-value (altodo--string-to-valid-number actual-value))))
    (when actual-num
      (cond
       ((eq op '>) (> actual-num value))
       ((eq op '<) (< actual-num value))
       ((eq op '=) (= actual-num value))
       ((eq op '>=) (>= actual-num value))
       ((eq op '<=) (<= actual-num value))
       (t nil)))))

(defun altodo--line-has-priority-p ()
  "Return t if current line has priority flag (!), nil otherwise.
Priority flag can be one or more '!' characters followed by a space."
  (save-excursion
    (beginning-of-line)
    (when (looking-at altodo-task-regex)
      (let ((content (match-string 3)))
        (and (string-match-p (concat "^[ \t]*" (regexp-quote altodo-flag-priority) "+ ")
                             content)
             t)))))

(defun altodo--line-has-star-p ()
  "Return t if current line has star flag (+), nil otherwise."
  (save-excursion
    (beginning-of-line)
    (when (looking-at altodo-task-regex)
      (let ((content (match-string 3)))
        (altodo--has-star-flag-p content)))))

(defun altodo--line-state-any-p (states)
  "Return t if current line has any of the STATES.
STATES should be a list of altodo-state-* constants."
  (catch 'found
    (dolist (state states)
      (when (altodo--line-state-p state)
        (throw 'found t)))
    nil))

(defun altodo--line-has-any-tag-p (tags)
  "Return t if current line has any of the TAGS, nil otherwise.
TAGS should be a list of tag strings (without @)."
  (catch 'found
    (dolist (tag tags)
      (when (altodo--line-has-tag-p tag)
        (throw 'found t)))
    nil))

(defun altodo--line-has-all-tags-p (tags)
  "Return t if current line has all of the TAGS, nil otherwise.
TAGS should be a list of tag strings (without @)."
  (catch 'found
    (dolist (tag tags)
      (unless (altodo--line-has-tag-p tag)
        (throw 'found nil)))
    t))

(defun altodo--line-has-person-p (person)
  "Return t if current line contains PERSON.
PERSON should be a string like \"john\" (without @)."
  (save-excursion
    (beginning-of-line)
    (and (or (altodo--task-p) (altodo--comment-p))
         (re-search-forward (concat "@" (regexp-quote person) "\\>")
                            (line-end-position)
                            t))))

(defun altodo--line-has-any-person-p (persons)
  "Return t if current line has any of the PERSONS.
PERSONS should be a list of person strings (without @)."
  (catch 'found
    (dolist (person persons)
      (when (altodo--line-has-person-p person)
        (throw 'found t)))
    nil))

(defun altodo--line-due-date-p ()
  "Check if current line has due date.
Returns t if due date exists, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (let ((line-end (line-end-position))
          (regex-match (altodo--date-regex-match)))
      (and (re-search-forward (concat "-> " regex-match) line-end t) t))))

(defun altodo--line-due-date-value ()
  "Get due date from current line.
Returns date string (e.g., \"2026-01-31\") or nil."
  (save-excursion
    (beginning-of-line)
    (let* ((line-end (line-end-position))
           (regex-info (altodo--date-regex-info))
           (regex (nth 0 regex-info))
           (year-idx (nth 2 regex-info))
           (month-idx (nth 3 regex-info))
           (day-idx (nth 4 regex-info)))
      (when (re-search-forward (concat "-> " regex) line-end t)
        (let ((year (match-string year-idx))
              (month (match-string month-idx))
              (day (match-string day-idx)))
          (format "%s-%s-%s" year month day))))))

(defun altodo--due-date-matches-p (condition)
  "Check if current line's due date matches CONDITION.
CONDITION: 'overdue, 'today, 'tomorrow, 'this-week, 'this-month,
           string (date), or list (before/after/between/within/past).
Returns t if matches, nil otherwise."
  (let ((due-date (altodo--line-due-date-value)))
    (unless due-date
      nil)
    
    (when due-date
      (let* ((due-date-time (altodo--parse-date due-date))
             (days-diff (altodo--days-diff due-date-time)))
        (pcase condition
          ('overdue (< days-diff 0))
          ('today (= days-diff 0))
          ('tomorrow (= days-diff 1))
          ('this-week
           (let* ((today-decoded (decode-time (current-time)))
                  (today-wday (nth 6 today-decoded))
                  (days-to-week-end (mod (- 7 today-wday) 7)))
             (and (>= days-diff 0) (<= days-diff days-to-week-end))))
          ('this-month
           (let* ((today-decoded (decode-time (current-time)))
                  (year (nth 5 today-decoded))
                  (month (nth 4 today-decoded))
                  (next-month (if (= month 12) 1 (1+ month)))
                  (next-year (if (= month 12) (1+ year) year))
                  (last-day-of-month-time (encode-time (list 0 0 0 0 next-month next-year nil nil nil)))
                  (last-day-of-month-decoded (decode-time (time-subtract last-day-of-month-time (seconds-to-time 86400))))
                  (last-day (nth 3 last-day-of-month-decoded))
                  (today-day (nth 3 today-decoded))
                  (days-to-month-end (- last-day today-day)))
             (and (>= days-diff 0) (<= days-diff days-to-month-end))))
          ((pred stringp) (string= due-date condition))
          (`(before ,date) (string< due-date date))
          (`(after ,date) (string> due-date date))
          (`(between ,start ,end) (and (not (string< due-date start)) (not (string> due-date end))))
          (`(within ,days) (and (>= days-diff 0) (<= days-diff days)))
          (`(past ,days) (>= (- days-diff) days))
          (_ nil))))))

(defun altodo--parse-due-date-condition (condition-str)
  "Parse due date condition string.
Returns parsed condition (symbol, string, or list).
Supports altodo-date-format for date strings.
Signals error on invalid date format."
  (cond
    ;; 相対日付
    ((string= condition-str "overdue") 'overdue)
    ((string= condition-str "today") 'today)
    ((string= condition-str "tomorrow") 'tomorrow)
    ((string= condition-str "this-week") 'this-week)
    ((string= condition-str "this-month") 'this-month)
    
    ;; 日付比較（before:DATE 形式）
    ((string-match "^before:\\(.+\\)$" condition-str)
     (let ((date-str (match-string 1 condition-str)))
       (if (altodo--parse-date date-str)
           (list 'before date-str)
         (error "Invalid date format in 'before' condition: %s (expected format: %s)" 
                date-str (or altodo-date-format "YYYY-MM-DD")))))
    
    ((string-match "^after:\\(.+\\)$" condition-str)
     (let ((date-str (match-string 1 condition-str)))
       (if (altodo--parse-date date-str)
           (list 'after date-str)
         (error "Invalid date format in 'after' condition: %s (expected format: %s)" 
                date-str (or altodo-date-format "YYYY-MM-DD")))))
    
    ((string-match "^between:\\(.+\\):\\(.+\\)$" condition-str)
     (let ((start-str (match-string 1 condition-str))
           (end-str (match-string 2 condition-str)))
       (if (and (altodo--parse-date start-str) (altodo--parse-date end-str))
           (list 'between start-str end-str)
         (error "Invalid date format in 'between' condition (expected format: %s)" 
                (or altodo-date-format "YYYY-MM-DD")))))
    
    ;; 相対比較（within:7, past:3 形式）
    ((string-match "^within:\\([0-9]+\\)$" condition-str)
     (list 'within (string-to-number (match-string 1 condition-str))))
    
    ((string-match "^past:\\([0-9]+\\)$" condition-str)
     (list 'past (string-to-number (match-string 1 condition-str))))
    
    ;; 絶対日付（altodo-date-format に対応）
    ((altodo--parse-date condition-str)
     condition-str)
    
    (t (error "Invalid due date condition: %s" condition-str))))


;; ========================================
;; 開始日フィルタ（start-date）
;; ========================================

(defun altodo--line-start-date-p ()
  "Check if current line has start date.
Returns t if start date exists, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (let ((line-end (line-end-position))
          (regex-match (altodo--date-regex-match)))
      (and (re-search-forward (concat regex-match " ->") line-end t) t))))

(defun altodo--line-start-date-value ()
  "Get start date from current line.
Returns date string (e.g., \"2026-01-01\") or nil."
  (save-excursion
    (beginning-of-line)
    (let* ((line-end (line-end-position))
           (regex-info (altodo--date-regex-info))
           (regex (nth 0 regex-info))
           (year-idx (nth 2 regex-info))
           (month-idx (nth 3 regex-info))
           (day-idx (nth 4 regex-info)))
      (when (re-search-forward (concat regex " ->") line-end t)
        (let ((year (match-string year-idx))
              (month (match-string month-idx))
              (day (match-string day-idx)))
          (format "%s-%s-%s" year month day))))))

(defun altodo--start-date-matches-p (condition)
  "Check if current line's start date matches CONDITION.
CONDITION: 'passed, 'today, 'not-yet, 'this-week, 'this-month,
           string (date), or list (before/after/between/within/past).
Returns t if matches, nil otherwise."
  (let ((start-date (altodo--line-start-date-value)))
    (unless start-date
      nil)
    
    (when start-date
      (let* ((start-date-time (altodo--parse-date start-date))
             (days-diff (altodo--days-diff start-date-time)))
        (pcase condition
          ('passed (< days-diff 0))
          ('today (= days-diff 0))
          ('not-yet (> days-diff 0))
          ('this-week
           (let* ((today-decoded (decode-time (current-time)))
                  (today-wday (nth 6 today-decoded))
                  (week-start (or altodo-week-start-day 1))
                  (days-to-week-end (mod (- 7 today-wday (- week-start 1)) 7)))
             (and (>= days-diff 0) (<= days-diff days-to-week-end))))
          ('this-month
           (let* ((today-decoded (decode-time (current-time)))
                  (year (nth 5 today-decoded))
                  (month (nth 4 today-decoded))
                  (next-month (if (= month 12) 1 (1+ month)))
                  (next-year (if (= month 12) (1+ year) year))
                  (last-day-time (time-subtract
                                  (encode-time 0 0 0 1 next-month next-year)
                                  (seconds-to-time 86400)))
                  (last-day (nth 3 (decode-time last-day-time)))
                  (today-day (nth 3 today-decoded))
                  (days-to-month-end (- last-day today-day)))
             (and (>= days-diff 0) (<= days-diff days-to-month-end))))
          ((pred stringp) (string= start-date condition))
          (`(before ,date) (string< start-date date))
          (`(after ,date) (string> start-date date))
          (`(between ,start ,end) (and (not (string< start-date start)) (not (string> start-date end))))
          (`(within ,days) (and (>= days-diff 0) (<= days-diff days)))
          (`(past ,days) (>= (- days-diff) days))
          (_ nil))))))

(defun altodo--parse-start-date-condition (condition-str)
  "Parse start date condition string.
Returns parsed condition (symbol, string, or list).
Supports altodo-date-format for date strings.
Signals error on invalid date format."
  (cond
    ((string= condition-str "passed") 'passed)
    ((string= condition-str "today") 'today)
    ((string= condition-str "not-yet") 'not-yet)
    ((string= condition-str "this-week") 'this-week)
    ((string= condition-str "this-month") 'this-month)
    
    ((string-match "^before:\\(.+\\)$" condition-str)
     (let ((date-str (match-string 1 condition-str)))
       (if (altodo--parse-date date-str)
           (list 'before date-str)
         (error "Invalid date format in 'before' condition: %s (expected format: %s)" 
                date-str (or altodo-date-format "YYYY-MM-DD")))))
    
    ((string-match "^after:\\(.+\\)$" condition-str)
     (let ((date-str (match-string 1 condition-str)))
       (if (altodo--parse-date date-str)
           (list 'after date-str)
         (error "Invalid date format in 'after' condition: %s (expected format: %s)" 
                date-str (or altodo-date-format "YYYY-MM-DD")))))
    
    ((string-match "^between:\\(.+\\):\\(.+\\)$" condition-str)
     (let ((start-str (match-string 1 condition-str))
           (end-str (match-string 2 condition-str)))
       (if (and (altodo--parse-date start-str) (altodo--parse-date end-str))
           (list 'between start-str end-str)
         (error "Invalid date format in 'between' condition (expected format: %s)" 
                (or altodo-date-format "YYYY-MM-DD")))))
    
    ((string-match "^within:\\([0-9]+\\)$" condition-str)
     (list 'within (string-to-number (match-string 1 condition-str))))
    
    ((string-match "^past:\\([0-9]+\\)$" condition-str)
     (list 'past (string-to-number (match-string 1 condition-str))))
    
    ((altodo--parse-date condition-str)
     condition-str)
    
    (t (error "Invalid start date condition: %s" condition-str))))


(defun altodo--line-text-contains-p (text)
  "Return t if current line contains TEXT.
Returns t if condition is true, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (and (or (altodo--task-p) (altodo--comment-p))
         (re-search-forward (regexp-quote text) (line-end-position) t))))

(defun altodo--line-contains-regexp-p (regexp)
  "Return t if current line matches REGEXP."
  (save-excursion
    (beginning-of-line)
    (and (or (altodo--task-p) (altodo--comment-p))
         (re-search-forward regexp (line-end-position) t))))

(defun altodo--line-nest-level ()
  "Return the nesting level of current line.
Returns integer (number of indentation levels)."
  (save-excursion
    (beginning-of-line)
    (let ((indent (altodo--get-current-indent)))
      (/ indent altodo-indent-size))))

(defun altodo--line-nest-level-p (level)
  "Return t if current line has nesting LEVEL.
Returns t if condition is true, nil otherwise."
  (= (altodo--line-nest-level) level))

(defun altodo--line-cancelled-p ()
  "Return t if current line is a cancelled task, nil otherwise."
  (altodo--line-state-p altodo-state-cancelled))

(defun altodo--line-waiting-p ()
  "Return t if current line is a waiting task, nil otherwise."
  (altodo--line-state-p altodo-state-waiting))

(defun altodo--line-matches-regexp-at-point-p (regexp)
  "Return t if current line matches REGEXP.
Assumes point is at beginning of line."
  (and regexp
       (re-search-forward regexp (line-end-position) t)))

(defun altodo--find-parent-task-matching-regexp (regexp target-indent-pred)
  "Find parent task matching REGEXP using TARGET-INDENT-PRED.
TARGET-INDENT-PRED is a function that takes (line-indent current-indent)
and returns t if this is the target parent level.
Returns t if found, nil otherwise."
  (when regexp
    (let ((current-indent (altodo--get-current-indent)))
      (when (> current-indent 0)
        (beginning-of-line)
        (catch 'found
          (while (zerop (forward-line -1))
            (when (altodo--task-p)
              (let ((line-indent (altodo--get-current-indent)))
                (when (funcall target-indent-pred line-indent current-indent)
                  (throw 'found
                         (save-excursion
                           (altodo--line-matches-regexp-at-point-p regexp))))))))))))

(defun altodo--line-parent-task-matches-regexp-p (regexp)
  "Return t if parent task matches REGEXP or current line is parent that matches.
Returns nil if no parent task exists (top-level task) or REGEXP is nil."
  (when regexp
    (save-excursion
      ;; Check if current line is a task that matches regexp
      (if (and (altodo--task-p)
               (progn
                 (beginning-of-line)
                 (altodo--line-matches-regexp-at-point-p regexp)))
          t
        ;; Check if parent task matches
        (altodo--find-parent-task-matching-regexp
         regexp
         (lambda (line-indent current-indent) (< line-indent current-indent)))))))

(defun altodo--line-root-parent-task-matches-regexp-p (regexp)
  "Return t if root parent task (indent=0) matches REGEXP or current line is root that matches.
Returns nil if no root parent task exists or REGEXP is nil."
  (when regexp
    (save-excursion
      (let ((current-indent (altodo--get-current-indent)))
        ;; Check if current line is root task that matches
        (if (and (= current-indent 0)
                 (altodo--task-p)
                 (progn
                   (beginning-of-line)
                   (altodo--line-matches-regexp-at-point-p regexp)))
            t
          ;; Check if root parent task matches
          (altodo--find-parent-task-matching-regexp
           regexp
           (lambda (line-indent _current-indent) (= line-indent 0))))))))

(defun altodo--parse-tag-value-condition (condition-str)
  "Parse tag-value CONDITION-STR and return predicate function.

Supported formats:
  \"tag value\" - exact match
  \"tag (value1 value2)\" - OR match
  \"tag (> 5)\" - numeric comparison
  \"tag (< 10)\" - numeric comparison
  \"tag (= 5)\" - numeric comparison
  \"tag (>= 5)\" - numeric comparison
  \"tag (<= 10)\" - numeric comparison"
  (cond
   ;; Numeric comparison: tag (op value)
   ((string-match "^\\([^ ]+\\) (\\([<>=]+\\) \\([0-9.eE+-]+\\))$" condition-str)
    (let* ((tag (match-string 1 condition-str))
           (op-str (match-string 2 condition-str))
           (value-str (match-string 3 condition-str))
           (op (intern op-str))
           (value (string-to-number value-str)))
      (lambda () (altodo--line-has-tag-value-numeric-p tag op value))))
   
   ;; Multiple values OR: tag (value1 value2 ...)
   ((string-match "^\\([^ ]+\\) (\\([^)]+\\))$" condition-str)
    (let* ((tag (match-string 1 condition-str))
           (values-str (match-string 2 condition-str))
           (values (split-string values-str)))
      (lambda () (altodo--line-has-tag-value-any-p tag values))))
   
   ;; Exact match: tag value
   ((string-match "^\\([^ ]+\\) \\(.+\\)$" condition-str)
    (let ((tag (match-string 1 condition-str))
          (value (match-string 2 condition-str)))
      (lambda () (altodo--line-has-tag-value-p tag value))))
   
   (t (error "Invalid tag-value condition: %s" condition-str))))

;; ============================================================================
;; DSL Pattern Helpers
;; ============================================================================

(defun altodo--simple-pattern-p (pattern)
  "Return t if PATTERN is a valid simple pattern.
Returns t if condition is true, nil otherwise."
  (member pattern altodo--dsl-simple-patterns))

(defun altodo--logic-operator-p (string)
  "Return t if STRING starts with a logic operator (and:, or:, not:).
Returns t if condition is true, nil otherwise."
  (string-match-p (concat "^" altodo--dsl-logic-operators-regex) string))

(defun altodo--find-next-logic-operator (string &optional start)
  "Find position of next logic operator in STRING after START.
Returns position or nil if not found."
  (string-match altodo--dsl-logic-operators-regex string (or start 0)))

;; ============================================================================
;; DSL Pattern Compiler
;; ============================================================================

(defun altodo--split-logic-args (args-string)
  "Split ARGS-STRING by top-level commas only.
Handles multiple logic operators at the same level.

Supports:
- Simple patterns: \"done,priority,cancelled\" → (\"done\" \"priority\" \"cancelled\")
- Single logic operator: \"and:done,priority\" → (\"and:done,priority\")
- Multiple same-level operators: \"and:done,priority,and:cancelled,star\" 
  → (\"and:done,priority\" \"and:cancelled,star\")

Limitations:
- Nested logic operators are NOT split: \"or:and:done,priority,cancelled\"
  → (\"or:and:done,priority,cancelled\") - treated as single element
- Deep nesting (2+ levels) is not supported
- See .kiro/memo/dsl_parser_limitations.md for details"
  (let ((result nil)
        (i 0)
        (len (length args-string))
        (in-logic nil))
    (while (< i len)
      (cond
       ;; Found logic operator at start (not nested)
       ((and (not in-logic) (altodo--logic-operator-p (substring args-string i)))
        (setq in-logic t)
        (let* ((op-match (string-match altodo--dsl-logic-operators-regex (substring args-string i)))
               (op-len (length (match-string 0 (substring args-string i))))
               (after-op-start (+ i op-len))
               ;; Look for next logic operator at same level (after a comma)
               (next-op-pos (string-match (concat "," altodo--dsl-logic-operators-regex)
                                         (substring args-string after-op-start))))
          (if next-op-pos
              ;; Found next same-level operator
              (let ((end-pos (+ after-op-start next-op-pos)))
                (push (substring args-string i end-pos) result)
                (setq i (1+ end-pos))
                (setq in-logic nil))
            ;; No next same-level operator - consume until end
            (push (substring args-string i) result)
            (setq i len))))
       
       ;; Simple pattern - consume until comma or end
       (t
        (let ((comma-pos (string-match "," (substring args-string i))))
          (if comma-pos
              (progn
                (push (substring args-string i (+ i comma-pos)) result)
                (setq i (+ i comma-pos 1)))
            (push (substring args-string i) result)
            (setq i len))))))
    (nreverse result)))

(defun altodo--normalize-pattern (pattern)
  "Normalize PATTERN string into a canonical form.

Returns a list:
  (simple \"pattern\") - simple pattern
  (arg \"type\" \"arg\") - argument pattern
  (logic op (\"p1\" \"p2\" ...)) - logic pattern"
  (cond
   ;; 単純パターン
   ((altodo--simple-pattern-p pattern)
    (list 'simple pattern))
   
   ;; 論理演算パターン: op:p1,p2,...
   ((altodo--logic-operator-p pattern)
    (string-match (concat "^" altodo--dsl-logic-operators-regex "\\(.+\\)$") pattern)
    (let ((op (match-string 1 pattern))
          (args (match-string 2 pattern)))
      (list 'logic (intern op) (altodo--split-logic-args args))))
   
   ;; 引数付きパターン: type:arg
   ((string-match "^\\([^:]+\\):\\(.+\\)$" pattern)
    (let ((type (match-string 1 pattern))
          (arg (match-string 2 pattern)))
      (list 'arg type arg)))
   
   (t (error "Invalid pattern: %s" pattern))))

(defun altodo--validate-pattern (normalized)
  "Validate NORMALIZED pattern.

Returns t if valid, nil otherwise."
  (pcase normalized
    (`(simple ,p)
     (altodo--simple-pattern-p p))
    
    (`(arg ,type ,_)
     (member type altodo--dsl-arg-types))
    
    (`(logic ,op ,args)
     (and (member op '(and or not))
          (consp args)))
    
    (_ nil)))

(defun altodo--compile-normalized-pattern (normalized)
  "Compile NORMALIZED pattern into a predicate function.

Returns a lambda function that returns t/nil."
  (pcase normalized
    ;; 単純パターン
    (`(simple ,p)
     (pcase p
       ("done" #'altodo--line-done-p)
       ("progress" #'altodo--line-progress-p)
       ("waiting" #'altodo--line-waiting-p)
       ("open" #'altodo--line-open-p)
       ("cancelled" #'altodo--line-cancelled-p)
       ("priority" #'altodo--line-has-priority-p)
       ("star" #'altodo--line-has-star-p)
       ("has-multiline-comment" #'altodo--line-has-multiline-comment-p)
       (_ (error "Unknown simple pattern: %s" p))))
    
    ;; 引数付きパターン
    (`(arg ,type ,arg)
     (pcase type
       ("tag" (lambda () (altodo--line-has-tag-p arg)))
       ("person" (lambda () (altodo--line-has-person-p arg)))
       ("text" (lambda () (altodo--line-text-contains-p arg)))
       ("regexp" (lambda () (altodo--line-contains-regexp-p arg)))
       ("level" (let ((level (string-to-number arg)))
                  (lambda () (altodo--line-nest-level-p level))))
       ("heading" (lambda () (altodo--line-in-heading-range-with-filter-p arg t 'only-tasks)))
       ("multiline-comment-contains" (lambda () (altodo--multiline-comment-contains-regexp-p arg)))
       ("due-date" (lambda () (altodo--due-date-matches-p (altodo--parse-due-date-condition arg))))
       ("start-date" (lambda () (altodo--start-date-matches-p (altodo--parse-start-date-condition arg))))
       ("tag-value" (altodo--parse-tag-value-condition arg))
       ("parent-task-regexp" (lambda () (altodo--line-parent-task-matches-regexp-p arg)))
       ("root-task-regexp" (lambda () (altodo--line-root-parent-task-matches-regexp-p arg)))
       (_ (error "Unknown arg type: %s" type))))
    
    ;; 論理演算パターン
    (`(logic ,op ,args)
     (let ((preds (mapcar #'altodo--compile-simple-pattern args)))
       (pcase op
         ('and (lambda ()
                 (catch 'found
                   (dolist (pred preds t)
                     (unless (funcall pred)
                       (throw 'found nil))))))
         ('or (lambda ()
                (catch 'found
                  (dolist (pred preds nil)
                    (when (funcall pred)
                      (throw 'found t))))))
         ('not (let ((pred (car preds)))
                 (lambda () (not (funcall pred)))))
         (_ (error "Unknown logic operator: %s" op)))))
    
    (_ (error "Invalid normalized pattern: %s" normalized))))

(defun altodo--compile-simple-pattern (pattern)
  "Compile PATTERN with error handling.

Returns a lambda function. On error, returns a fallback lambda that matches nothing."
  (condition-case err
      (let ((normalized (altodo--normalize-pattern pattern)))
        (unless (altodo--validate-pattern normalized)
          (error "Invalid pattern structure: %s" normalized))
        (altodo--compile-normalized-pattern normalized))
    (error (message "Failed to compile pattern '%s': %s" pattern err)
           (lambda () nil))))


(defun altodo--reset-indent-flags ()
  "Reset all indent tracking flags."
  (setq altodo--last-indent-action nil
        altodo--last-indent-line nil
        altodo--original-indent nil))

(defun altodo--get-multiline-comment-lines ()
  "Get list of line numbers for multiline comments following current line.
Returns nil if no multiline comments follow."
  (save-excursion
    (let ((start-line (line-number-at-pos))
          (lines nil))
      (forward-line 1)
      (while (and (not (eobp))
                  (get-text-property (point) 'altodo-multiline-comment))
        (push (line-number-at-pos) lines)
        (forward-line 1))
      (nreverse lines))))

(defun altodo--indent-multiline-comments (lines indent-delta)
  "Indent multiline comment LINES by INDENT-DELTA spaces.
Returns value."
  (save-excursion
    (dolist (line-num lines)
      (goto-char (point-min))
      (forward-line (1- line-num))
      (let ((current-indent (altodo--get-current-indent)))
        (altodo--set-line-indent (max 0 (+ current-indent indent-delta)))))))

(defun altodo-indent-line ()
  "Indent current line for altodo-mode with smart task hierarchy.
Returns nil."
  (interactive)
  (let* ((current-line (line-number-at-pos))
         (current-indent (altodo--get-current-indent))
         (point-pos (current-column)))
    (back-to-indentation)
    (let* ((cur-pos (current-column))
           (new-indent
            (cond
             ;; タスク行または1行コメント行
             ((or (altodo--task-p) (altodo--comment-p))
              (altodo--indent-task-or-comment current-line current-indent))
             ;; 複数行コメント行
             ((altodo--multiline-comment-p)
              (altodo--indent-multiline-comment current-indent))
             ;; その他 → markdown-mode の標準動作
             (t
              (altodo--reset-indent-flags)
              (if (fboundp 'markdown-cycle)
                  (markdown-cycle)
                (indent-for-tab-command))
              nil))))
      (when new-indent
        (let ((indent-delta (- new-indent current-indent)))
          ;; 現在行をインデント
          (altodo--set-line-indent new-indent)
          ;; 複数行コメントも一緒にインデント（タスク/1行コメントの場合のみ）
          (when (and (or (altodo--task-p) (altodo--comment-p))
                     (/= indent-delta 0))
            (let ((multiline-lines (altodo--get-multiline-comment-lines)))
              (when multiline-lines
                (altodo--indent-multiline-comments multiline-lines indent-delta))))
          (move-to-column (max (+ point-pos (- new-indent cur-pos)) 0)))))))

(defun altodo--indent-task-or-comment (current-line current-indent)
  "Calculate indent for task or comment line.
CURRENT-LINE is the line number, CURRENT-INDENT is current indentation."
  (let ((normalized (altodo--normalize-indent current-indent)))
    (if (/= normalized current-indent)
        ;; 中途半端なインデント → 正常化（G1, G2）
        (altodo--normalize-irregular-indent current-indent normalized)
      ;; 正常なインデント → 段階的制御（G3-G8）
      (altodo--smart-indent current-line current-indent))))

(defun altodo--normalize-irregular-indent (current-indent normalized)
  "Normalize irregular indent considering previous line.
CURRENT-INDENT is current indentation, NORMALIZED is normalized value."
  (altodo--reset-indent-flags)
  (if (altodo--previous-line-empty-p)
      ;; G1: 前が空行 → インデント0
      0
    ;; G2: 前がタスク/コメント → 前+4を超えない
    (let ((prev-indent (altodo--get-previous-task-indent)))
      (min normalized (+ prev-indent altodo-indent-size)))))

(defun altodo--smart-indent (current-line current-indent)
  "Smart indent control for task/comment line.
CURRENT-LINE is the line number, CURRENT-INDENT is current indentation."
  (cond
   ;; G3: 前が空行 → インデント0
   ((altodo--previous-line-empty-p)
    (altodo--reset-indent-flags)
    0)
   ;; G6-G8: 連続TAB実行
   ((and (eq altodo--last-indent-line current-line) altodo--last-indent-action)
    (or (altodo--cycle-indent current-indent)
        ;; nilが返された場合は初回TAB処理
        (altodo--initial-indent current-indent)))
   ;; G4, G5: 初回TAB
   (t
    (altodo--initial-indent current-indent))))

(defun altodo--cycle-indent (current-indent)
  "Handle cyclic indent for consecutive TAB presses.
CURRENT-INDENT is current indentation."
  (pcase altodo--last-indent-action
    ;; 2回目 → 元に戻す
    ('increase
     (setq altodo--last-indent-action 'same)
     altodo--original-indent)
    ;; 3回目 → 逆インデント
    ('same
     (if (> current-indent 0)
         (progn
           (setq altodo--last-indent-action 'decrease)
           (max 0 (- current-indent altodo-indent-size)))
       ;; indent=0の場合はリセット
       (altodo--reset-indent-flags)
       nil))
    ;; 4回目 → 逆インデント継続 or 元に戻す
    ('decrease
     (if (> current-indent 0)
         ;; 逆インデント継続
         (progn
           (setq altodo--last-indent-action 'decrease)
           (max 0 (- current-indent altodo-indent-size)))
       ;; indent=0 → 元に戻す
       (setq altodo--last-indent-action 'back)
       altodo--original-indent))
    ;; 5回目 → リセット
    ('back
     (altodo--reset-indent-flags)
     nil)))

(defun altodo--initial-indent (current-indent)
  "Handle initial TAB press for task/comment line.
CURRENT-INDENT is current indentation."
  (cond
   ;; ファイル先頭行（1行目）→ インデント0
   ((= (line-number-at-pos) 1)
    (altodo--reset-indent-flags)
    0)
   ;; 前の行を確認
   (t
    (let ((prev-task-pos (altodo--find-previous-task-line)))
      (cond
       ;; 前の行がない → インデント0
       ((null prev-task-pos)
        (altodo--reset-indent-flags)
        0)
       ;; 前の行がある → 順インデント可能かチェック
       (t
        (let ((prev-indent (altodo--get-line-indent prev-task-pos)))
          (cond
           ;; 現在のインデントが前の行より深い → 逆インデント
           ((> current-indent prev-indent)
            (setq altodo--last-indent-action 'increase
                  altodo--original-indent current-indent
                  altodo--last-indent-line (line-number-at-pos))
            (max 0 (- current-indent altodo-indent-size)))
           ;; 順インデント可能（前の行+8以内）
           ((<= (+ current-indent altodo-indent-size) (+ prev-indent (* 2 altodo-indent-size)))
            (setq altodo--last-indent-action 'increase
                  altodo--original-indent current-indent
                  altodo--last-indent-line (line-number-at-pos))
            (+ current-indent altodo-indent-size))
           ;; 順インデント不可能 → 維持
           (t
            (altodo--reset-indent-flags)
            current-indent)))))))))

(defun altodo--indent-multiline-comment (current-indent)
  "Calculate indent for multiline comment line.
CURRENT-INDENT is current indentation."
  (let ((normalized (altodo--normalize-indent current-indent)))
    (if (/= normalized current-indent)
        ;; 中途半端なインデント → 正常化
        (progn
          (altodo--reset-indent-flags)
          (if (altodo--previous-line-empty-p)
              0
            (let ((prev-indent (altodo--get-previous-task-indent)))
              (min normalized (+ prev-indent altodo-indent-size)))))
      ;; G9: 正常インデント → 維持
      normalized)))

(defun altodo-enter ()
  "Handle RET key in altodo-mode.
Returns nil."
  (interactive)
  ;; SKK compatibility: similar to skk-wrap-newline-command
  ;; See: https://github.com/skk-dev/ddskk/issues/176
  (cond
   ;; SKK is in conversion mode
   ((and altodo-skk-wrap-newline
         (boundp 'skk-henkan-mode)
         skk-henkan-mode)
    (when (fboundp 'skk-kakutei)
      (skk-kakutei))
    ;; If skk-egg-like-newline is nil, execute normal processing
    (unless (and (boundp 'skk-egg-like-newline)
                 skk-egg-like-newline)
      (altodo-enter-internal)))
   ;; Normal case
   (t
    (altodo-enter-internal))))

(defun altodo-enter-internal ()
  "Internal function for altodo-enter processing.
Returns value."
  (cond
   ;; 空のタスク行 → タスクマーカーを削除して改行
   ((altodo--empty-task-line-p)
    (let ((indent (altodo--empty-task-line-p)))
      (delete-region (line-beginning-position) (line-end-position))
      (insert indent)
      (newline)))
   ;; タスク行・1行コメント行 → 同じインデントで空のタスク挿入
   ((or (altodo--task-p) (altodo--comment-p))
    (altodo--reset-indent-flags)
    (altodo-add-task))
   ;; 複数行コメント行 → 同じインデントで継続
   ((altodo--multiline-comment-p)
    (altodo--reset-indent-flags)
    (let ((indent (altodo--get-current-indent)))
      (end-of-line)
      (newline)
      (indent-to indent)))
   ;; その他 → markdown-mode の標準動作
   (t
    (if (fboundp 'markdown-enter-key)
        (markdown-enter-key)
      (newline-and-indent)))))

(defun altodo-add-task (&optional indent-deeper)
  "Add a new task at current indentation level.
If INDENT-DEEPER is non-nil, add as subtask (one level deeper).
Returns nil."
  (interactive)
  (if (or (altodo--task-p) (altodo--comment-p))
      (progn
        (end-of-line)
        (newline)
        (let ((indent (save-excursion
                        (forward-line -1)
                        (beginning-of-line)
                        (if (looking-at "^[ ]*")
                            (length (match-string 0))
                          0))))
          (indent-to (if indent-deeper
                         (+ indent altodo-indent-size)
                       indent))
          (insert "[ ] ")))
    (message "Not on a task or comment line")))

(defun altodo-add-subtask ()
  "Add a new subtask (indented one level deeper).
Returns nil."
  (interactive)
  (if (or (altodo--task-p) (altodo--comment-p))
      (altodo-add-task t)
    (message "Not on a task or comment line")))

(defun altodo-toggle-comment ()
  "Toggle between task and comment.
Returns value."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (cond
     ((looking-at altodo-task-regex)
      (replace-match (format "%s \\3" altodo-comment-marker) nil nil))
     ((looking-at altodo-comment-regex)
      (replace-match "\\1[ ] \\2" nil nil)))))

(defun altodo--get-priority-level ()
  "Get priority level (1-3) of current line, or nil if no priority flag."
  (save-excursion
    (beginning-of-line)
    (let ((content (cond
                    ((looking-at altodo-task-regex) (match-string 3))
                    ((looking-at altodo-comment-regex) (match-string 2))
                    (t nil))))
      (when content
        (cond
         ((string-match-p (concat "^\\s-*" (regexp-quote altodo-flag-priority) "\\{3\\}") content) 3)
         ((string-match-p (concat "^\\s-*" (regexp-quote altodo-flag-priority) "\\{2\\}") content) 2)
         ((string-match-p (concat "^\\s-*" (regexp-quote altodo-flag-priority)) content) 1)
         (t nil))))))

(defun altodo--remove-priority-from-string (str)
  "Remove priority flags (!, !!, !!!) from STR."
  (replace-regexp-in-string 
   (concat "^[ \t]*" (regexp-quote altodo-flag-priority) "+[ \t]*")
   ""
   str))

(defun altodo--has-star-flag-p (str)
  "Return t if STR has star flag (+)."
  (and (string-match-p (concat "^[ \t]*" (regexp-quote altodo-flag-star) " ") str)
       t))

(defun altodo--remove-star-from-string (str)
  "Remove star flag (+) from STR."
  (replace-regexp-in-string 
   (concat "^[ \t]*" (regexp-quote altodo-flag-star) "[ \t]*")
   " "
   str))

(defun altodo--set-priority-flag (level)
  "Set priority flag to LEVEL (1-3) on current line.
Returns value."
  (save-excursion
    (beginning-of-line)
    (cond
     ;; タスク行
     ((looking-at altodo-task-regex)
      (let ((indent (match-string 1))
            (state (match-string 2))
            (content (match-string 3)))
        (let* ((cleaned (save-match-data (altodo--remove-priority-from-string content)))
               (flag (make-string level (string-to-char altodo-flag-priority)))
               (trimmed (save-match-data (string-trim cleaned))))
          (replace-match (format "%s[%s] %s%s" 
                               indent 
                               (or state " ")
                               flag
                               (if (string-empty-p trimmed) "" (concat " " trimmed)))))))
     ;; コメント行
     ((looking-at altodo-comment-regex)
      (let ((indent (match-string 1))
            (content (match-string 2)))
        (let* ((cleaned (save-match-data (altodo--remove-priority-from-string content)))
               (flag (make-string level (string-to-char altodo-flag-priority)))
               (trimmed (save-match-data (string-trim cleaned))))
          (replace-match (format "%s%s %s%s" 
                               indent 
                               altodo-comment-marker
                               flag
                               (if (string-empty-p trimmed) "" (concat " " trimmed)))))))
     ;; その他の行
     (t
      (message "Not on a task or comment line")))))
(defun altodo-set-priority-1 ()
  "Set priority flag to level 1 (!).
Returns nil."
  (interactive)
  (altodo--set-priority-flag 1))

(defun altodo-set-priority-2 ()
  "Set priority flag to level 2 (!!).
Returns nil."
  (interactive)
  (altodo--set-priority-flag 2))

(defun altodo-set-priority-3 ()
  "Set priority flag to level 3 (!!!).
Returns nil."
  (interactive)
  (altodo--set-priority-flag 3))


(defun altodo-toggle-star-flag ()
  "Toggle star flag (+) on current task or comment line.
Returns nil."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (cond
     ;; タスク行
     ((looking-at altodo-task-regex)
      (let ((indent (match-string 1))
            (state (match-string 2))
            (content (match-string 3)))
        (if (save-match-data (altodo--has-star-flag-p content))
            ;; フラグを削除
            (let ((cleaned (save-match-data (altodo--remove-star-from-string content))))
              (replace-match (format "%s[%s]%s" indent (or state " ") cleaned)))
          ;; フラグを追加
          (let ((trimmed (save-match-data (string-trim content))))
            (replace-match (format "%s[%s] %s%s" 
                                 indent 
                                 (or state " ")
                                 altodo-flag-star
                                 (if (string-empty-p trimmed) "" (concat " " trimmed))))))))
     ;; コメント行
     ((looking-at altodo-comment-regex)
      (let ((indent (match-string 1))
            (content (match-string 2)))
        (if (save-match-data (altodo--has-star-flag-p content))
            ;; フラグを削除
            (let ((cleaned (save-match-data (altodo--remove-star-from-string content))))
              (replace-match (format "%s%s%s" indent altodo-comment-marker cleaned)))
          ;; フラグを追加
          (let ((trimmed (save-match-data (string-trim content))))
            (replace-match (format "%s%s %s%s" 
                                 indent 
                                 altodo-comment-marker
                                 altodo-flag-star
                                 (if (string-empty-p trimmed) "" (concat " " trimmed))))))))
     ;; その他の行
     (t
      (message "Not on a task or comment line")))))

(defun altodo-start-multiline-comment ()
  "Start a multiline comment at current indentation level + 4.
Returns nil."
  (interactive)
  (if (or (altodo--task-p) (altodo--comment-p))
      (let ((indent (altodo--get-current-indent)))
        (end-of-line)
        (newline)
        (indent-to (+ indent altodo-indent-size)))
    (message "Not on a task or comment line")))

;;; Testing Functions

;;;###autoload
(defun altodo-run-full-test-suite ()
  "Run comprehensive test suite for altodo-mode.
Returns value."
  (interactive)
  (message "=== Running Full altodo Test Suite ===")
  
  (let ((regex-passed (altodo-test-regex-patterns))
        (helper-passed (altodo-test-helper-functions))
        (total-tests 0)
        (passed-tests 0))
    
    ;; Count and report results
    (when regex-passed (setq passed-tests (1+ passed-tests)))
    (when helper-passed (setq passed-tests (1+ passed-tests)))
    (setq total-tests 2)
    
    ;; Additional integration tests
    (message "Running integration tests...")
    (let ((integration-passed t))
      
      ;; Test state change functions
      (condition-case err
          (progn
            (altodo--get-state-face "x")
            (altodo--get-state-text-face "@")
            (altodo--get-flag-text-face "+" "w")
            (message "✓ State function integration test passed"))
        (error
         (message "✗ State function integration test failed: %s" err)
         (setq integration-passed nil)))
      
      (when integration-passed 
        (setq passed-tests (1+ passed-tests)))
      (setq total-tests (1+ total-tests)))
    
    ;; Final report
    (message "=== Test Suite Results ===")
    (message "Tests passed: %d/%d" passed-tests total-tests)
    (if (= passed-tests total-tests)
        (message "✓ All tests PASSED - altodo-mode is ready for production")
      (message "✗ Some tests FAILED - review issues before deployment"))
    
    (= passed-tests total-tests)))

;;;###autoload
(defun altodo-test-regex-patterns ()
  "Test altodo regex patterns for correctness.
Returns value."
  (interactive)
  (let ((test-cases '(("[ ] test task" . ("" "test task"))
                      ("[x] completed task" . ("x" "completed task"))
                      ("    [ ] indented task" . ("" "indented task"))
                      ("[@ ] progress task" . ("@" " progress task"))
                      ("[w] waiting task" . ("w" "waiting task"))
                      ("[~] cancelled task" . ("~" "cancelled task"))
                      ("not a task" . nil)))
        (passed 0)
        (total (length test-cases)))
    (message "Testing altodo-task-regex...")
    (dolist (test-case test-cases)
      (let ((input (car test-case))
            (expected (cdr test-case)))
        (if (string-match altodo-task-regex input)
            (let ((actual (list (match-string 1 input) (match-string 2 input))))
              (if (equal expected actual)
                  (progn
                    (message "✓ PASS: '%s'" input)
                    (setq passed (1+ passed)))
                (message "✗ FAIL: '%s' -> Expected: %s, Got: %s" input expected actual)))
          (if (null expected)
              (progn
                (message "✓ PASS: '%s' (no match expected)" input)
                (setq passed (1+ passed)))
            (message "✗ FAIL: '%s' -> Expected match but got none" input)))))
    (message "Test Results: %d/%d passed" passed total)
    (= passed total)))

;;;###autoload
(defun altodo-test-helper-functions ()
  "Test altodo helper functions for correctness.
Returns value."
  (interactive)
  (let ((passed 0) (total 0))
    (message "Testing helper functions...")
    
    ;; Test altodo--get-state-face
    (dolist (test-case '(("x" . altodo-task-done)
                         ("@" . altodo--task-progress)
                         ("w" . altodo-task-waiting)
                         ("~" . altodo-task-cancelled)
                         ("" . altodo-task-open)
                         ("invalid" . altodo-task-open)))
      (setq total (1+ total))
      (let* ((input (car test-case))
             (expected (cdr test-case))
             (actual (altodo--get-state-face input)))
        (if (eq expected actual)
            (progn
              (message "✓ PASS: altodo--get-state-face('%s') -> %s" input actual)
              (setq passed (1+ passed)))
          (message "✗ FAIL: altodo--get-state-face('%s') -> Expected: %s, Got: %s" 
                   input expected actual))))
    
    (message "Helper function tests: %d/%d passed" passed total)
    (= passed total)))

;;; Auto-mode

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.altodo\\'" . altodo-mode))


;;; Done Task Movement

(defcustom altodo-done-file-prefix "_done"
  "Prefix for done task files."
  :type 'string
  :group 'altodo)

(defcustom altodo-move-single-line-comments-manually t
  "Whether to move single-line comments (///) when moving tasks manually."
  :type 'boolean
  :group 'altodo)

(defcustom altodo-auto-move-interval 3600
  "Interval in seconds for auto-moving done tasks (default: 3600 = 1 hour)."
  :type 'integer
  :group 'altodo)

(defcustom altodo-auto-save-after-move nil
  "Whether to save buffer after auto-moving done tasks."
  :type 'boolean
  :group 'altodo)

(defcustom altodo-auto-move-skip-done-files t
  "Whether to skip done files when auto-moving tasks."
  :type 'boolean
  :group 'altodo)

(defcustom altodo-show-auto-move-in-mode-line t
  "Whether to show auto-move status in mode line."
  :type 'boolean
  :group 'altodo)

(defvar altodo--auto-move-timer nil
  "Timer for auto-moving done tasks.")

(defun altodo--is-done-file-p ()
  "Check if current buffer is a done file.
Returns t if condition is true, nil otherwise."
  (when (buffer-file-name)
    (let ((basename (file-name-sans-extension (file-name-nondirectory (buffer-file-name)))))
      (string-suffix-p altodo-done-file-prefix basename))))

(defun altodo--auto-move-all-buffers ()
  "Move done tasks in all altodo-mode buffers."
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (and (eq major-mode 'altodo-mode)
                 (or (not altodo-auto-move-skip-done-files)
                     (not (altodo--is-done-file-p))))
        (altodo-move-all-done-tasks altodo-auto-save-after-move)))))

(defun altodo-toggle-auto-move-timer ()
  "Toggle auto-move timer for done tasks.
Returns nil."
  (interactive)
  (if altodo--auto-move-timer
      (altodo-stop-auto-move-timer)
    (altodo-start-auto-move-timer)))

(defun altodo-start-auto-move-timer ()
  "Start auto-move timer for done tasks.
Returns value."
  (interactive)
  (when altodo--auto-move-timer
    (cancel-timer altodo--auto-move-timer))
  (setq altodo--auto-move-timer
        (run-with-timer altodo-auto-move-interval altodo-auto-move-interval
                        #'altodo--auto-move-all-buffers))
  (force-mode-line-update t)
  (message "altodo: Auto-move timer started (interval: %d seconds)" altodo-auto-move-interval))

(defun altodo-stop-auto-move-timer ()
  "Stop auto-move timer for done tasks.
Returns value."
  (interactive)
  (when altodo--auto-move-timer
    (cancel-timer altodo--auto-move-timer)
    (setq altodo--auto-move-timer nil)
    (force-mode-line-update t)
    (message "altodo: Auto-move timer stopped")))

(defun altodo--get-done-file-path ()
  "Get the path to the done file for current buffer.
Returns value or nil."
  (let* ((current-file (buffer-file-name))
         (dir (file-name-directory current-file))
         (base (file-name-sans-extension (file-name-nondirectory current-file)))
         (ext (file-name-extension current-file t))
         (done-file (concat dir base altodo-done-file-prefix ext)))
    done-file))

(defun altodo--is-done-or-cancelled-task ()
  "Check if current line is a done [x] or cancelled [~] task."
  (save-excursion
    (beginning-of-line)
    (when (looking-at altodo-task-regex)
      (let ((state (match-string 2)))
        (or (string= state altodo-state-done)
            (string= state altodo-state-cancelled))))))

(defun altodo--get-task-heading ()
  "Get the heading for current task (search backward for # heading).
Returns (heading-marks . heading-text) or nil if no heading found."
  (save-excursion
    (let ((heading nil))
      (when (re-search-backward "^\\(#+\\)[ \t]+\\(.+\\)$" nil t)
        (setq heading (cons (match-string 1) (match-string 2))))
      heading)))

(defun altodo--extract-task-line ()
  "Extract current task line content."
  (buffer-substring-no-properties (line-beginning-position) (line-end-position)))

(defun altodo--get-multiline-comment-region ()
  "Get region (start . end) of multiline comments following current line.
Returns nil if no multiline comments follow."
  (save-excursion
    (forward-line 1)
    (let ((start (point))
          (end nil))
      ;; Collect multiline comment lines
      (while (and (not (eobp))
                  (altodo--multiline-comment-p))
        (forward-line 1))
      (setq end (point))
      
      (if (> end start)
          (cons start end)
        nil))))

(defun altodo--extract-task-with-comments ()
  "Extract current task with its multiline comments.
Returns (task-line . comments-text) or (task-line . nil)."
  (let ((task-line (altodo--extract-task-line))
        (comments nil))
    (let ((region (altodo--get-multiline-comment-region)))
      (when region
        (setq comments (buffer-substring-no-properties (car region) (cdr region)))))
    (cons task-line comments)))

(defun altodo--append-to-done-file (done-file heading task-line comments)
  "Append task to DONE-FILE under HEADING with TASK-LINE and COMMENTS."
  (condition-case err
      (with-temp-buffer
        (when (file-exists-p done-file)
          (insert-file-contents done-file))
        
        (markdown-mode)  ; Enable markdown-mode for helper functions
        
        ;; Find or create heading
        (goto-char (point-min))
        (let ((heading-found nil)
              (insert-pos nil))
          (when heading
            (let ((heading-pattern (concat "^" (regexp-quote (car heading)) "[ \t]+" (regexp-quote (cdr heading)))))
              (while (and (not heading-found) (not (eobp)))
                (when (looking-at heading-pattern)
                  (setq heading-found t)
                  ;; Move to end of this section
                  (condition-case nil
                      (progn
                        (markdown-next-heading)
                        (setq insert-pos (point)))
                    (error
                     (goto-char (point-max))
                     (setq insert-pos (point)))))
                (unless heading-found
                  (forward-line 1)))))
          
          (if heading-found
              ;; Insert at end of section
              (progn
                (goto-char insert-pos)
                (unless (bolp) (insert "\n"))
                (insert task-line "\n")
                (when comments
                  (insert comments)
                  (unless (bolp) (insert "\n"))))
            ;; Create new heading at end
            (goto-char (point-max))
            (when heading
              (unless (bolp) (insert "\n"))
              (when (> (point) 1) (insert "\n"))
              (insert (car heading) " " (cdr heading) "\n\n"))
            (insert task-line "\n")
            (when comments
              (insert comments)
              (unless (bolp) (insert "\n"))))
          
          ;; Write to file
          (write-region (point-min) (point-max) done-file)))
    (error
     (signal (car err) (cdr err)))))

(defun altodo--delete-task-from-buffer ()
  "Delete current task and its multiline comments from buffer."
  (let ((start (line-beginning-position))
        (end nil))
    (let ((region (altodo--get-multiline-comment-region)))
      (if region
          (setq end (cdr region))
        (setq end (line-beginning-position 2))))
    (delete-region start end)))

(defun altodo-move-done-tasks-at-point ()
  "Move done/cancelled task at point to done file.
Returns nil."
  (interactive)
  (unless (buffer-file-name)
    (user-error "Buffer is not visiting a file"))
  
  (unless (altodo--is-done-or-cancelled-task)
    (user-error "Current line is not a done or cancelled task"))
  
  (let* ((done-file (altodo--get-done-file-path))
         (heading (altodo--get-task-heading))
         (task-data (altodo--extract-task-with-comments))
         (task-line (car task-data))
         (comments (cdr task-data)))
    
    (altodo--append-to-done-file done-file heading task-line comments)
    (altodo--delete-task-from-buffer)
    (message "Moved task to %s" done-file)))

(defun altodo-move-all-done-tasks (&optional auto-save)
  "Move all done/cancelled tasks in buffer to done file.
If AUTO-SAVE is non-nil, save buffer after moving tasks."
  (interactive)
  (unless (buffer-file-name)
    (user-error "Buffer is not visiting a file"))
  
  (let ((count 0)
        (original-pos (point)))
    (goto-char (point-min))
    (while (not (eobp))
      (if (altodo--is-done-or-cancelled-task)
          (progn
            (altodo-move-done-tasks-at-point)
            (setq count (1+ count)))
        (forward-line 1)))
    (when (and auto-save (buffer-modified-p))
      (save-buffer))
    (goto-char (min original-pos (point-max)))
    (message "Moved %d task(s) to done file" count)))


;;; Debug System

;; debug-helper is loaded automatically when altodo-debug-mode is t
;; (see defcustom altodo-debug-mode above)

(defgroup altodo-debug nil
  "Debug settings for altodo-mode."
  :group 'altodo)

(defcustom altodo-debug-log-file nil
  "Path to debug log file (absolute path).
If nil, debug log is not written to file."
  :type '(choice (const :tag "No log file" nil)
                 (file :tag "Log file path"))
  :group 'altodo-debug)

(defcustom altodo-debug-log-to-messages nil
  "Also log to *Messages* buffer."
  :type 'boolean
  :group 'altodo-debug)

;; Setup debug helper (only if loaded)
(when (featurep 'debug-helper)
  (debug-helper-setup "altodo" "0.1.0" altodo-debug-log-file altodo-debug-log-to-messages))

;; Override message function to also log to file when altodo-debug-mode is enabled
(when altodo-debug-mode
  (let ((original-message (symbol-function 'message)))
    (defun message (format-string &rest args)
      "Override message to also log to debug file."
      (let ((msg (apply #'format format-string args)))
        ;; Call original message
        (apply original-message format-string args)
        ;; Also log to file if debug mode is enabled
        (when altodo-debug-mode
          (condition-case err
              (let* ((log-file (substitute-in-file-name altodo-debug-log-file))
                     (log-dir (file-name-directory log-file)))
                (unless (file-exists-p log-dir)
                  (let ((inhibit-message t))
                    (make-directory log-dir t)))
                (with-temp-buffer
                  (insert (format "%s\n" msg))
                  (let ((inhibit-message t))
                    (append-to-file (point-min) (point-max) log-file))))
            (error nil)))))))


(defun altodo-debug-enable ()
  "Enable debug logging for altodo functions.
Returns nil."
  (interactive)
  (if (featurep 'debug-helper)
      (progn
        (debug-helper-setup "altodo" "0.1.0" altodo-debug-log-file altodo-debug-log-to-messages altodo--updatedtime)
        (debug-helper-enable))
    (message "debug-helper is not loaded. Set altodo-enable-debug to t and reload altodo.el")))

(defun altodo-debug-disable ()
  "Disable debug logging for altodo functions.
Returns value."
  (interactive)
  (when (featurep 'debug-helper)
    (debug-helper-disable)))

(defun altodo-debug-add-function (function-symbol)
  "Add FUNCTION-SYMBOL to debug list.
Returns nil."
  (interactive "aFunction to debug: ")
  (if (featurep 'debug-helper)
      (progn
        (debug-helper-add-function function-symbol)
        (message "Added %s to debug list" function-symbol))
    (message "debug-helper is not loaded")))

(defun altodo-debug-remove-function (function-symbol)
  "Remove FUNCTION-SYMBOL from debug list.
Returns nil."
  (interactive
   (list (when (featurep 'debug-helper)
           (intern (completing-read "Function to remove: "
                                    debug-helper--functions nil t)))))
  (if (featurep 'debug-helper)
      (progn
        (debug-helper-remove-function function-symbol)
        (message "Removed %s from debug list" function-symbol))
    (message "debug-helper is not loaded")))

(defun altodo-debug-clear-log ()
  "Clear debug log file.
Returns value."
  (interactive)
  (debug-helper-clear-log))

(defun altodo-debug-view-log ()
  "Open debug log file.
Returns value."
  (interactive)
  (debug-helper-view-log))


;;; Display Line Number Calculation

(defun altodo--get-display-line-number (actual-line)
  "Get display line number for ACTUAL-LINE considering invisible lines.
Returns the line number as displayed (counting only visible lines)."
  (save-excursion
    (goto-char (point-min))
    (let ((display-line 1))
      (while (< (line-number-at-pos) actual-line)
        (unless (get-char-property (point) 'invisible)
          (setq display-line (1+ display-line)))
        (forward-line 1))
      display-line)))

(defun altodo--get-actual-line-number (display-line)
  "Get actual line number for DISPLAY-LINE (counting only visible lines).
Returns the actual line number in the buffer."
  (catch 'found
    (save-excursion
      (goto-char (point-min))
      (let ((count 0))
        (while (not (eobp))
          (unless (get-char-property (point) 'invisible)
            (setq count (1+ count)))
          (if (= count display-line)
              (throw 'found (line-number-at-pos)))
          (forward-line 1))
        nil))))

(defun altodo--sidebar-get-line-number-for-entry (entry source-buffer)
  "Get display line number for ENTRY in SOURCE-BUFFER.
Returns the line number as displayed (counting only visible lines)."
  (with-current-buffer source-buffer
    (let ((pattern (plist-get entry :pattern)))
      (when pattern
        (save-excursion
          (goto-char (point-min))
          (let ((display-line 1))
            (while (not (eobp))
              (unless (get-char-property (point) 'invisible)
                (setq display-line (1+ display-line)))
              (forward-line 1))
            display-line))))))

;;; Filter Functions

(defun altodo--filter-init ()
  "Initialize filter system."
  (add-to-invisibility-spec 'altodo-filter))


(defun altodo--find-matching-lines (predicate &optional buf)
  "Find lines matching PREDICATE.
PREDICATE is a function with no arguments that returns t to match.
BUF is the target buffer (default: current buffer).
Returns list of ranges: ((start1 . end1) (start2 . end2) ...)."
  (let ((target-buf (or buf (current-buffer)))
        ranges)
    (with-current-buffer target-buf
      (save-excursion
        (goto-char (point-min))
        (while (not (eobp))
          (when (funcall predicate)
            (push (cons (line-beginning-position)
                        (1+ (line-end-position)))
                  ranges))
          (forward-line 1))))
    (nreverse ranges)))


(defun altodo--invert-ranges (ranges)
  "Invert RANGES to get non-matching ranges.
If RANGES is ((10 . 20) (30 . 40)), returns ((1 . 10) (20 . 30) (40 . end))."
  (let ((result nil)
        (last-end (point-min)))
    (dolist (range ranges)
      (when (< last-end (car range))
        (push (cons last-end (car range)) result))
      (setq last-end (cdr range)))
    (when (< last-end (point-max))
      (push (cons last-end (point-max)) result))
    (nreverse result)))


(defun altodo--merge-consecutive-ranges (ranges)
  "Merge consecutive ranges.
((1 . 10) (10 . 20)) => ((1 . 20))"
  (if (null ranges)
      nil
    (let ((result (list (car ranges))))
      (dolist (range (cdr ranges))
        (let ((last (car result)))
          (if (= (cdr last) (car range))
              ;; 連続している → マージ
              (setcar result (cons (car last) (cdr range)))
            ;; 連続していない → 追加
            (push range result))))
      (nreverse result))))


(defun altodo--create-overlays (ranges)
  "Create overlays for RANGES.
RANGES is a list of (start . end) cons cells.
Returns list of created overlays."
  (mapcar (lambda (range)
            (let ((ov (make-overlay (car range) (cdr range))))
              (overlay-put ov 'invisible 'altodo-filter)
              (overlay-put ov 'evaporate t)
              ov))
          ranges))


(defun altodo--filter-cleanup ()
  "Cleanup filter system."
  (altodo-filter-clear)
  (remove-from-invisibility-spec 'altodo-filter))


(defun altodo-filter-clear ()
  "Clear all filters.
Returns nil."
  (interactive)
  (mapc #'delete-overlay altodo--filter-overlays)
  (setq altodo--filter-overlays nil)
  (setq altodo--filter-mode nil)
  (let ((sidebar-buffer (altodo--get-sidebar-buffer)))
    (when sidebar-buffer
      (with-current-buffer sidebar-buffer
        (setq-local altodo-sidebar--active-entries nil
                    altodo-sidebar--selected-filters nil
                    altodo-sidebar--selection-mode nil
                    altodo-sidebar--current-combined-predicate nil))))
  (altodo-sidebar-refresh)
  (altodo--update-sidebar-modeline)
  (message "Filter cleared"))


(defun altodo-filter-show-done-only ()
  "Show only done tasks.
Returns value."
  (interactive)
  (altodo--filter-lines
   (lambda ()
     (altodo--line-done-p)))
  (setq altodo--filter-mode 'done))


(defun altodo-filter-show-progress-only ()
  "Show only tasks in progress.
Returns value."
  (interactive)
  (altodo--filter-lines
   (lambda ()
     (altodo--line-progress-p)))
  (setq altodo--filter-mode 'progress))

(defun altodo-filter-show-waiting-only ()
  "Show only waiting tasks.
Returns value."
  (interactive)
  (altodo--filter-lines
   (lambda ()
     (altodo--line-state-p altodo-state-waiting)))
  (setq altodo--filter-mode 'waiting))

(defun altodo-filter-show-open-only ()
  "Show only open tasks.
Returns value."
  (interactive)
  (altodo--filter-lines
   (lambda ()
     (altodo--line-open-p)))
  (setq altodo--filter-mode 'open))

(defun altodo-filter-show-cancelled-only ()
  "Show only cancelled tasks.
Returns value."
  (interactive)
  (altodo--filter-lines
   (lambda ()
     (altodo--line-state-p altodo-state-cancelled)))
  (setq altodo--filter-mode 'cancelled))

(defun altodo-filter-show-priority ()
  "Show only tasks with priority flag.
Returns value."
  (interactive)
  (altodo--filter-lines
   (lambda ()
     (altodo--line-has-priority-p)))
  (setq altodo--filter-mode 'priority))

(defun altodo-filter-show-star ()
  "Show only tasks with star flag.
Returns value."
  (interactive)
  (altodo--filter-lines
   (lambda ()
     (altodo--line-has-star-p)))
  (setq altodo--filter-mode 'star))


(defun altodo-filter-show-tag (tag)
  "Show only tasks with TAG.
Returns value."
  (interactive "sTag: ")
  (altodo--filter-lines
   (lambda ()
     (altodo--line-has-tag-p tag)))
  (setq altodo--filter-mode (intern (format "tag:%s" tag)))
  (message "Showing tasks with tag #%s" tag))


(defun altodo-filter-show-overdue ()
  "Show only overdue tasks.
Returns value."
  (interactive)
  (altodo--filter-lines
   (lambda ()
     (and (altodo--task-p)
          (save-excursion
            (re-search-forward "-> [0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}"
                               (line-end-position) t)
            (let ((date-str (match-string 0)))
              (< (altodo--days-diff (altodo--parse-date date-str)) 0))))))
  (setq altodo--filter-mode 'overdue)
  (message "Showing overdue tasks only"))


(defun altodo-filter-show-person (person)
  "Show only tasks with PERSON.
Returns value."
  (interactive "sPerson: ")
  (altodo--filter-lines
   (lambda ()
     (save-excursion
       (re-search-forward (concat "@" (regexp-quote person) "\\>")
                          (line-end-position) t))))
  (setq altodo--filter-mode (intern (format "person:%s" person)))
  (message "Showing tasks with person @%s" person))


;;; Sidebar UI (Phase 5-2)

;; Customization Variables

(defcustom altodo-sidebar-buffer-name "*altodo-filters*"
  "Name of the sidebar buffer."
  :group 'altodo
  :type 'string)

(defvar altodo-sidebar--buffer-alist nil
  "Alist mapping source-buffer to sidebar-buffer.")

(defcustom altodo-sidebar-position 'left
  "Position of sidebar window.
Either 'left, 'right, 'above or 'below.
Can be overridden by .altodo-locals.el."
  :group 'altodo
  :type '(choice (const left) (const right) (const above) (const below)))

(defcustom altodo-sidebar-size 0.2
  "Size of sidebar window.
Either a positive integer (rows/columns) or a percentage (0 < size < 1).
Can be overridden by .altodo-locals.el."
  :group 'altodo
  :type 'number)

(defcustom altodo-sidebar-indent 2
  "Number of spaces for each nesting level.
Can be overridden by .altodo-locals.el."
  :group 'altodo
  :type 'integer)

(defcustom altodo-sidebar-focus-after-activation nil
  "Whether to focus sidebar after activation."
  :group 'altodo
  :type 'boolean)

(defcustom altodo-sidebar-auto-resize nil
  "Whether to auto-resize sidebar window."
  :group 'altodo
  :type 'boolean)

(defcustom altodo-sidebar-hide-mode-line nil
  "Whether to hide mode-line in sidebar."
  :group 'altodo
  :type 'boolean)

(defcustom altodo-sidebar-hide-line-numbers t
  "Whether to hide line numbers in sidebar."
  :group 'altodo
  :type 'boolean)

(defcustom altodo-default-filter-patterns
  '((:title "Status" :type group-header :nest 0)
    (:title "Open [ ] - %n" :type search-simple :pattern "open" :count-format t :nest 1)
    (:title "In Progress [@] - %n" :type search-simple :pattern "progress" :count-format t :nest 1)
    (:title "Waiting [w] - %n" :type search-simple :pattern "waiting" :count-format t :nest 1)
    (:title "Done [x] - %n" :type search-simple :pattern "done" :count-format t :nest 1)
    (:title "Cancelled [~] - %n" :type search-simple :pattern "cancelled" :count-format t :nest 1)
    
    (:title "Flags" :type group-header :nest 0)
    (:title "Priority (!) - %n" :type search-simple :pattern "priority" :count-format t :nest 1)
    (:title "Star (+) - %n" :type search-simple :pattern "star" :count-format t :nest 1
        :count-face-rules ((>= 5 error)
                       (>= 1 warning)))
    (:title "Due" :type group-header :nest 0)
    (:title "Open and Over Due - %n"
            :type search-lambda
            :pattern (lambda ()
                       (and (altodo--due-date-matches-p 'overdue)
                            (not (or (altodo--line-state-p altodo-state-done)
                                     (altodo--line-state-p altodo-state-cancelled)))))
            :count-format t
            :nest 1
            :face-rules ((>= 1 error)))
    (:title "Open and Due Today - %n"
            :type search-lambda
            :pattern (lambda ()
                       (and (altodo--due-date-matches-p 'today)
                            (not (or (altodo--line-state-p altodo-state-done)
                                     (altodo--line-state-p altodo-state-cancelled)))))
            :count-format t :nest 1
            :face-rules ((>= 1 error)))
    (:title "Open and Due This Week - %n"
            :type search-lambda
            :pattern (lambda ()
                       (and (altodo--due-date-matches-p 'this-week)
                            (not (altodo--due-date-matches-p 'today))
                            (not (or (altodo--line-state-p altodo-state-done)
                                     (altodo--line-state-p altodo-state-cancelled)))))
            :count-format t :nest 1)
    (:title "Section" :type separator :pattern "─" :nest 0)
    (:title "[Clear Filter]" :type command :nest 0 :command altodo-filter-clear)
    )
  "Default filter patterns for sidebar when .altodo-locals.el is not found.
Each entry is a plist with properties like :title, :type, :pattern, etc.
See `doc/design-filter.md` for detailed specification."
  :type '(repeat plist)
  :group 'altodo)

(defvar-local altodo-sidebar--source-buffer nil
  "The altodo buffer that this sidebar is associated with.")

(defvar-local altodo-sidebar--active-entries nil
  "List of currently active entries in sidebar.
Each element is an entry plist from altodo-filter-patterns.
Used for applying face to selected filters.")

;; Phase 5-5: Multiple filter selection state management
(defvar-local altodo-sidebar--selected-filters nil
  "List of selected filters in multiple selection mode.
Each element is an entry plist from altodo-filter-patterns.")

(defvar-local altodo-sidebar--combine-mode 'and
  "Combine mode for multiple filters: 'and or 'or.
Default: 'and (more restrictive).")

(defvar-local altodo-sidebar--selection-mode nil
  "Current selection mode: 'single, 'multiple, or nil (no selection).")

(defvar-local altodo-sidebar--current-combined-predicate nil
  "Current combined predicate for multiple filter selection.
Set by altodo-sidebar--apply-combined-filter.
Used by sidebar--render for dynamic count calculation.")

;; Generic Sidebar Framework Functions

(defun sidebar-display (config)
  "Display sidebar with CONFIG.
CONFIG is a plist with :name, :position, :width, :dedicated, :entries.
Returns the displayed window."
  (let ((buf (get-buffer-create (plist-get config :name))))
    (sidebar--setup-buffer buf config)
    (let ((action (sidebar--make-display-action config)))
      (let ((win (display-buffer buf action)))
        ;; Render after window is displayed
        (sidebar--render buf config)
        win))))

(defun sidebar--update-faces (buffer config &optional source-buffer)
  "Update faces for all entries in BUFFER based on CONFIG.
Does not re-render the buffer, only updates face properties."
  (with-current-buffer buffer
    (let ((inhibit-read-only t)
          (entries (plist-get config :entries)))
      (save-excursion
        (goto-char (point-min))
        (dolist (entry entries)
          (let ((face (sidebar--get-face entry config source-buffer))
                (title (plist-get entry :title)))
            ;; Find the button for this entry on the current line
            (let ((button (button-at (point))))
              (if button
                  (progn
                    ;; Update button face
                    (put-text-property (button-start button) (button-end button) 'face face))))
            ;; Move to next line
            (forward-line)))))))

(defun sidebar--render (buffer config)
  "Render entries in BUFFER based on CONFIG.
Clears BUFFER and inserts all entries from CONFIG.
Uses the source buffer (altodo main buffer) for counting."
  (let ((source-buffer (plist-get config :source-buffer))
        (sidebar-window (get-buffer-window buffer))
        ;; 保存された複合 predicate を取得（再生成なし）
        (combined-predicate (when (and altodo-sidebar-dynamic-count-enabled
                                       (eq altodo-sidebar--selection-mode 'multiple))
                              altodo-sidebar--current-combined-predicate))
        (combine-mode altodo-sidebar--combine-mode))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (unless (and source-buffer (buffer-live-p source-buffer))
          (setq altodo-sidebar--current-combined-predicate nil
                combined-predicate nil))
        (dolist (entry (plist-get config :entries))
          (if (or (eq (plist-get entry :type) 'dynamic)
                  (equal (plist-get entry :type) "dynamic"))
              (dolist (expanded (altodo--expand-dynamic-filter entry source-buffer combined-predicate))
                (sidebar--insert-entry expanded config source-buffer sidebar-window combined-predicate combine-mode))
            (sidebar--insert-entry entry config source-buffer sidebar-window combined-predicate combine-mode)))))))

(defun altodo--make-repeated-pattern (pattern width)
  "Create a repeated PATTERN string to fill WIDTH display columns.
Returns the repeated pattern truncated or padded to WIDTH."
  (let ((pattern-width (string-width pattern)))
    (if (<= pattern-width 0)
        ""
      (let ((repeat-count (/ width pattern-width))
            (remainder (% width pattern-width)))
        (concat (apply #'concat (make-list repeat-count pattern))
                (substring pattern 0 (max 0 (/ (* remainder (length pattern)) pattern-width))))))))

(defun altodo--make-separator-with-title (title pattern available-width)
  "Create separator line with TITLE in center, filled with PATTERN.
AVAILABLE-WIDTH is in display columns (accounting for wide characters).
Returns the separator string or just TITLE if it doesn't fit."
  (let* ((title-text (if (string-empty-p title) "" (concat " " title " ")))
         (title-width (string-width title-text)))
    (if (>= title-width available-width)
        title-text
      (let* ((remaining-width (max 0 (- available-width title-width)))
             (left-width (/ remaining-width 2))
             (right-width (- remaining-width left-width)))
        (concat (altodo--make-repeated-pattern pattern left-width)
                title-text
                (altodo--make-repeated-pattern pattern right-width))))))

(defun altodo--make-separator-line (sidebar-window indent title pattern)
  "Create a separator line with proper width calculation.
Returns the full separator line string."
  (let* ((window-width (if sidebar-window 
                          (window-body-width sidebar-window)
                          (window-body-width (selected-window))))
         (available-width (max 1 (- window-width (string-width indent))))
         (separator-text (altodo--make-separator-with-title title pattern available-width)))
    (concat indent separator-text)))

(defun sidebar--insert-entry (entry config &optional source-buffer sidebar-window combined-predicate combine-mode)
  "Insert ENTRY into sidebar buffer based on CONFIG.
Creates a clickable button with appropriate indentation and face.
SOURCE-BUFFER is the main altodo buffer for counting matches.
SIDEBAR-WINDOW is the sidebar window for width calculation.
COMBINED-PREDICATE is the combined predicate for dynamic count calculation.
COMBINE-MODE is 'and or 'or, used to determine whether to apply combined-predicate."
  (let* ((title (altodo--format-sidebar-title entry source-buffer combined-predicate combine-mode))
         (type (plist-get entry :type))
         (nest (or (plist-get entry :nest) 0))
         (action (and (not (member type '(separator group-header comment nil)))
                      (or (plist-get entry :action)
                          #'altodo-sidebar--apply-filter)))
         (indent (make-string (* nest (plist-get config :indent)) ?\s))
         (face (sidebar--get-face entry config source-buffer)))
    
    (cond
     ;; Separator - fill line with repeated pattern, optionally with title
     ((eq type 'separator)
      (let ((full-line (altodo--make-separator-line sidebar-window indent title 
                                                     (or (plist-get entry :pattern) "─"))))
        (insert (propertize full-line 'face face 'read-only t))))
     
     ;; Non-clickable entry (no action)
     ((null action)
      (let* ((is-selection (or (eq face 'altodo-sidebar-selected-filter-face)
                               (eq face 'altodo-sidebar-active-filter-face)))
             (effective-title (if is-selection (substring-no-properties title) title))
             (full-line (concat indent effective-title)))
        (if is-selection
            ;; Selection face: apply to entire line
            (insert (propertize full-line 'face face 'read-only t))
          ;; Non-selection: preserve title's existing face properties
          (when (> (length indent) 0)
            (put-text-property 0 (length indent) 'face face full-line))
          (let ((pos (length indent)))
            (while (< pos (length full-line))
              (unless (get-text-property pos 'face full-line)
                (put-text-property pos (1+ pos) 'face face full-line))
              (setq pos (1+ pos))))
          (insert (propertize full-line 'read-only t)))))
     
     ;; Clickable button (default)
     (t
      (insert (propertize indent 'face face))
      ;; Selection face (Layer 1) overrides all existing face properties
      (let ((is-selection (or (eq face 'altodo-sidebar-selected-filter-face)
                              (eq face 'altodo-sidebar-active-filter-face))))
        (if (and (not is-selection) (altodo--string-has-face-property title))
            ;; Non-selection: preserve title's existing face properties
            (let ((start (point)))
              (insert title)
              (altodo--apply-face-to-unfaced-text start (point) face)
              (make-text-button start (point)
                                'type 'button
                                'follow-link t
                                'action action
                                'sidebar-entry entry
                                'sidebar-config config
                                'help-echo nil
                                'mouse-face 'highlight))
          ;; Selection or no face property: apply face to entire title
          (insert-button (if is-selection (substring-no-properties title) title)
                         'type 'button
                         'face face
                         'follow-link t
                         'action action
                         'sidebar-entry entry
                         'sidebar-config config
                         'help-echo nil
                         'mouse-face 'highlight)))))
    
    (insert "\n")))

(defun sidebar--make-display-action (config)
  "Create display action from CONFIG.
Returns display action (function . alist) per GNU Emacs manual."
  `(display-buffer-in-side-window
    . ((side . ,(plist-get config :position))
       (slot . 0)
       (dedicated . side))))

(defun sidebar--setup-buffer (buffer config)
  "Setup BUFFER for sidebar display.
Enables special-mode, sets read-only, and configures mode-line."
  (with-current-buffer buffer
    (special-mode)
    (setq buffer-read-only t)
    (setq mode-name (format "Sidebar: %s" (plist-get config :name)))
    ;; Setup sidebar-specific mode-line (must be after special-mode)
    (if altodo-sidebar-hide-mode-line
        (setq-local mode-line-format nil)
      (setq-local mode-line-format
                  '("%e"
                    " "
                    (:eval (or altodo-sidebar-modeline-string ""))
                    " "
                    mode-line-end-spaces)))
    ;; Hide line numbers if configured
    (when altodo-sidebar-hide-line-numbers
      (when (fboundp 'display-line-numbers-mode)
        (display-line-numbers-mode -1))
      (setq-local display-line-numbers nil))
    ;; Setup keybindings
    (sidebar--setup-keybindings)))

(defvar altodo-sidebar-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") 'sidebar--apply-filter-at-point)
    (define-key map (kbd "SPC") 'sidebar--apply-filter-at-point)
    (define-key map (kbd "c") 'altodo-filter-clear)
    (define-key map (kbd "r") 'altodo-sidebar-refresh)
    (define-key map (kbd "q") 'altodo-sidebar-hide)
    (define-key map (kbd "n") 'next-line)
    (define-key map (kbd "p") 'previous-line)
    ;; Phase 5-5: Multiple filter selection keybindings
    (define-key map (kbd "s") 'altodo-sidebar-toggle-selection)
    (define-key map (kbd "C-c C-a") 'altodo-sidebar-set-and-mode)
    (define-key map (kbd "C-c C-o") 'altodo-sidebar-set-or-mode)
    (define-key map (kbd "C-c C-t") 'altodo-sidebar-toggle-combine-mode)
    (define-key map (kbd "C-<mouse-1>") 'altodo-sidebar-mouse-toggle-selection)
    map)
  "Keymap for altodo sidebar.")

(defun sidebar--setup-keybindings ()
  "Setup keybindings for sidebar buffer.
Returns value."
  (use-local-map altodo-sidebar-mode-map))

(defun sidebar--apply-filter-at-point ()
  "Apply filter at point in sidebar.
Returns value."
  (interactive)
  (let ((button (button-at (point))))
    (if button
        (let ((inhibit-read-only t))
          (altodo-sidebar--apply-filter button))
      (message "No filter at point"))))

(defun sidebar--get-face (entry config &optional source-buffer)
  "Get face for ENTRY based on CONFIG using selection mode.
SOURCE-BUFFER is used for :face-rules evaluation.
Returns face symbol based on current selection mode."
  (let* ((selection-mode (buffer-local-value 'altodo-sidebar--selection-mode (current-buffer)))
         (selected-filters (buffer-local-value 'altodo-sidebar--selected-filters (current-buffer)))
         (active-entries (buffer-local-value 'altodo-sidebar--active-entries (current-buffer)))
         (face-spec (plist-get entry :face))
         (face-rules (plist-get entry :face-rules)))
    
    (cond
      ;; Layer 1: Selection mode (highest priority)
      ((and selected-filters (member entry selected-filters))
       'altodo-sidebar-selected-filter-face)
      
      ((and active-entries (equal (car active-entries) entry))
       'altodo-sidebar-active-filter-face)
      
      ;; Layer 2: Face rules (title-wide face)
      ((and (plist-get entry :count-format)
            (or (plist-get entry :face-rules)
                (plist-get entry :count-face-rules)))
       (let ((count (altodo--get-entry-count entry source-buffer))
             (rules (or face-rules (plist-get entry :count-face-rules))))
         (let ((face-rules-result (altodo--evaluate-face-rules rules count)))
           (if face-rules-result
               face-rules-result
             ;; If no rule matches, fall through to Layer 4/5
             (or (sidebar--resolve-face face-spec)
                 (sidebar--default-face (plist-get entry :type)
                                        (plist-get entry :nest)))))))
      
      ;; Layer 4: Static face
      ((sidebar--resolve-face face-spec)
       (sidebar--resolve-face face-spec))
      
      ;; Layer 5: Default face
      (t
        (sidebar--default-face (plist-get entry :type)
                               (plist-get entry :nest))))))


(defun sidebar--resolve-face (face-spec)
  "Resolve FACE-SPEC to actual face symbol or spec.
FACE-SPEC can be:
- nil (use default)
- face symbol (e.g., 'bold, 'done-face)
- face spec (e.g., ((t (:foreground \"green\"))))"
  (cond
   ;; nil - use default (handled by caller)
   ((null face-spec) nil)
   
   ;; Face spec (list starting with (t ...))
   ;; Convert to anonymous face (list of attributes)
   ((and (listp face-spec) (listp (car face-spec)))
    ;; Extract attributes from ((t (:foreground "red" ...)))
    ;; to (:foreground "red" ...)
    (let ((display-spec (car face-spec)))
      (when (eq (car display-spec) 't)
        (cadr display-spec))))
   
   ;; Face symbol
   ((symbolp face-spec)
    face-spec)
   
   (t nil)))

(defun sidebar--default-face (type nest)
  "Get default face for TYPE and NEST level.
Returns appropriate face based on entry type."
  (cond
   ((eq type 'group-header) 'altodo-sidebar-group-header-face)
   ((eq type 'search-simple) 'altodo-sidebar-search-simple-face)
   ((eq type 'search-lambda) 'altodo-sidebar-search-lambda-face)
   ((eq type 'command) 'altodo-sidebar-command-face)
   ((eq type 'separator) 'altodo-sidebar-separator-face)
   ((or (eq type 'comment) (null type)) 'altodo-sidebar-comment-face)
   (t 'default)))

;; altodo-specific Functions

(defun altodo--get-sidebar-face-alist ()
  "Get sidebar face alist from .altodo-locals.el.
Returns alist of (face-name . face-spec) or nil."
  (let ((locals (altodo--load-locals-file)))
    (cdr (assq 'altodo-sidebar-face-alist locals))))

(defun altodo--register-sidebar-faces ()
  "Register sidebar faces from .altodo-locals.el to Emacs face list.
Converts face specs from altodo-sidebar-face-alist to defface."
  (let ((face-alist (altodo--get-sidebar-face-alist)))
    (dolist (entry face-alist)
      (let ((face-name (car entry))
            (face-spec (cdr entry)))
        ;; face-name が既に定義されていなければ、face-spec を使用して定義
        (unless (facep face-name)
          (custom-declare-face face-name face-spec
            (format "Sidebar face: %s" face-name)))))))

(defun altodo--load-locals-file ()
  "Load .altodo-locals.el from the same directory as the current buffer.
Returns alist with configuration or nil if file not found."
  (when buffer-file-name
    (let ((locals-file (expand-file-name ".altodo-locals.el"
                                         (file-name-directory buffer-file-name))))
      (when (file-exists-p locals-file)
        (with-temp-buffer
          (insert-file-contents locals-file)
          (read (current-buffer)))))))

(defun altodo--get-filter-patterns ()
  "Get filter patterns from .altodo-locals.el.
Returns list of pattern plists or nil if not found."
  (let ((locals (altodo--load-locals-file)))
    (let ((result (cdr (assq 'altodo-filter-patterns locals))))
      result)))

(defun altodo--get-locals-value (key)
  "Get value for KEY from .altodo-locals.el.
Returns value or nil if not found."
  (let ((locals (altodo--load-locals-file)))
    (cdr (assq key locals))))

(defun altodo--parent-task-matches-regexp-p (regexp)
  "Check if parent task matches REGEXP.
Returns t if current task has a parent and parent matches REGEXP."
  (save-excursion
    (let ((current-indent (current-indentation)))
      (when (> current-indent 0)
        (forward-line -1)
        (while (and (not (bobp))
                    (>= (current-indentation) current-indent))
          (forward-line -1))
        (and (< (current-indentation) current-indent)
             (altodo--task-p)
             (re-search-forward regexp (line-end-position) t)
             t)))))

(defun altodo--root-parent-task-matches-regexp-p (regexp)
  "Check if root parent task (nest=0) matches REGEXP.
Returns t if current task has a root parent and it matches REGEXP."
  (save-excursion
    (let ((current-indent (current-indentation)))
      (when (> current-indent 0)
        ;; Go to beginning of buffer or first line with indent 0
        (while (and (not (bobp))
                    (> (current-indentation) 0))
          (forward-line -1))
        (and (= (current-indentation) 0)
             (altodo--task-p)
             (re-search-forward regexp (line-end-position) t)
             t)))))

(defun altodo--heading-level ()
  "Get heading level of current line.
Returns integer (1, 2, 3, ...) if current line is a heading, nil otherwise.
Supports both ATX (# ## ###) and Setext (=== or ---) syntax."
  (save-excursion
    (beginning-of-line)
    ;; Check ATX syntax
    (if (looking-at "^\\(#+\\)[ \t]+")
        (length (match-string 1))
      ;; Check Setext syntax (next line)
      (let ((current-line (line-number-at-pos)))
        (forward-line 1)
        (when (and (< (line-number-at-pos) (+ current-line 2))
                   (looking-at "^\\(=+\\|-+\\)[ \t]*$"))
          (if (looking-at "^=+")
              1
            2))))))

(defun altodo--heading-text ()
  "Get heading text of current line.
Returns heading text (without #) if current line is a heading, nil otherwise.
Supports both ATX (# ## ###) and Setext (=== or ---) syntax."
  (save-excursion
    (beginning-of-line)
    ;; Check ATX syntax
    (if (looking-at "^#+[ \t]+\\(.+\\)$")
        (match-string 1)
      ;; Check Setext syntax (next line)
      (let ((current-line (line-number-at-pos)))
        (forward-line 1)
        (when (and (< (line-number-at-pos) (+ current-line 2))
                   (looking-at "^\\(=+\\|-+\\)[ \t]*$"))
          (forward-line -1)
          (beginning-of-line)
          (when (looking-at "^\\(.+\\)$")
            (match-string 1)))))))

(defun altodo--compute-all-heading-ranges ()
  "Compute all heading ranges in buffer and cache them.
Returns alist of (heading-regexp . (start . end))."
  (let ((cache nil))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (when (altodo--heading-level)
          (let ((heading-text (altodo--heading-text)))
            (when heading-text
              (let ((range (altodo--find-heading-range heading-text t)))
                (when range
                  (push (cons heading-text range) cache))))))
        (forward-line 1)))
    (setq altodo--heading-cache (nreverse cache))
    altodo--heading-cache))

(defun altodo--find-heading-range (heading-regexp &optional include-children)
  "Find range of lines under heading matching HEADING-REGEXP.
INCLUDE-CHILDREN: if t, include child headings; if nil, exclude them.
Returns (start . end) where start is line after heading, end is before next same-level heading.
Returns nil if heading not found."
  (save-excursion
    (let ((heading-level nil)
          (start nil)
          (end nil))
      ;; Search for heading
      (goto-char (point-min))
      (if (not (re-search-forward (concat "^#+[ \t]+" heading-regexp) nil t))
          nil
        ;; Get heading level
        (beginning-of-line)
        (setq heading-level (altodo--heading-level))
        (setq start (line-beginning-position 2))  ; Next line after heading
        
        ;; Find end of range
        (forward-line 1)
        (while (and (not (eobp))
                    (let ((current-level (altodo--heading-level)))
                      (cond
                        ;; No heading on this line - continue
                        ((null current-level) t)
                        ;; Child heading and include-children is t - continue
                        ((and include-children (> current-level heading-level)) t)
                        ;; Same or higher level heading - stop
                        ((<= current-level heading-level) nil)
                        ;; Child heading but include-children is nil - stop
                        (t nil))))
          (forward-line 1))
        
        (setq end (line-beginning-position))
        (cons start end)))))

(defun altodo--line-in-heading-range-p (heading-regexp &optional include-children)
  "Check if current line is in range of heading matching HEADING-REGEXP.
INCLUDE-CHILDREN: if t, include child headings; if nil, exclude them.
Returns t if in range, nil otherwise."
  (let ((range (altodo--find-heading-range heading-regexp include-children)))
    (when range
      (and (>= (point) (car range))
           (< (point) (cdr range))))))

(defun altodo--line-in-heading-range-with-filter-p (heading-regexp &optional include-children headings-option)
  "Check if current line should be displayed based on heading filter.
HEADING-REGEXP: regex to match heading
INCLUDE-CHILDREN: if t, include child headings (default: t)
HEADINGS-OPTION: 'all, 'all-without-heading-line, 'only-tasks, 'only-tasks-without-heading-line (default: 'only-tasks)
Returns t if line should be displayed, nil otherwise.

Uses cached heading ranges for optimization (Phase 1)."
  (setq include-children (if include-children t t))
  (setq headings-option (or headings-option 'only-tasks))
  
  ;; Try to get range from cache first (Phase 1 optimization)
  (let ((range (or (altodo--get-cached-heading-range heading-regexp)
                   (altodo--find-heading-range heading-regexp include-children))))
    (if (not range)
        nil
      ;; Check if current line is in range
      (if (not (and (>= (point) (car range))
                    (< (point) (cdr range))))
          nil
        ;; Apply headings-option filter
        (let ((is-heading (altodo--heading-level))
              (is-task (altodo--task-p))
              (is-comment (altodo--comment-p))
              (is-multiline-comment (altodo--multiline-comment-p)))
          (pcase headings-option
            ('all t)  ; Show all lines
            ('all-without-heading-line (not is-heading))  ; Hide heading lines
            ('only-tasks (and (or is-task is-comment is-multiline-comment)
                              (not is-heading)))  ; Show only task/comment lines, not headings
            ('only-tasks-without-heading-line (and (or is-task is-comment is-multiline-comment)
                                                    (not is-heading)))  ; Show task/comment but not heading
            (_ nil)))))))

(defun altodo--get-multiline-comment-range ()
  "Get range of multiline comments following current line.
Returns (start . end) cons cell or nil if no multiline comments follow.
Assumes current line is a task or comment line."
  (save-excursion
    (forward-line 1)
    (let ((start (line-beginning-position))
          (end nil))
      ;; Collect multiline comment lines
      (while (and (not (eobp))
                  (altodo--multiline-comment-p))
        (forward-line 1))
      (setq end (point))
      
      (if (> end start)
          (cons start end)
        nil))))

(defun altodo--line-has-multiline-comment-p ()
  "Check if current line has multiline comments.
Returns t if current task/comment line has multiline comments, nil otherwise."
  (and (or (altodo--task-p) (altodo--comment-p))
       (altodo--get-multiline-comment-range)
       t))

(defun altodo--multiline-comment-contains-regexp-p (regexp)
  "Check if multiline comments contain REGEXP.
Returns t if current task/comment line has multiline comments containing REGEXP, nil otherwise."
  (let ((range (altodo--get-multiline-comment-range)))
    (when range
      (save-excursion
        (goto-char (car range))
        (re-search-forward regexp (cdr range) t)))))

;;; seq-tasks Helper Functions

(defun altodo--line-extract-tag-value (tag)
  "Extract TAG:VALUE from current line.
Returns VALUE string or nil if not found.
TAG should be a string like \"dep\" (without #).
Returns plain text without any face properties."
  (save-excursion
    (beginning-of-line)
    (when (re-search-forward (format "#%s:\\([a-zA-Z0-9_-]+\\)" (regexp-quote tag)) (line-end-position) t)
      (substring-no-properties (match-string 1)))))

(defun altodo--person-tag-regex ()
  "Return regex pattern for matching @person tags.
Matches @person with support for ASCII and multi-byte characters.
Excludes space characters only (@ [ ] are allowed in person names)."
  "@\\([a-zA-Z0-9_\\-]+\\|[^[:space:]]+\\)")

(defun altodo--line-task-body ()
  "Extract task body from current line.
Returns the text after the task bracket (e.g., '[ ]' or '[x]').
Returns nil if current line is not a task line.
Returns plain text without any face properties."
  (when (altodo--task-p)
    (save-excursion
      (beginning-of-line)
      (when (re-search-forward "^[ ]*\\[[^]]*\\][ ]*\\(.*\\)$" (line-end-position) t)
        (substring-no-properties (match-string 1))))))

(defun altodo--line-extract-person-value ()
  "Extract @person from current line's task body.
Returns person name or nil if not found.
Only searches in task body (after the task bracket).
Supports ASCII and multi-byte characters (Japanese, etc).
Returns plain text without any face properties."
  (let ((body (altodo--line-task-body)))
    (when body
      (when (string-match "@\\([^[:space:]]+\\)" body)
        (let ((person (match-string 1 body)))
          ;; Exclude @ followed by ] or [
          (unless (or (string-match "^\\]" person)
                      (string-match "^\\[" person))
            ;; Return plain text without face properties
            (substring-no-properties person)))))))

(defun altodo--collect-dynamic-values (dynamic-type source-buffer &optional ignore-value)
  "Collect values of DYNAMIC-TYPE from SOURCE-BUFFER.
If IGNORE-VALUE is t and DYNAMIC-TYPE is \"tag\", collect tag names only.
Returns alist of (value . count)."
  (altodo--collect-dynamic-values-with-exclude dynamic-type source-buffer ignore-value nil nil nil))

(defun altodo--should-exclude-value (value dynamic-type exclude-person exclude-tag exclude-tag-value)
  "Check if VALUE should be excluded based on DYNAMIC-TYPE and exclusion lists.
Returns t if value should be excluded, nil otherwise."
  (catch 'excluded
    (when (and (equal dynamic-type "person") exclude-person)
      (dolist (exc exclude-person)
        (when (string-match (regexp-quote exc) value)
          (throw 'excluded t))))
    (when (and (equal dynamic-type "tag") exclude-tag)
      (dolist (exc exclude-tag)
        (when (string-match (regexp-quote exc) value)
          (throw 'excluded t))))
    (when (and (equal dynamic-type "tag") exclude-tag-value)
      (dolist (exc exclude-tag-value)
        (when (string-match (regexp-quote exc) value)
          (throw 'excluded t))))
    nil))

(defun altodo--extract-dynamic-value (dynamic-type ignore-value)
  "Extract value of DYNAMIC-TYPE from current line.
If IGNORE-VALUE is t and DYNAMIC-TYPE is \"tag\", extract tag name only.
Returns value string or nil if not found."
  (cond
   ((equal dynamic-type "person")
    (altodo--line-extract-person-value))
   ((equal dynamic-type "tag")
    (save-excursion
      (beginning-of-line)
      (when (re-search-forward "#\\([a-zA-Z0-9_-]+\\):\\([a-zA-Z0-9_-]+\\)" (line-end-position) t)
        (if ignore-value
            (match-string 1)
          (concat (match-string 1) ":" (match-string 2))))))
   ((equal dynamic-type "due")
    (altodo--line-extract-tag-value "due"))
   ((equal dynamic-type "start")
    (altodo--line-extract-tag-value "start"))))

(defun altodo--collect-dynamic-values-with-exclude (dynamic-type source-buffer &optional ignore-value exclude-person exclude-tag exclude-tag-value predicate)
  "Collect values of DYNAMIC-TYPE from SOURCE-BUFFER with exclusions.
If IGNORE-VALUE is t and DYNAMIC-TYPE is \"tag\", collect tag names only.
EXCLUDE-PERSON, EXCLUDE-TAG, EXCLUDE-TAG-VALUE are lists of patterns to exclude.
PREDICATE is an optional predicate function to filter lines (called at line beginning).
Returns alist of (value . count)."
  (with-current-buffer source-buffer
    (let ((values (make-hash-table :test 'equal)))
      (save-excursion
        (goto-char (point-min))
        (while (not (eobp))
          (when (and (altodo--task-p)
                     (or (not predicate) (funcall predicate)))
            (let ((value (altodo--extract-dynamic-value dynamic-type ignore-value)))
              (when (and value
                         (not (altodo--should-exclude-value value dynamic-type
                                                           exclude-person exclude-tag exclude-tag-value)))
                (puthash value (1+ (gethash value values 0)) values))))
          (forward-line 1)))
      (let ((result nil))
        (maphash (lambda (k v) (push (cons k v) result)) values)
        result))))

(defun altodo--sort-dynamic-values (alist sort-by)
  "Sort ALIST by SORT-BY. \"alpha\" for alphabetical, \"count\" for count descending."
  (sort alist
        (if (equal sort-by "count")
            (lambda (a b) (> (cdr a) (cdr b)))
          (lambda (a b) (string< (car a) (car b))))))

(defun altodo--limit-dynamic-values (alist limit)
  "Limit ALIST to LIMIT rows. If LIMIT is nil, return all."
  (if limit
      (cl-subseq alist 0 (min limit (length alist)))
    alist))

(defun altodo--format-placeholder (text replacements)
  "Replace placeholders in TEXT with REPLACEMENTS.
REPLACEMENTS is alist of (placeholder . value).
Returns plain text without any face properties."
  (let ((result (substring-no-properties text)))
    (dolist (replacement replacements result)
      (let ((placeholder (car replacement))
            (value (substring-no-properties (format "%s" (cdr replacement)))))
        (setq result (replace-regexp-in-string
                      (regexp-quote (format "%%%s" placeholder))
                      value result t t))))))

(defun altodo--expand-dynamic-filter (entry source-buffer &optional combined-predicate)
  "Expand dynamic filter ENTRY to actual filter entries using SOURCE-BUFFER.
If COMBINED-PREDICATE is provided, filter values based on combined predicate."
  (let* ((dynamic-type (plist-get entry :dynamic-type))
         (tag-ignore-value (plist-get entry :tag-ignore-value))
         (sort-by (or (plist-get entry :sort-by) "alpha"))
         (limit (plist-get entry :limit))
         (count-format (if (plist-member entry :count-format)
                           (plist-get entry :count-format)
                         t))
         (nest (or (plist-get entry :nest) 0))
         (face (plist-get entry :face))
         (face-count (plist-get entry :face-count))
         (title (plist-get entry :title))
         (exclude-person (plist-get entry :exclude-person))
         (exclude-tag (plist-get entry :exclude-tag))
         (exclude-tag-value (plist-get entry :exclude-tag-value))
         ;; 複合フィルタ下での値収集
         (alist (altodo--collect-dynamic-values-with-exclude 
                 dynamic-type source-buffer tag-ignore-value 
                 exclude-person exclude-tag exclude-tag-value combined-predicate))
         (sorted (if (member dynamic-type '("person" "tag"))
                     (altodo--sort-dynamic-values alist sort-by)
                   (altodo--sort-dynamic-values alist "alpha")))
         (limited (altodo--limit-dynamic-values sorted limit)))
    (mapcar (lambda (item)
              (let* ((value (car item))
                     (count (cdr item))
                     ;; %s のみ置換、%n は altodo--format-sidebar-title で再計算される
                     (entry-title (altodo--format-placeholder
                                   title `(("s" . ,value))))
                     (pattern (cond
                               ((equal dynamic-type "person")
                                (format "person:%s" value))
                               ((equal dynamic-type "due")
                                (format "due-date:%s" value))
                               ((equal dynamic-type "start")
                                (format "start-date:%s" value))
                               (t (format "tag:%s" value)))))
                `(:title ,entry-title
                  :type search-simple
                  :pattern ,pattern
                  :nest ,nest
                  ,@(when face `(:face ,face))
                  ,@(when face-count `(:face-count ,face-count))
                  ,@(when count-format `(:count-format ,count-format)))))
            limited)))

(defun altodo--find-line-with-tag (tag value)
  "Find line number with #TAG:VALUE.
Returns line number (1-based) or nil if not found."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward (format "#%s:%s" (regexp-quote tag) (regexp-quote value)) nil t)
      (line-number-at-pos))))

(defun altodo-goto-dependency ()
  "Jump to dependency target line.
If current line has #dep:xxx, jump to line with #id:xxx.
Returns nil."
  (interactive)
  (let ((dep-id (altodo--line-extract-tag-value "dep")))
    (if dep-id
        (let ((target-line (altodo--find-line-with-tag "id" dep-id)))
          (if target-line
              (progn
                (goto-line target-line)
                (message "Jumped to dependency: #id:%s" dep-id))
            (message "Dependency target not found: #id:%s" dep-id)))
      (message "No dependency tag found on current line"))))

(defun altodo--has-seq-tasks-tag ()
  "Check if current line has #seq-tasks tag."
  (save-excursion
    (beginning-of-line)
    (re-search-forward "#seq-tasks" (line-end-position) t)))

(defun altodo--get-seq-tasks-parent ()
  "Get parent task with #seq-tasks tag."
  (save-excursion
    (let ((current-indent (altodo--get-current-indent))
          (found nil))
      (while (and (> current-indent 0) (= (forward-line -1) 0) (not found))
        (let ((line-indent (altodo--get-current-indent)))
          (when (and (< line-indent current-indent)
                     (altodo--task-p)
                     (altodo--has-seq-tasks-tag))
            (setq found (cons (line-number-at-pos) (point))))))
      found)))

(defun altodo--get-seq-tasks-children ()
  "Get direct child tasks of current task."
  (save-excursion
    (let ((parent-indent (altodo--get-current-indent))
          (children nil))
      (when (= (forward-line 1) 0)
        (while (and (not (eobp))
                    (or (not (altodo--task-p))
                        (> (altodo--get-current-indent) parent-indent)))
          (let ((line-indent (altodo--get-current-indent)))
            (when (and (= line-indent (+ parent-indent altodo-indent-size))
                       (altodo--task-p))
              (push (cons (line-number-at-pos) (point)) children)))
          (when (= (forward-line 1) 1)
            (goto-char (point-max)))))
      (nreverse children))))

(defun altodo--get-seq-tasks-status ()
  "Get status of current seq-tasks task.
Parent depends on all children:
- If all children are completed, parent is ready
- If any child is open/progress, parent is blocked"
  (if (not (altodo--has-seq-tasks-tag))
      'none
    (save-excursion
      (beginning-of-line)
      (when (looking-at altodo-task-regex)
        (let ((state (altodo--normalize-state (match-string 2))))
          (if (altodo--task-is-completed state)
              'completed
            (let ((children (altodo--get-seq-tasks-children)))
              (if (null children)
                  'ready
                ;; Check if all children are completed
                (let ((all-completed t))
                  (dolist (child children)
                    (save-excursion
                      (goto-char (cdr child))
                      (beginning-of-line)
                      (when (looking-at altodo-task-regex)
                        (let ((child-state (altodo--normalize-state (match-string 2))))
                          (unless (altodo--task-is-completed child-state)
                            (setq all-completed nil))))))
                  (if all-completed 'ready 'blocked))))))))))

(defun altodo--update-seq-tasks-status ()
  "Update seq-tasks status when task state changes."
  (when (altodo--has-seq-tasks-tag)
    (let ((parent (altodo--get-seq-tasks-parent)))
      (when parent
        (save-excursion
          (goto-char (cdr parent))
          (font-lock-fontify-line))))))

;;; seq-tasks Filter Functions

(defun altodo--line-seq-tasks-ready-p ()
  "Check if current line is a ready seq-tasks task."
  (and (altodo--task-p)
       (altodo--has-seq-tasks-tag)
       (eq (altodo--get-seq-tasks-status) 'ready)))

(defun altodo--line-seq-tasks-blocked-p ()
  "Check if current line is a blocked seq-tasks task."
  (and (altodo--task-p)
       (altodo--has-seq-tasks-tag)
       (eq (altodo--get-seq-tasks-status) 'blocked)))

(defun altodo--is-seq-tasks-child-blocked-p ()
  "Check if current line is a child of seq-tasks with incomplete previous sibling."
  (when (altodo--task-p)
    (let ((current-indent (altodo--get-current-indent))
          (current-line (line-number-at-pos)))
      (save-excursion
        (beginning-of-line)
        ;; Find direct parent
        (forward-line -1)
        (while (and (not (bobp))
                    (or (not (altodo--task-p))
                        (>= (altodo--get-current-indent) current-indent)))
          (forward-line -1))
        ;; Check if parent is seq-tasks
        (when (and (altodo--task-p)
                   (= (altodo--get-current-indent) (- current-indent altodo-indent-size))
                   (altodo--has-seq-tasks-tag))
          ;; Check if previous sibling is incomplete
          (let ((has-incomplete-prev nil))
            (forward-line 1)
            ;; Find previous sibling
            (while (< (line-number-at-pos) current-line)
              (when (and (= (altodo--get-current-indent) current-indent)
                         (looking-at altodo-task-regex))
                ;; Found previous sibling
                (unless (altodo--task-is-completed (altodo--normalize-state (match-string 2)))
                  (setq has-incomplete-prev t)))
              (forward-line 1))
            has-incomplete-prev))))))

(defun altodo--line-seq-tasks-all-p ()
  "Check if current line is any seq-tasks task.
Returns t if condition is true, nil otherwise."
  (and (altodo--task-p)
       (altodo--has-seq-tasks-tag)))

;;; Helper: Check if string has face property

(defun altodo--string-has-face-property (str)
  "Return t if STR has any face property, nil otherwise.
Returns value."
  (let ((has-face nil)
        (len (length str)))
    (dotimes (i len has-face)
      (when (get-text-property i 'face str)
        (setq has-face t)))))

(defun altodo--apply-face-to-unfaced-text (start end face)
  "Apply FACE to text between START and END that lacks face property."
  (let ((pos start))
    (while (< pos end)
      (unless (get-text-property pos 'face)
        (put-text-property pos (1+ pos) 'face face))
      (setq pos (1+ pos)))))

;;; Sidebar Title Expansion

(defun altodo--evaluate-face-rules (rules count)
  "Evaluate RULES against COUNT, return first matching face or nil.
RULES: ((OP N FACE) ...) e.g. ((>= 10 \\='face1) (>= 1 \\='face2) (= 0 \\='face3))"
  (catch 'found
    (dolist (rule rules)
      (when (funcall (nth 0 rule) count (nth 1 rule))
        (throw 'found (nth 2 rule))))))

(defun altodo--get-entry-count (entry &optional source-buffer combined-predicate combine-mode)
  "Get match count for ENTRY from SOURCE-BUFFER.
If COMBINED-PREDICATE is provided, count only lines matching both ENTRY and COMBINED-PREDICATE.
COMBINE-MODE is 'and or 'or, used to determine whether to apply combined-predicate.
Returns integer (number of matching lines)."
  (let* ((type (plist-get entry :type))
         (pattern (plist-get entry :pattern))
         (count-pattern-simple (plist-get entry :count-pattern-simple))
         (count-pattern-lambda (plist-get entry :count-pattern-lambda))
         (exclude-others (plist-get entry :count-exclude-others))
         (match-pattern (cond
                         ((eq type 'search-simple) (or count-pattern-simple pattern))
                         ((eq type 'search-lambda) (or count-pattern-lambda pattern))
                         (t pattern)))
         ;; エントリの predicate を事前にコンパイル
         (entry-pred (when match-pattern
                       (if (functionp match-pattern)
                           match-pattern
                         (altodo--compile-simple-pattern match-pattern))))
         ;; 複合フィルタ下でのカウント用 predicate
         (effective-predicate 
          (cond
           ;; combined-predicate がない場合: entry-pred のみ
           ((not combined-predicate) entry-pred)
           ;; entry-pred がない場合: combined-predicate のみ
           ((not entry-pred) combined-predicate)
           ;; OR モード: combined-predicate を無視（全体のカウント）
           ((eq combine-mode 'or) entry-pred)
           ;; AND モードまたはデフォルト: entry AND combined
           (t
            (lambda ()
              (and (funcall entry-pred)
                   (funcall combined-predicate)))))))
    (if (null match-pattern)
        0
      (progn
        (setq exclude-others (if (null exclude-others) t exclude-others))
        (altodo--count-matching-lines effective-predicate exclude-others source-buffer)))))

(defun altodo--count-matching-lines (pattern &optional exclude-others source-buffer)
  "Count lines matching PATTERN in SOURCE-BUFFER.
PATTERN can be a DSL string or a lambda function.
If EXCLUDE-OTHERS is t (default), count only task lines.
If EXCLUDE-OTHERS is nil, count all matching lines.
SOURCE-BUFFER defaults to current buffer if not specified."
  (let ((count 0)
        (predicate (if (functionp pattern)
                       pattern
                     (altodo--compile-simple-pattern pattern)))
        (buf (or source-buffer (current-buffer))))
    (with-current-buffer buf
      (save-excursion
        (goto-char (point-min))
        (while (not (eobp))
          (when (and (funcall predicate)
                     (or (not exclude-others)
                         (altodo--task-p)))
            (setq count (1+ count)))
          (forward-line 1))))
    count))

(defun altodo--format-sidebar-title (pattern-spec &optional source-buffer combined-predicate combine-mode)
  "Generate :title from PATTERN-SPEC.
Replace %n with match count if :count-format is t.
Apply :face-count or :count-face-rules to the count if specified.
SOURCE-BUFFER is the main altodo buffer for counting matches.
COMBINED-PREDICATE is the combined predicate for dynamic count calculation.
COMBINE-MODE is 'and or 'or, used to determine whether to apply combined-predicate.
Returns formatted title string."
  (let ((title (plist-get pattern-spec :title))
        (count-format (plist-get pattern-spec :count-format))
        (face-count (plist-get pattern-spec :face-count))
        (count-face-rules (plist-get pattern-spec :count-face-rules)))
    (if (not (and count-format (string-match "%n" title)))
        title
      (let* ((count (altodo--get-entry-count pattern-spec source-buffer combined-predicate combine-mode))
             (count-str (number-to-string count))
             (resolved-face (or (when count-face-rules
                                  (altodo--evaluate-face-rules count-face-rules count))
                                face-count)))
        (when resolved-face
          (setq count-str (propertize count-str 'face resolved-face)))
        (replace-regexp-in-string "%n" count-str title t t)))))

;;; Strikethrough Matcher

(defun altodo-sidebar-make-config (&optional source-buffer)
  "Create sidebar config for altodo.
Reads patterns from .altodo-locals.el and customization variables.
Returns config plist ready for sidebar-display.
SOURCE-BUFFER is the main altodo buffer for counting matches."
  (let* ((src (or source-buffer (current-buffer)))
         (sidebar-buf (altodo-sidebar--get-or-create-buffer src))
         (patterns (or (altodo--get-filter-patterns)
                       altodo-default-filter-patterns)))
    (list :name (buffer-name sidebar-buf)
          :position (or (altodo--get-locals-value 'altodo-sidebar-position)
                        altodo-sidebar-position)
          :width (or (altodo--get-locals-value 'altodo-sidebar-size)
                     altodo-sidebar-size)
          :dedicated t
          :indent (or (altodo--get-locals-value 'altodo-sidebar-indent)
                      altodo-sidebar-indent)
          :source-buffer src
          :entries patterns)))

(defun sidebar--setup-sidebar-window (sidebar-win source-buffer)
  "Setup SIDEBAR-WIN with SOURCE-BUFFER context.
Disables tooltip-mode, sets source buffer, and positions cursor."
  (with-selected-window sidebar-win
    (setq-local altodo-sidebar--source-buffer source-buffer)
    (when (fboundp 'tooltip-mode)
      (setq-local tooltip-mode nil))
    (goto-char (point-min))
    (recenter 0)))

(defun altodo-sidebar-show ()
  "Display altodo sidebar.
Creates sidebar buffer with filter patterns from .altodo-locals.el.
Returns nil."
  (interactive)
  (altodo--register-sidebar-faces)
  (let ((source-buffer (current-buffer)))
    (let ((sidebar-win (sidebar-display (altodo-sidebar-make-config))))
      (when sidebar-win
        (sidebar--setup-sidebar-window sidebar-win source-buffer)
        ;; Initialize modeline with default mode
        (let ((sidebar-buf (altodo-sidebar--get-buffer source-buffer)))
          (when sidebar-buf
            (with-current-buffer sidebar-buf
              (altodo--update-sidebar-modeline))))))))

(defun altodo-sidebar--update-active-entry (entry)
  "Update active entry in sidebar buffer and refresh.
Returns value."
  (let ((sidebar-buffer (altodo--get-sidebar-buffer)))
    (when sidebar-buffer
      (with-current-buffer sidebar-buffer
        (setq-local altodo-sidebar--active-entries (list entry)))))
  (altodo-sidebar-refresh))

(defun altodo-sidebar--apply-filter (button)
  "Apply filter from BUTTON.
Extracts pattern from button and applies filter to altodo buffer."
  (let* ((entry (button-get button 'sidebar-entry))
         (pattern (plist-get entry :pattern))
         (type (plist-get entry :type))
         (command (plist-get entry :command))
         (source-buffer altodo-sidebar--source-buffer)
         (show-multiline (if (plist-member entry :multiline-comment)
                             (plist-get entry :multiline-comment)
                           t)))
    
    (if (not (and source-buffer (buffer-live-p source-buffer)))
        (message "Error: No valid source buffer")
      
      ;; Save window configuration to prevent scrolling
      (save-window-excursion
        (cond
         ;; Group header or separator - do nothing
         ((memq type '(group-header separator)))
         
         ;; Command - execute command in source buffer
         ((eq type 'command)
          (when command
            (with-current-buffer source-buffer
              (call-interactively command))))
         
         ;; Search lambda - apply custom predicate to source buffer
         ((and pattern (eq type 'search-lambda))
          (with-current-buffer source-buffer
            (altodo--filter-lines pattern show-multiline))
          (altodo-sidebar--update-active-entry entry))
         
         ;; Search simple - apply filter to source buffer
         ((and pattern (eq type 'search-simple))
          (setq altodo-sidebar--selected-filters nil
                altodo-sidebar--selection-mode 'single
                altodo-sidebar--current-combined-predicate nil)
          (altodo-sidebar--update-active-entry entry)
          (with-current-buffer source-buffer
            (let ((display-context (if (plist-member entry :display-context)
                                       (plist-get entry :display-context)
                                     'heading-only)))
              (altodo--filter-lines (altodo--compile-filter-predicate entry)
                                   show-multiline
                                   display-context)))
          (altodo-sidebar-refresh)
          (altodo--update-sidebar-modeline))
         
         ;; No pattern or unknown type
         (t
          (message "No action for type=%s pattern=%s" type pattern)))))))


(defun altodo-sidebar-hide ()
  "Hide altodo sidebar.
Returns nil."
  (interactive)
  (let ((buf (altodo--get-sidebar-buffer)))
    (when buf
      (delete-windows-on buf))))

(defun altodo-sidebar-toggle ()
  "Toggle altodo sidebar visibility.
Returns value."
  (interactive)
  (let ((buf (altodo--get-sidebar-buffer)))
    (if (and buf (get-buffer-window buf))
        (altodo-sidebar-hide)
      (altodo-sidebar-show))))

(defun altodo-sidebar-refresh ()
  "Refresh altodo sidebar.
Returns value."
  (interactive)
  (let ((buf (if altodo-sidebar--source-buffer
                 (current-buffer)
               (altodo--get-sidebar-buffer))))
    (when buf
      (with-current-buffer buf
        (let ((source-buf altodo-sidebar--source-buffer)
              (cursor-pos (point)))
          ;; 元のバッファのコンテキストで altodo-sidebar-make-config を実行
          (let ((config (with-current-buffer source-buf
                          (altodo-sidebar-make-config))))
            (sidebar--render buf config)
            ;; Restore cursor position
            (goto-char (min cursor-pos (point-max)))))))))

;;; Phase 5-5: Multiple Filter Selection Functions

(defun altodo-sidebar--toggle-filter-selection (entry)
  "Toggle ENTRY in multiple selection mode.
Add or remove ENTRY from altodo-sidebar--selected-filters.
If no filters are selected after removal, clear the filter."
  (altodo--with-sidebar-buffer
   (lambda ()
     ;; Switch to multiple selection mode
     (setq altodo-sidebar--active-entries nil
           altodo-sidebar--selection-mode 'multiple)
     
     (let ((cursor-pos (point)))
       (if (member entry altodo-sidebar--selected-filters)
           ;; Remove from selection
           (progn
             (setq altodo-sidebar--selected-filters
                   (delete entry altodo-sidebar--selected-filters)))
         ;; Add to selection
         (push entry altodo-sidebar--selected-filters))
       
       ;; If no filters selected, clear the filter and reset mode
       (if (null altodo-sidebar--selected-filters)
           (progn
             (setq altodo-sidebar--selection-mode nil
                   altodo-sidebar--current-combined-predicate nil)
             (let ((source-buf altodo-sidebar--source-buffer))
               (when (and source-buf (buffer-live-p source-buf))
                 (with-current-buffer source-buf
                   (altodo-filter-clear)))))
         ;; Apply combined filter
         (altodo-sidebar--apply-combined-filter))
       
       ;; Refresh sidebar to update faces
       (altodo-sidebar-refresh)
       (altodo--update-sidebar-modeline)
       
       ;; Restore cursor position
       (goto-char (min cursor-pos (point-max)))))))

(defun altodo-sidebar--apply-combined-filter ()
  "Apply combined filter from altodo-sidebar--selected-filters.
Combines predicates using altodo-sidebar--combine-mode."
  (let ((source-buf altodo-sidebar--source-buffer)
        (selected-filters altodo-sidebar--selected-filters)
        (combine-mode altodo-sidebar--combine-mode))
    (unless (and source-buf (buffer-live-p source-buf))
      (message "Error: No valid source buffer"))
    
    (when (and source-buf (buffer-live-p source-buf))
      (with-current-buffer source-buf
        ;; Compile predicates from selected filters using helper
        (let* ((predicates (mapcar #'altodo--compile-filter-predicate selected-filters))
               (combined-predicate (altodo--combine-predicates predicates combine-mode)))
          
          ;; predicate を変数に保存（sidebar--render で再利用）
          (altodo--with-sidebar-buffer
           (lambda ()
             (setq altodo-sidebar--current-combined-predicate combined-predicate)))
          
          ;; Apply combined filter
          (altodo--filter-lines combined-predicate t 'heading-only))))))

(defun altodo-sidebar-toggle-selection ()
  "Toggle multiple selection for filter at point.
Keyboard shortcut: s
Works anywhere on the line containing a filter."
  (interactive)
  (let ((button (or (button-at (point))
                    (button-at (line-beginning-position))
                    (button-at (1- (line-end-position))))))
    (unless button
      (message "No filter on this line"))
    
    (when button
      (let ((entry (button-get button 'sidebar-entry)))
        (unless entry
        (message "No filter entry at point")
        (nil))
      
        (altodo-sidebar--toggle-filter-selection entry)))))

(defun altodo-sidebar-set-and-mode ()
  "Set AND mode for multiple filter combination.
M-x command: altodo-sidebar-set-and-mode"
  (interactive)
  (altodo--with-sidebar-buffer
   (lambda ()
     (setq altodo-sidebar--combine-mode 'and)
     (when altodo-sidebar--selected-filters
       (altodo-sidebar--apply-combined-filter)
       (altodo-sidebar-refresh))
     (altodo--update-sidebar-modeline))))

(defun altodo-sidebar-set-or-mode ()
  "Set OR mode for multiple filter combination.
M-x command: altodo-sidebar-set-or-mode"
  (interactive)
  (altodo--with-sidebar-buffer
   (lambda ()
     (setq altodo-sidebar--combine-mode 'or)
     (when altodo-sidebar--selected-filters
       (altodo-sidebar--apply-combined-filter)
       (altodo-sidebar-refresh))
     (altodo--update-sidebar-modeline))))

(defun altodo-sidebar-toggle-combine-mode ()
  "Toggle AND/OR mode for multiple filter combination.
M-x command: altodo-sidebar-toggle-combine-mode"
  (interactive)
  (altodo--with-sidebar-buffer
   (lambda ()
     (unless altodo-sidebar--selected-filters
       (message "No filters selected")
       (nil))
     
     (setq altodo-sidebar--combine-mode
           (if (eq altodo-sidebar--combine-mode 'and) 'or 'and))
     (altodo-sidebar--apply-combined-filter)
     (altodo-sidebar-refresh))))

(defun altodo-sidebar--toggle-combine-mode ()
  "Toggle between AND and OR combine modes.
Returns value."
  (interactive)
  (setq altodo-sidebar--combine-mode
        (if (eq altodo-sidebar--combine-mode 'and) 'or 'and))
  (force-mode-line-update))

(defun altodo-sidebar--get-mode-line-string ()
  "Generate mode-line string for multiple selection display.
Returns nil if no filters selected, otherwise returns display string."
  (when altodo-sidebar--selected-filters
    (let ((mode-str (upcase (symbol-name altodo-sidebar--combine-mode))))
      (concat " Multiple: " (number-to-string (length altodo-sidebar--selected-filters))
              " filters, "
              (propertize mode-str
                          'mouse-face 'mode-line-highlight
                          'local-map (make-mode-line-mouse-map 'mouse-1
                                                               'altodo-sidebar--toggle-combine-mode)
                          'help-echo "mouse-1: toggle AND/OR")))))

(defun altodo-sidebar-mouse-toggle-selection (event)
  "Toggle multiple selection via mouse.
Ctrl+mouse-1 to toggle selection.
M-x command: altodo-sidebar-mouse-toggle-selection"
  (interactive "e")
  
  (let* ((pos (posn-point (event-start event)))
         (button (button-at pos)))
    (unless button
      (message "No filter at point")
      (nil))
    
    (let ((entry (button-get button 'sidebar-entry)))
      (unless entry
        (message "No filter entry at point")
        (nil))
      
      (altodo-sidebar--toggle-filter-selection entry))))


(provide 'altodo)

;;; altodo.el ends here
