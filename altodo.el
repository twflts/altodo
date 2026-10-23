;;; altodo.el --- Major mode for editing altodo files -*- lexical-binding: t; -*-

;; Copyright (C) 2026 altodo contributors

;; Author: twofaults
;; Maintainer: twofaults
;; Created: January 27, 2026
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (markdown-mode "2.0"))
;; Keywords: outlines, convenience, text
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

;; altodo-mode is a major mode for editing altodo files, which are
;; Markdown-based TODO files with enhanced task management features.
;;
;; Features:
;; - Syntax highlighting for task states, flags, tags, and dates
;; - Task state management with keyboard shortcuts
;; - Nested task support with proper indentation
;; - Integration with markdown-mode for Markdown compatibility
;; - Sidebar with filters and match counts.  A filter is a DSL pattern
;;   (for example "and:open,priority") or, in a trusted settings file, a
;;   lambda.  Several filters can be combined with AND or OR
;; - Mini calendar and per-day agenda in the sidebar, and a list of the
;;   headings of the buffer that jumps to a heading
;; - Per-directory settings in `.altodo-locals.el'.  Code in this file is
;;   not run unless `altodo-locals-code-policy' allows it
;; - Moving done tasks to a "_done" file, by hand or with a timer
;; - Commands for investigating a problem are in the separate file
;;   `altodo-debug.el'
;;
;; Usage:
;; Add the following to your init file:
;;   (require 'altodo)
;;   (add-to-list 'auto-mode-alist '("\\.altodo\\'" . altodo-mode))

;;; Code:

(require 'markdown-mode)
(require 'cl-lib)
(require 'calendar)
(require 'altodo-calendar)

;; Variables defined later in this file.  A `let' of a variable that is not
;; yet declared special would bind it lexically.
(defvar altodo-show-auto-move-in-mode-line)
(defvar altodo-sidebar--combine-mode)
(defvar altodo-sidebar--buffer-alist)
(defvar altodo--count-cache)
(defvar read-eval)

;;; Constants and Variables

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
Note: \\='dep\\=' is handled separately by altodo--dep-tag-matcher.")

;; Dynamic task regex based on defined state constants
(defconst altodo-task-state-chars
  (concat altodo-state-done altodo-state-progress altodo-state-waiting altodo-state-cancelled)
  "All valid task state characters.")

(defconst altodo-task-regex
  (format "^\\([ ]*\\)\\[\\([%s ]?\\)\\]\\(.*\\)$"
          (regexp-quote altodo-task-state-chars))
  "Regular expression for matching task lines.
Generated from the state constants.")

(defconst altodo-comment-regex
  (format "^\\([ \t]*\\)%s \\(.*\\)$" (regexp-quote altodo-comment-marker))
  "Regular expression for matching comment lines.
Generated from the comment marker.")

;; Dynamic special tag regex
(defconst altodo-special-tag-regex
  (format "\\(?:^\\|[ ]\\)\\(#\\(?:%s\\)\\)\\(?::\\([^[:space:]]+\\)\\)?"
          (mapconcat 'identity altodo-special-tag-names "\\|"))
  "Regular expression for matching special tags.
Generated from the special tag names.")

;; DSL pattern constants
(defconst altodo--dsl-simple-patterns
  '("done" "progress" "waiting" "open" "cancelled" "priority" "star"
    "has-multiline-comment" "task" "comment" "multiline-comment" "heading"
    "empty-line" "any-line")
  "List of valid simple DSL patterns.")

(defconst altodo--dsl-logic-operators-regex
  "\\(and\\|or\\|not\\):"
  "Regular expression for matching DSL logic operators.")

(defconst altodo--dsl-arg-types
  '("tag" "person" "text" "regexp" "level" "heading" "multiline-comment-contains"
    "due-date" "start-date" "tag-value" "parent-task-regexp" "root-task-regexp"
    "state-any" "has-any-flag" "has-any-tag" "has-any-person" "has-all-tags")
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
When nil, multiline comments are displayed in a single face without Markdown
formatting.

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
The value is one of the following symbols:
  \\='uuid         - Full UUIDv7 (36 chars)
  \\='base62       - Base62 encoded UUID (21 chars): CRl6Njdf8iwWyyc32HW2H
  \\='short        - Short ID, sortable (15 chars): eBnPYIBatZhU1lG
  \\='short-random - Short ID, random first (up to 16 chars): atZhU1lGeBnPYIB
  \\='tiny         - Tiny ID, sortable (10 chars): 2C47gz6WJT
  \\='tiny-random  - Tiny ID, random first (up to 10 chars): 6WJT2C47gz"
  :type '(choice (const :tag "Full UUIDv7 (36 chars)" uuid)
                 (const :tag "Base62 encoded (21 chars)" base62)
                 (const :tag "Short ID, sortable (15 chars)" short)
                 (const :tag "Short ID, random first (15 chars)" short-random)
                 (const :tag "Tiny ID, sortable (10 chars)" tiny)
                 (const :tag "Tiny ID, random first (10 chars)" tiny-random))
  :group 'altodo)

;;; Modeline Variables

(defvar-local altodo-sidebar-modeline-string ""
  "Current filter state for the mode line of a sidebar buffer.")

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

(defcustom altodo-date-format nil
  "Date format string for parsing dates.
If nil, uses YYYY-MM-DD format (ISO 8601).
If non-nil, should be a `format-time-string' compatible format.

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

(defcustom altodo-week-start-day 0
  "Day of week that starts the week (0=Sunday, 1=Monday, ..., 6=Saturday).
Used for \\='this-week\\=' filter condition in due-date and start-date filters."
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

(defface altodo-flag-priority-face
  '((t :inherit error :weight bold))
  "Face for priority flags."
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

(defun altodo--integer-to-base62 (number)
  "Convert the non-negative integer NUMBER to a Base62 string.
Return \"0\" for 0."
  (let ((result ""))
    (while (> number 0)
      (setq result (concat (substring altodo--base62-chars
                                      (% number 62) (1+ (% number 62)))
                           result))
      (setq number (/ number 62)))
    (if (string= result "") "0" result)))

(defun altodo--uuid-to-base62 (uuid)
  "Convert UUID string to Base62 encoded string.
UUID can be in format with or without hyphens."
  (altodo--integer-to-base62
   (string-to-number (replace-regexp-in-string "-" "" uuid) 16)))

(defun altodo--base62-to-uuid (base62)
  "Convert the Base62 encoded string BASE62 back to UUID format."
  (let ((num 0))
    (dotimes (i (length base62))
      (let* ((char (aref base62 i))
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
  "Generate a UUIDv7 string as defined by RFC 9562.
The 128 bits are:
  - 48 bits: Unix timestamp in milliseconds
  - 4 bits: version (0111 = 7)
  - 12 bits: random data (rand_a)
  - 2 bits: variant (10)
  - 62 bits: random data (rand_b)

Returns a string in the format: xxxxxxxx-xxxx-7xxx-xxxx-xxxxxxxxxxxx"
  (let* ((unix-ms (floor (* 1000 (float-time))))
         (version-and-rand-a (logior (ash 7 12) (random (ash 1 12))))
         (variant-and-rand-b (logior (ash 2 62) (random (ash 1 62)))))
    (format "%08x-%04x-%04x-%04x-%012x"
            (ash unix-ms -16)
            (logand unix-ms #xFFFF)
            version-and-rand-a
            (ash variant-and-rand-b -48)
            (logand variant-and-rand-b #xFFFFFFFFFFFF))))

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
         (combined (+ (ash ts-42 48) rand-48)))
    (altodo--integer-to-base62 combined)))

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
         (combined (+ (ash rand-48 42) ts-42)))
    (altodo--integer-to-base62 combined)))

(defun altodo--generate-tiny-id-sortable ()
  "Generate a sortable tiny ID (10 characters).
Format: timestamp (32 bits) + random (24 bits) in Base62.
Timestamp comes first for chronological sorting."
  (let* ((unix-sec (truncate (time-to-seconds (current-time))))
         (ts-32 (logand unix-sec #xFFFFFFFF))
         (rand-24 (random (expt 2 24)))
         (combined (+ (ash ts-32 24) rand-24)))
    (altodo--integer-to-base62 combined)))

(defun altodo--generate-tiny-id-random ()
  "Generate a tiny ID with random first (10 characters).
Format: random (24 bits) + timestamp (32 bits) in Base62.
Random part comes first for better visual distinction."
  (let* ((unix-sec (truncate (time-to-seconds (current-time))))
         (ts-32 (logand unix-sec #xFFFFFFFF))
         (rand-24 (random (expt 2 24)))
         (combined (+ (ash rand-24 32) ts-32)))
    (altodo--integer-to-base62 combined)))

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
  "Insert #id: tag with generated ID at the end of current line."
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
    (when (re-search-forward (format "#id:%s\\(?:[ \t]\\|$\\)"
                                     (regexp-quote id))
                             nil t)
      (beginning-of-line)
      (when (looking-at altodo-task-regex)
        (let ((state (altodo--normalize-state (match-string 2))))
          state)))))

(defun altodo--task-is-completed (state)
  "Check if task STATE is completed (x or ~).
Returns t if completed, nil otherwise."
  (or (string= state altodo-state-done)
      (string= state altodo-state-cancelled)))

(defun altodo--get-task-id (pos)
  "Get #id: value of task at POS.  Return nil if no #id: tag."
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
  "Check whether ID is in a circular dependency.
VISITED is a list of IDs already visited in the dependency chain.
Call it inside (catch \\='circular ...): when a circle is found it throws
`circular' with the value `circular'.  Otherwise it returns nil."
  ;; Strip text properties for comparison
  (let ((id-clean (substring-no-properties id)))
    (when (cl-some (lambda (v) (string= id-clean (substring-no-properties v))) visited)
      (throw 'circular 'circular))
    (let ((new-visited (cons id-clean visited)))
      (save-excursion
        (goto-char (point-min))
        (when (re-search-forward (format "#id:%s\\(?:[ \t]\\|$\\)"
                                         (regexp-quote id-clean))
                                 nil t)
          (let ((deps (altodo--get-task-deps (point))))
            (dolist (dep deps)
              (altodo--check-circular-dependency dep new-visited))))))))

(defun altodo--check-all-deps-completed (deps)
  "Check if all dependencies in DEPS list are completed.
Returns:
  \\='circular - if circular dependency detected
  \\='blocked  - if any dependency is not completed
  \\='ready    - if all dependencies are completed or not found"
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
  "Normalize task state string STATE-STR, treating space as empty.
Return normalized state string."
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
;;; Date-based face functions
;;; ============================================================================

(defun altodo--format-to-regex (format-str)
  "Convert the `format-time-string' format FORMAT-STR to regex.
Returns (regex-parse regex-match year-idx month-idx day-idx).
regex-parse: with capture groups for parsing
regex-match: without capture groups for font-lock matching"
  (let ((pos 0)
        (group-count 0)
        (regex-parse "")
        (regex-match "")
        (year-idx nil)
        (month-idx nil)
        (day-idx nil))
    ;; Literal text between specifiers is quoted, and group numbers follow
    ;; the order in which the specifiers appear in FORMAT-STR.
    (while (string-match "%[Ymd]" format-str pos)
      (let* ((spec (aref format-str (1+ (match-beginning 0))))
             (literal (regexp-quote
                       (substring format-str pos (match-beginning 0))))
             (digits (if (eq spec ?Y) "[0-9]\\{4\\}" "[0-9]\\{2\\}")))
        (setq group-count (1+ group-count))
        (pcase spec
          (?Y (setq year-idx group-count))
          (?m (setq month-idx group-count))
          (?d (setq day-idx group-count)))
        (setq regex-parse (concat regex-parse literal "\\(" digits "\\)")
              regex-match (concat regex-match literal "\\(?:" digits "\\)")
              pos (match-end 0))))
    (let ((tail (regexp-quote (substring format-str pos))))
      (list (concat regex-parse tail) (concat regex-match tail)
            year-idx month-idx day-idx))))

(defun altodo--normalize-date-string (date-str)
  "Return DATE-STR in YYYY-MM-DD form, or nil if it cannot be parsed.
DATE-STR is written in the format of `altodo-date-format'."
  (let ((regex-info (altodo--date-regex-info)))
    (when (string-match (nth 0 regex-info) date-str)
      (format "%s-%s-%s"
              (match-string (nth 2 regex-info) date-str)
              (match-string (nth 3 regex-info) date-str)
              (match-string (nth 4 regex-info) date-str)))))

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

(defun altodo--due-date-regex (&optional date-regex)
  "Return the regexp of the due date \"-> DATE\", with the date in group 1.
The arrow needs a space or the beginning of the line before it, and the date
a space or the end of the line after it.  DATE-REGEX is the regexp of the
date without groups; by default it is the date format in use."
  (concat "\\(?:^\\| \\)-> \\(" (or date-regex (altodo--date-regex-match))
          "\\)\\(?: \\|$\\)"))

(defun altodo--start-date-regex (&optional date-regex)
  "Return the regexp of the start date \"DATE ->\", with the date in group 1.
The date needs a space or the beginning of the line before it, and the arrow
a space or the end of the line after it.  DATE-REGEX is as for
`altodo--due-date-regex\'."
  (concat "\\(?:^\\| \\)\\(" (or date-regex (altodo--date-regex-match))
          "\\) ->\\(?: \\|$\\)"))

(defun altodo--date-line-p ()
  "Return non-nil if dates are recognized in the current line.
Dates are an element of the task lines, the \"///\" comment lines and the
headings.  They are not an element of a multi-line comment, which is text of
the task above it, nor of a fenced code block."
  (save-excursion
    (beginning-of-line)
    (and (not (altodo--in-fenced-code-block-p))
         (or (looking-at altodo-task-regex)
             (looking-at altodo-comment-regex)
             (looking-at "^#+[ \t]+")
             (altodo--line-heading-p))
         t)))

(defun altodo--search-date (regex limit)
  "Search REGEX forward up to LIMIT on the lines where dates are recognized.
A match on another line is skipped.  Return non-nil if a match is found, with
the match data set."
  (let ((found nil))
    (while (and (not found) (re-search-forward regex limit t))
      (when (save-match-data
              (save-excursion
                (goto-char (match-beginning 0))
                (altodo--date-line-p)))
        (setq found t)))
    found))

(defun altodo--valid-date-p (year month day)
  "Return non-nil if YEAR, MONTH and DAY are a date that exists.
YEAR is 1 to 9999."
  (and (<= 1 year 9999)
       (<= 1 month 12)
       (<= 1 day (if (= month 2)
                     (if (and (zerop (% year 4))
                              (or (/= 0 (% year 100)) (zerop (% year 400))))
                         29
                       28)
                   (aref [31 28 31 30 31 30 31 31 30 31 30 31] (1- month))))))

(defun altodo--parse-date (date-str)
  "Parse date string DATE-STR and return time value.
Return time value (for use with encode-time/decode-time), or nil if parsing
fails or the date does not exist (such as 2026-02-30)."
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
            (altodo--encode-date year month day))))
    (error nil)))

(defun altodo--encode-date (year month day)
  "Return the time value of 00:00 on the date YEAR, MONTH and DAY.
Return nil if the date does not exist."
  (when (altodo--valid-date-p year month day)
    ;; DST -1: let the system decide, so that midnight stays 00:00 in summer
    ;; time (nil would mean standard time, 01:00 in summer).
    (encode-time (list 0 0 0 day month year nil -1 nil))))

(defun altodo--parse-normalized-date (date-str)
  "Parse DATE-STR written as YYYY-MM-DD, whatever `altodo-date-format' is.
That is the form `altodo--line-due-date-value' returns.  Return a time value,
or nil if DATE-STR is not a date that exists."
  (when (string-match "\\`\\([0-9]+\\)-\\([0-9]+\\)-\\([0-9]+\\)\\'" date-str)
    (altodo--encode-date (string-to-number (match-string 1 date-str))
                         (string-to-number (match-string 2 date-str))
                         (string-to-number (match-string 3 date-str)))))

(defun altodo--today-start ()
  "Return today\\='s start time (00:00:00) in local timezone.
Returns time value."
  (let ((today-decoded (decode-time (current-time))))
    (encode-time (list 0 0 0
                       (nth 3 today-decoded)
                       (nth 4 today-decoded)
                       (nth 5 today-decoded)
                       nil -1 nil))))

(defun altodo--days-diff (date-time)
  "Calculate days difference between DATE-TIME and today.
Positive means future, negative means past.
Counts calendar days in the local time zone, so a day of 23 or 25 hours
at the switch of summer time still counts as one day.
Returns number (float)."
  (float (- (time-to-days date-time)
            (time-to-days (altodo--today-start)))))

(defun altodo--determine-start-date-face (date-str)
  "Determine face for start date DATE-STR.
Returns yellow if started, blue if not yet started.
Returns face symbol."
  (let ((date-time (altodo--parse-date date-str)))
    (if (and date-time (<= (altodo--days-diff date-time) 0))
        'altodo-date-start-active-face
      'altodo-date-face)))

(defun altodo--determine-due-date-face (date-str)
  "Determine face for due date DATE-STR.
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
  (altodo--search-date (altodo--start-date-regex) limit))

(defun altodo--due-date-matcher (limit)
  "Match due dates (-> DATE) up to LIMIT.
Requires exactly one space before and after ->, or end-of-line after DATE."
  (altodo--search-date (altodo--due-date-regex) limit))

(defun altodo--arrow-matcher (limit)
  "Match arrows (->) up to LIMIT.
Requires exactly one space before ->, and space or end-of-line after ->.
Matches \\='DATE -> DATE\\=', \\='DATE -> \\=', or \\=' -> DATE\\=' pattern.
Does NOT match bare \\='->\\=' without dates."
  (let ((date-regex (altodo--date-regex-match)))
    (altodo--search-date
     (concat "\\(" date-regex " " (regexp-quote "->") "\\|" (regexp-quote "->") " " date-regex "\\)")
     limit)))


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
    (let ((max-iterations 1000)
          (iterations 0))
      (while (and (< (point) limit) (not (eobp)) (< iterations max-iterations))
        (setq iterations (1+ iterations))
        (when (re-search-forward "#dep:\\([^[:space:]]+\\)" limit t)
          (let* ((value-start (match-beginning 1))
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
            (if (string-match (altodo--due-date-regex) line-text)
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
            ;; The space before the date may be the one after the bracket.
            (goto-char (line-beginning-position))
            ;; Search for "DATE -> " or "DATE ->" pattern anywhere in the line
            (if (re-search-forward (altodo--start-date-regex) line-end t)
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

(defun altodo--restore-code-block-faces (beg end)
  "Restore markdown faces in fenced code blocks between BEG and END.
Overwrites altodo faces with markdown-pre-face and markdown-code-face.
Only targets fenced code blocks (``` or ~~~), not indented code blocks."
  (save-excursion
    (goto-char beg)
    (while (< (point) end)
      (when (or (get-text-property (point) 'markdown-gfm-code)
                (get-text-property (point) 'markdown-fenced-code))
        (put-text-property (line-beginning-position) (line-end-position)
                           'face '(markdown-pre-face markdown-code-face)))
      (forward-line 1))))

;; Font-lock keywords for altodo-mode
(defun altodo-font-lock-keywords ()
  "Generate font lock keywords for altodo-mode.
Processing order: brackets -> base text -> tags/dates -> emphasis/flags ->
priority.
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
                             (altodo--is-seq-tasks-child-blocked-p))))
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
                           (altodo--is-seq-tasks-child-blocked-p))))
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
    (,(format "^[ ]*\\[.\\][ ]*\\(?:%s \\)?\\(%s\\{3,\\}\\) \\(.*\\)" (regexp-quote altodo-flag-star) (regexp-quote altodo-flag-priority)) .
     ((1 'altodo-flag-priority3-face t)
      (2 'altodo-flag-priority3-text-face prepend)))

    (,(format "^[ ]*\\[.\\][ ]*\\(?:%s \\)?\\(%s\\{2\\}\\) \\(.*\\)" (regexp-quote altodo-flag-star) (regexp-quote altodo-flag-priority)) .
     ((1 'altodo-flag-priority2-face t)
      (2 'altodo-flag-priority2-text-face prepend)))

    (,(format "^[ ]*\\[.\\][ ]*\\(?:%s \\)?\\(%s\\) \\(.*\\)" (regexp-quote altodo-flag-star) (regexp-quote altodo-flag-priority)) .
     ((1 'altodo-flag-priority1-face t)
      (2 'altodo-flag-priority1-text-face prepend)))

    ;; 7. スターフラグ
    (,(format "^[ ]*\\[.\\][ ]*\\(?:%s+ \\)?\\(%s\\) \\(.*\\)" (regexp-quote altodo-flag-priority) (regexp-quote altodo-flag-star)) .
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

(defun altodo--task-or-comment-p ()
  "Return non-nil if the current line is a task or a `///' comment."
  (or (altodo--task-p) (altodo--comment-p)))

(defun altodo--task-comment-or-multiline-p ()
  "Return non-nil if the current line is a task, a comment or a multi-line comment."
  (or (altodo--task-p) (altodo--comment-p) (altodo--multiline-comment-p)))

(defun altodo--on-line (predicate command)
  "Return a command for COMMAND on the lines where PREDICATE is true.
On any other line, the command of the parent mode for the same key is used,
so a key keeps its Markdown meaning outside the tasks."
  (lambda ()
    (interactive)
    (if (funcall predicate)
        (call-interactively command)
      (altodo--call-parent-command (this-command-keys-vector)))))

(defvar-keymap altodo-mode-map
  :doc "Keymap for altodo-mode."
  :parent markdown-mode-map
  "TAB" #'altodo-indent-line
  "RET" #'altodo-enter
  "<backtab>" #'outline-cycle
  "C-c C-x" (altodo--on-line #'altodo--task-p #'altodo-toggle-task-state)
  "C-c C-t o" (altodo--on-line #'altodo--task-p #'altodo-set-task-open)
  "C-c C-t x" (altodo--on-line #'altodo--task-p #'altodo-set-task-done)
  "C-c C-t @" (altodo--on-line #'altodo--task-p #'altodo-set-task-progress)
  "C-c C-t w" (altodo--on-line #'altodo--task-p #'altodo-set-task-waiting)
  "C-c C-t ~" (altodo--on-line #'altodo--task-p #'altodo-set-task-cancelled)
  "C-c C-t d" (altodo--on-line #'altodo--task-p #'altodo-move-done-tasks-at-point)
  "C-c C-t D" (altodo--on-line #'altodo--task-p #'altodo-move-done-task-alone)
  "C-c C-a" (altodo--on-line #'altodo--task-or-comment-p #'altodo-add-task)
  "M-RET" (altodo--on-line #'altodo--task-or-comment-p #'altodo-add-subtask)
  "C-c C-m" (altodo--on-line #'altodo--task-or-comment-p #'altodo-start-multiline-comment)
  "C-c C-s" (altodo--on-line #'altodo--task-or-comment-p #'altodo-toggle-star-flag)
  "C-c C-f 1" (altodo--on-line #'altodo--task-or-comment-p #'altodo-set-priority-1)
  "C-c C-f 2" (altodo--on-line #'altodo--task-or-comment-p #'altodo-set-priority-2)
  "C-c C-f 3" (altodo--on-line #'altodo--task-or-comment-p #'altodo-set-priority-3)
  "C-c C-e d" (altodo--on-line #'altodo--task-or-comment-p #'altodo-select-due-calendar)
  "C-c C-e s" (altodo--on-line #'altodo--task-or-comment-p #'altodo-select-start-calendar)
  "C-c C-i" (altodo--on-line #'altodo--task-or-comment-p #'altodo-insert-id)
  "M-<right>" (altodo--on-line #'altodo--task-comment-or-multiline-p #'altodo-indent-increase)
  "M-<left>" (altodo--on-line #'altodo--task-comment-or-multiline-p #'altodo-indent-decrease)
  "C-c C-v f c" #'altodo-filter-clear
  "C-c C-v s t" #'altodo-sidebar-toggle
  "C-c C-v s r" #'altodo-sidebar-refresh
  "C-c C-j" (altodo--on-line #'altodo--task-or-comment-p #'altodo-goto-dependency))

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
  ;; Add altodo font-lock keywords after markdown keywords
  ;; This allows markdown inline elements (bold, italic, etc.) to be applied first,
  ;; then altodo faces are added as base colors
  (font-lock-add-keywords nil (altodo-font-lock-keywords) 'append)
  (setq-local indent-line-function #'altodo-indent-line)
  ;; The nesting is written with spaces (see the format specification).
  (setq-local indent-tabs-mode nil)

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
    (font-lock-ensure))

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

  ;; Clean up sidebar buffer when source buffer is killed
  (add-hook 'kill-buffer-hook #'altodo-sidebar--on-source-buffer-kill nil t)

  ;; Update the sidebar when the file is saved
  (add-hook 'after-save-hook #'altodo--sidebar-refresh-after-save nil t))

;;; Interactive Commands

;;; Helper function for keymap fallback

(defun altodo--sidebar-refresh-after-save ()
  "Redraw the sidebar of the current buffer after a save, if it is shown.
A hidden sidebar is drawn when it is shown again, so drawing it now would
only make each save slower."
  (let ((sidebar (altodo--get-sidebar-buffer)))
    (when (and sidebar (get-buffer-window sidebar t))
      (altodo-sidebar-refresh))))

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
  "Toggle task state between open and done."
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

(defun altodo--change-task-state (state done-tag)
  "Set the task at point to STATE.
DONE-TAG is `add' to add a #done tag, `remove' to remove it, or nil."
  (save-excursion
    (beginning-of-line)
    (if (looking-at altodo-task-regex)
        (progn
          (altodo--set-task-state state)
          (pcase done-tag
            ('add (altodo--add-done-tag))
            ('remove (altodo--remove-done-tag))))
      (message "Not on a task line"))))

(defun altodo-set-task-open ()
  "Set current task to open state and remove its #done tag."
  (interactive)
  (altodo--change-task-state altodo-state-open 'remove))

(defun altodo-set-task-done ()
  "Set current task to done state and add a #done tag."
  (interactive)
  (altodo--change-task-state altodo-state-done 'add))

(defun altodo-set-task-progress ()
  "Set current task to progress state."
  (interactive)
  (altodo--change-task-state altodo-state-progress nil))

(defun altodo-set-task-waiting ()
  "Set current task to waiting state."
  (interactive)
  (altodo--change-task-state altodo-state-waiting nil))

(defun altodo-set-task-cancelled ()
  "Set current task to cancelled state and add a #done tag."
  (interactive)
  (altodo--change-task-state altodo-state-cancelled 'add))

(defun altodo-indent-increase ()
  "Increase indentation of current line or region."
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
  "Decrease indentation of current line or region."
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

(defun altodo--in-fenced-code-block-p ()
  "Return non-nil if point is in a fenced code block (``` or ~~~).
Indented code blocks of Markdown are not counted: altodo uses indentation
for nesting and multi-line comments, so an indented line is never a code
block, even right after a blank line."
  (save-match-data
    (and (markdown-get-enclosing-fenced-block-construct) t)))

(defun altodo--leading-spaces ()
  "Return the number of leading spaces of the current line."
  (save-excursion
    (beginning-of-line)
    (skip-chars-forward " ")
    (- (point) (line-beginning-position))))

(defun altodo--task-or-comment-line-p ()
  "Return non-nil if the current line is a task or a `///' comment line.
A line inside a fenced code block is not."
  (save-excursion
    (beginning-of-line)
    (and (or (looking-at altodo-task-regex)
             (looking-at altodo-comment-regex))
         (not (altodo--in-fenced-code-block-p)))))

(defun altodo--multiline-comment-indent-ok-p (indent)
  "Return non-nil if the lines above make an INDENT-space line a comment.
Going up through the lines with the same indentation, the first task or
`///' line found must be indented by `altodo-indent-size' spaces less
than INDENT.  A completely empty line, or a line with another indentation,
ends the search."
  (save-excursion
    (let ((result nil)
          (done nil))
      (while (not done)
        (if (bobp)
            (setq done t)
          (forward-line -1)
          (cond
           ((altodo--task-or-comment-line-p)
            (setq result (= indent (+ (altodo--leading-spaces)
                                      altodo-indent-size))
                  done t))
           ((looking-at "^$") (setq done t))
           ((= (altodo--leading-spaces) indent))
           (t (setq done t)))))
      result)))

(defun altodo--multiline-comment-matcher-new (limit)
  "Match multiline comments up to LIMIT.
Each match is one line, without its newline."
  (catch 'found
    (while (and (< (point) limit) (not (eobp)))
      (if (and (looking-at " +")
               (altodo--multiline-comment-p))
          (let ((line-start (point))
                (line-end (line-end-position)))
            (set-match-data (list line-start line-end))
            (goto-char (1+ line-end))
            (throw 'found t))
        (forward-line 1)))
    nil))

;; === Helper functions ===

(defun altodo--multiline-comment-p ()
  "Check if the current line is a multi-line comment.
A multi-line comment line is indented by exactly `altodo-indent-size'
spaces more than the task or `///' line above it, or has the same
indentation as the multi-line comment line above it.  A line that
contains only that many spaces is included.  Every line other than a task
line qualifies, including Markdown lists, links and fenced code blocks.
A completely empty line, or a line with another indentation, ends the
comment."
  (save-excursion
    (beginning-of-line)
    (let ((indent (altodo--leading-spaces)))
      (and (> indent 0)
           (not (altodo--task-p))
           (not (altodo--comment-p))
           (altodo--multiline-comment-indent-ok-p indent)))))

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

(defconst altodo--done-tag-value-regex
  "\\(?:\"[^\"]*\"\\|[^[:space:]]+\\)"
  "Regexp for the value of the #done tag: a word or a double-quoted string.")

(defun altodo--done-tag-timestamp ()
  "Return the timestamp for a new #done tag.
Without `altodo-done-tag-datetime-format', it is ISO 8601 with the time zone
offset.  With a format, it is the result of the format alone.  A result that
has a space is double-quoted, as the tag syntax requires."
  (let* ((now (current-time))
         (zone (if altodo-use-local-timezone nil t))
         (timestamp
          (if altodo-done-tag-datetime-format
              (format-time-string altodo-done-tag-datetime-format now zone)
            (format-time-string "%Y-%m-%dT%H:%M:%S%:z" now zone))))
    (if (string-match-p "[[:space:]]" timestamp)
        (concat "\"" (replace-regexp-in-string "\"" "" timestamp) "\"")
      timestamp)))

(defun altodo--add-done-tag ()
  "Add a #done tag with the current time at the end of the current line.
Nothing is added when the line already ends with a #done tag."
  (save-excursion
    (end-of-line)
    (unless (looking-back (concat "#done:" altodo--done-tag-value-regex)
                          (line-beginning-position))
      (insert " #done:" (altodo--done-tag-timestamp)))))

(defun altodo--remove-done-tag ()
  "Remove #done tag from current line."
  (save-excursion
    (beginning-of-line)
    (when (re-search-forward (concat " #done:\\(?:" altodo--done-tag-value-regex "\\)?")
                             (line-end-position) t)
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
    (and (not (altodo--in-fenced-code-block-p))
         (looking-at altodo-task-regex))))

(defun altodo--comment-p ()
  "Check if current line is a single-line comment.
Returns nil if in a code block.
Returns t if current line is a single-line comment, nil otherwise."
  (save-excursion
    (beginning-of-line)
    (and (not (altodo--in-fenced-code-block-p))
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
  "Get indentation level of line at position POS."
  (save-excursion
    (goto-char pos)
    (altodo--get-current-indent)))

(defun altodo--normalize-indent (indent)
  "Normalize INDENT to next multiple of `altodo-indent-size`."
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
  "Set current line indentation to INDENT spaces."
  (save-excursion
    (beginning-of-line)
    (delete-horizontal-space)
    (indent-to indent)))

(defvar-local altodo--last-indent-action nil
  "Track last indent action: \\='adjust, \\='increase, \\='same, \\='decrease.")

(defvar-local altodo--last-indent-line nil
  "Track line number of last indent action.")

(defvar-local altodo--original-indent nil
  "Track original indent level before first action.")

;;; Filter Variables

(defvar-local altodo--filter-overlays nil
  "List of overlays used for filtering.")

(defvar-local altodo--filter-mode nil
  "Current filter mode symbol (e.g., \\='done, \\='progress, \\='tag).")


;;; Filter Helper Functions

(defun altodo--filter-find-overlay (line-start line-end)
  "Find existing filter overlay for the line from LINE-START to LINE-END.
Returns the overlay if found, nil otherwise."
  ;; `overlays-in' uses the overlay tree, so this does not scan every
  ;; overlay of the buffer.
  (seq-find (lambda (ov)
              (and (eq (overlay-get ov 'category) 'altodo-filter)
                   (= (overlay-start ov) line-start)
                   (= (overlay-end ov) line-end)))
            (overlays-in line-start line-end)))

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

(defvar altodo--filter-defer-prune nil
  "Non-nil while the caller prunes `altodo--filter-overlays' afterward.")

(defun altodo--filter-remove-overlay (line-start line-end)
  "Remove overlay for line from LINE-START to LINE-END.
Returns t if overlay was removed, nil otherwise.
While `altodo--filter-defer-prune' is non-nil, the deleted overlay stays in
`altodo--filter-overlays'; the caller removes the deleted overlays at once
with `altodo--filter-prune-overlays' (a `delq' per line would scan the list
for every line)."
  (let ((ov (altodo--filter-find-overlay line-start line-end)))
    (when ov
      (delete-overlay ov)
      (unless altodo--filter-defer-prune
        (setq altodo--filter-overlays (delq ov altodo--filter-overlays)))
      t)))

(defun altodo--filter-prune-overlays ()
  "Remove the deleted overlays from `altodo--filter-overlays'."
  (setq altodo--filter-overlays
        (seq-filter #'overlay-buffer altodo--filter-overlays)))

(defun altodo--filter-show-multiline-comments (range-start range-end)
  "Show multiline comments in range from RANGE-START to RANGE-END.
Removes overlays for all lines in the range to make them visible."
  (save-excursion
    (goto-char range-start)
    (while (< (point) range-end)
      (altodo--filter-remove-overlay (line-beginning-position)
                                     (1+ (line-end-position)))
      (forward-line 1))))


;;; Filter Heading Cache

(defvar-local altodo--heading-cache nil
  "Cache of heading ranges: ((heading-text . (start . end)) ...).
It is valid while `altodo--heading-cache-tick' is the modification tick of
the buffer.")

(defvar-local altodo--heading-cache-tick nil
  "Value of `buffer-chars-modified-tick' when the heading cache was made.")

(defvar-local altodo--heading-range-table nil
  "Hash table from a regexp to the ranges of the headings that match it.")

(defun altodo--heading-ranges-matching (regexp)
  "Return the ranges (START . END) of the headings that match REGEXP.
REGEXP is searched in the text of each heading, so every heading with a
match counts, and the range of a heading includes its child headings.  The
ranges come from the heading cache, which is made again after the buffer
changes."
  (unless (eql altodo--heading-cache-tick (buffer-chars-modified-tick))
    (altodo--compute-all-heading-ranges))
  (let ((ranges (gethash regexp altodo--heading-range-table 'miss)))
    (when (eq ranges 'miss)
      (setq ranges (cl-loop for entry in altodo--heading-cache
                            when (string-match-p regexp (car entry))
                            collect (cdr entry)))
      (puthash regexp ranges altodo--heading-range-table))
    ranges))


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
  (ignore event)
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
Returns string like \\='[AND] (Single)\\=' or \\='[OR] (Multiple)\\='."
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
  "Update the mode line of the sidebar of the current buffer.
The state shown is that of the sidebar buffer, whichever buffer is current,
so two sidebars do not show each other's state."
  (when altodo-sidebar-modeline-enabled
    (altodo--with-sidebar-buffer
     (lambda ()
       (setq altodo-sidebar-modeline-string
             (or (altodo--get-sidebar-modeline-string) ""))))
    (force-mode-line-update t)))

;;; Multiple sidebar buffer support

(defun altodo-sidebar--get-buffer (&optional source-buffer)
  "Return sidebar buffer for SOURCE-BUFFER from alist.
If SOURCE-BUFFER is nil, use current buffer."
  (let ((buf (cdr (assoc (or source-buffer (current-buffer)) altodo-sidebar--buffer-alist))))
    (when (and buf (buffer-live-p buf)) buf)))

(defun altodo-sidebar--get-or-create-buffer (source-buffer)
  "Get or create sidebar buffer for SOURCE-BUFFER."
  (or (altodo-sidebar--get-buffer source-buffer)
      (let ((buf (generate-new-buffer
                  (format "*altodo-sidebar<%s>*" (buffer-name source-buffer)))))
        (with-current-buffer buf
          (setq-local altodo-sidebar--source-buffer source-buffer))
        (push (cons source-buffer buf) altodo-sidebar--buffer-alist)
        buf)))

(defun altodo-sidebar--cleanup-buffer (source-buffer)
  "Clean up sidebar buffer for SOURCE-BUFFER."
  (when-let ((buf (altodo-sidebar--get-buffer source-buffer)))
    (kill-buffer buf))
  (setq altodo-sidebar--buffer-alist
        (assoc-delete-all source-buffer altodo-sidebar--buffer-alist)))

(defun altodo-sidebar--on-source-buffer-kill ()
  "Clean up sidebar buffer when source buffer is killed."
  (altodo-sidebar--cleanup-buffer (current-buffer)))

(defun altodo--get-sidebar-buffer (&optional source-buffer)
  "Get sidebar buffer if it exists and is live.
Returns buffer or nil.
Can be called from either source or sidebar buffer.
SOURCE-BUFFER defaults to the current buffer."
  (let ((src (or source-buffer (current-buffer))))
    ;; If called from sidebar buffer, return current buffer
    (if (buffer-local-value 'altodo-sidebar--source-buffer src)
        (when (buffer-live-p src) src)
      (altodo-sidebar--get-buffer src))))

(defun altodo--with-sidebar-buffer (body-fn)
  "Execute BODY-FN in sidebar buffer context if it exists.
Returns result of BODY-FN or nil if sidebar buffer doesn\\='t exist."
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
     ((eq type 'search-lambda)
      (if (altodo--entry-code-permitted-p entry)
          pattern
        (lambda () nil)))
     ((eq type 'search-simple)
      (altodo--compile-simple-pattern pattern))
     (t (lambda () nil)))))

(defun altodo--combine-predicates (predicates combine-mode)
  "Combine multiple PREDICATES with COMBINE-MODE.
COMBINE-MODE is \\='and or \\='or.
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

(defmacro altodo--with-filter-rollback (&rest body)
  "Run BODY; if it signals an error, remove the filter overlays and re-signal.
A predicate that fails halfway would otherwise leave only some of the lines
hidden, which looks like a filter result."
  (declare (indent 0))
  `(condition-case err
       (progn ,@body)
     (error
      (mapc #'delete-overlay altodo--filter-overlays)
      (setq altodo--filter-overlays nil)
      (message "altodo: filter failed, the filter was cleared: %s"
               (error-message-string err))
      (signal (car err) (cdr err)))))

(cl-defun altodo--filter-lines (predicate &optional (show-multiline-comment t)
                                          display-context)
  "Apply filter using PREDICATE function.
PREDICATE is called at the beginning of each line.
If PREDICATE returns t, the line is shown; otherwise, it is hidden.
SHOW-MULTILINE-COMMENT (default t) controls whether to show multiline comments
attached to matching task/comment lines.  Passing nil hides them.
DISPLAY-CONTEXT (default \\='heading-only) controls display of heading and
comment lines:
  - \\='all: show heading and multiline comments
  - \\='heading-only: show heading only
  - \\='none: show matched lines only"
  (let ((show-multiline show-multiline-comment)
        (ctx (or display-context 'heading-only))
        (matched-line-numbers nil)
        (current-line-number 1))

    ;; Fill the heading cache
    (altodo--compute-all-heading-ranges)

    (unwind-protect
        (let ((altodo--filter-defer-prune t))
          (altodo--with-filter-rollback
           (save-excursion
             ;; First pass: create overlays for all lines
             (goto-char (point-min))
             (while (not (eobp))
               (let* ((line-start (line-beginning-position))
                      (line-end (1+ (line-end-position))))
                 (unless (altodo--filter-find-overlay line-start line-end)
                   (altodo--filter-create-overlay line-start line-end t)))
               (forward-line 1))

             ;; Second pass: remove overlays for matched lines and collect line numbers
             (setq current-line-number 1)
             (goto-char (point-min))
             (while (not (eobp))
               (let* ((line-start (line-beginning-position))
                      (line-end (1+ (line-end-position)))
                      (match (funcall predicate)))
                 (if match
                     ;; Show line: remove overlay if exists
                     (progn
                       (altodo--filter-remove-overlay line-start line-end)
                       ;; Collect matched line numbers for display-context processing
                       (push current-line-number matched-line-numbers)

                       ;; Handle multiline comments if show-multiline is t
                       (when show-multiline
                         (let ((comment-range (altodo--get-multiline-comment-range)))
                           (when comment-range
                             (altodo--filter-show-multiline-comments (car comment-range) (cdr comment-range))))))))

               (forward-line 1)
               (setq current-line-number (1+ current-line-number)))

             ;; Third pass: apply display-context option
             (when (and matched-line-numbers (not (eq ctx 'none)))
               (let ((display-lines (sort (altodo--compute-display-lines
                                           (nreverse matched-line-numbers) ctx)
                                          #'<))
                     (current-line 1))
                 ;; Walk the sorted line numbers once instead of counting lines
                 ;; from the beginning of the buffer for each of them.
                 (goto-char (point-min))
                 (dolist (line-num display-lines)
                   (forward-line (- line-num current-line))
                   (setq current-line line-num)
                   (altodo--filter-remove-overlay (line-beginning-position)
                                                  (1+ (line-end-position)))))))))
      (altodo--filter-prune-overlays))

    ;; Force redisplay after all overlays are processed
    (redisplay t)))

;;; Display Context Helper Functions

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
Return new DISPLAY-LINES with consecutive blank lines reduced to one."
  (let ((sorted-lines (sort (copy-sequence display-lines) #'<))
        (result nil)
        (prev-blank-p nil)
        (current-line 1))
    (save-excursion
      (goto-char (point-min))
      (dolist (line sorted-lines)
        ;; Move from the previous line number instead of the buffer start.
        (forward-line (- line current-line))
        (setq current-line line)
        (let ((blank-p (looking-at "^[ \t]*$")))
          (if (and blank-p prev-blank-p)
              ;; Skip consecutive blank lines
              nil
            ;; Add line
            (push line result)
            (setq prev-blank-p blank-p)))))
    (nreverse result)))

(defun altodo--add-heading-spacing (display-lines heading-line
                                                  &optional later-line-p)
  "Add spacing lines before and after HEADING-LINE to DISPLAY-LINES.
Always add the line after the heading.
Add the line before the heading only if DISPLAY-LINES already has a line
after this heading.  A non-nil LATER-LINE-P tells that DISPLAY-LINES has such
a line, which saves scanning the list.  Return the new DISPLAY-LINES."
  ;; Always add line after heading
  (let ((next-line (1+ heading-line)))
    (unless (member next-line display-lines)
      (push next-line display-lines)))
  ;; Add line before heading only if not first heading
  ;; (i.e., if there are lines after this heading already in display-lines)
  (when (or later-line-p
            (seq-some (lambda (line) (> line heading-line)) display-lines))
    (let ((prev-line (1- heading-line)))
      (when (and (> prev-line 0)
                 (not (member prev-line display-lines)))
        (push prev-line display-lines))))
  ;; Always add heading line
  (unless (member heading-line display-lines)
    (push heading-line display-lines))
  display-lines)

(defvar altodo--goto-line-cache nil
  "Cons of a line number and its position, used by `altodo--goto-line'.
Bind this to nil around a loop that visits many lines in ascending order.")

(defun altodo--goto-line (line-num)
  "Move point to the beginning of line LINE-NUM.
Counts lines from the line cached in `altodo--goto-line-cache' when
LINE-NUM is at or after it, and from the beginning of the buffer otherwise."
  (let ((cache altodo--goto-line-cache))
    (if (and cache (>= line-num (car cache)))
        (progn (goto-char (cdr cache))
               (forward-line (- line-num (car cache))))
      (goto-char (point-min))
      (forward-line (1- line-num)))
    (setq altodo--goto-line-cache (cons line-num (point)))))

;; A heading range is (HEADING-LINE START-LINE END-LINE) in line numbers:
;; the lines START-LINE..END-LINE belong to the heading at HEADING-LINE.
;; END-LINE is the line of the heading that ends the range (inclusive).

(defun altodo--heading-line-ranges (heading-ranges)
  "Return HEADING-RANGES as a vector of (HEADING-LINE START-LINE END-LINE).
HEADING-RANGES is the alist from `altodo--compute-all-heading-ranges', whose
ranges are buffer positions.  The vector keeps the buffer order."
  (save-excursion
    (vconcat
     (mapcar (lambda (entry)
               (let* ((range (cdr entry))
                      (start-line (progn (goto-char (car range))
                                         (+ (line-number-at-pos)
                                            (if (bolp) 0 1))))
                      (end-line (progn (goto-char (cdr range))
                                       (line-number-at-pos))))
                 (list (1- start-line) start-line end-line)))
             heading-ranges))))

(defun altodo--map-lines-to-headings (lines line-ranges)
  "Map each line number in LINES to the indexes of LINE-RANGES containing it.
LINE-RANGES is the vector from `altodo--heading-line-ranges'.  The result is
a hash table; the indexes of a line are in buffer order (outer heading first).
Heading ranges nest, so one pass over the sorted LINES with a stack of the
ranges that contain the current line is enough."
  (let ((table (make-hash-table))
        (count (length line-ranges))
        (next 0)
        (stack nil))
    (dolist (line (sort (delete-dups (copy-sequence lines)) #'<))
      (while (and (< next count) (<= (nth 1 (aref line-ranges next)) line))
        (while (and stack
                    (< (nth 2 (aref line-ranges (car stack)))
                       (nth 1 (aref line-ranges next))))
          (pop stack))
        (push next stack)
        (setq next (1+ next)))
      (while (and stack (< (nth 2 (aref line-ranges (car stack))) line))
        (pop stack))
      (when stack
        (puthash line (reverse stack) table)))
    table))

(defun altodo--add-comment-lines (line-num max-line display-lines seen)
  "Add the multiline comment lines of line LINE-NUM to DISPLAY-LINES.
MAX-LINE is the number of the last line.  SEEN is the hash table of the
lines in DISPLAY-LINES; it is updated.  Returns the new DISPLAY-LINES.
The line after the comment is added too, because the range from
`altodo--get-multiline-comment-range' ends at the beginning of that line."
  (save-excursion
    (altodo--goto-line line-num)
    (let ((line-start (point))
          (comment-range (altodo--get-multiline-comment-range)))
      (when comment-range
        (goto-char (car comment-range))
        ;; The range starts at LINE-NUM itself on the last line of a buffer
        ;; without a final newline, as `forward-line' cannot move past it.
        (let ((comment-line (if (= (car comment-range) line-start)
                                (min line-num max-line)
                              (1+ (min line-num max-line))))
              (iter 0))
          (while (and (<= (point) (cdr comment-range)) (< iter 1000))
            (unless (gethash comment-line seen)
              (puthash comment-line t seen)
              (push comment-line display-lines))
            (setq iter (1+ iter))
            (if (and (zerop (forward-line 1)) (bolp))
                (setq comment-line (1+ comment-line))
              ;; End of the buffer: the next lines would repeat this one.
              (setq iter 1000)))))))
  display-lines)

(defun altodo--compute-display-lines (matched-lines display-context)
  "Compute display lines based on DISPLAY-CONTEXT option.
MATCHED-LINES: list of line numbers that match the filter
DISPLAY-CONTEXT: \\='all, \\='heading-only, or \\='none
Returns: list of line numbers to display (including heading and comment lines)"
  ;; Fill the heading cache, as the other filter functions use it.
  (let ((heading-ranges (altodo--compute-all-heading-ranges)))
    (if (not (memq display-context '(all heading-only)))
        matched-lines
      (let* ((display-lines matched-lines)
             ;; The lines of DISPLAY-LINES, for the membership tests.
             (seen (make-hash-table))
             (max-line (save-excursion (goto-char (point-max))
                                       (line-number-at-pos)))
             (line-ranges (altodo--heading-line-ranges heading-ranges))
             (headings-of-line
              (altodo--map-lines-to-headings
               (mapcar (lambda (line) (min line max-line)) matched-lines)
               line-ranges))
             (altodo--goto-line-cache nil))
        (dolist (line matched-lines)
          (puthash line t seen))
        (dolist (line-num matched-lines)
          (let ((line (min line-num max-line)))
            ;; Add the headings that contain the line.
            (dolist (index (gethash line headings-of-line))
              (let ((heading-line (car (aref line-ranges index))))
                (unless (gethash heading-line seen)
                  (let ((previous display-lines))
                    ;; LINE is in the range of the heading, so DISPLAY-LINES
                    ;; has a line after the heading.
                    (setq display-lines (altodo--add-heading-spacing
                                         display-lines heading-line t))
                    (let ((added display-lines))
                      (while (not (eq added previous))
                        (puthash (car added) t seen)
                        (setq added (cdr added)))))))))
          (when (eq display-context 'all)
            (setq display-lines
                  (altodo--add-comment-lines line-num max-line display-lines
                                             seen))))
        (if (eq display-context 'all)
            display-lines
          (altodo--collapse-blank-lines display-lines))))))

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
  "Return t if the current line has TAG.
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
  "Extract tag value from MATCH-STRING, removing quotes if present."
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
Priority flag can be one or more \\='!\\=' characters followed by a space.
It may follow a star flag."
  (save-excursion
    (beginning-of-line)
    (when (looking-at altodo-task-regex)
      (and (nth 1 (altodo--parse-flags (match-string 3))) t))))

(defun altodo--line-has-star-p ()
  "Return t if current line has star flag (+), nil otherwise.
It may follow a priority flag."
  (save-excursion
    (beginning-of-line)
    (when (looking-at altodo-task-regex)
      (altodo--has-star-flag-p (match-string 3)))))

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

(defun altodo--person-search-regex (person)
  "Return the regexp that matches @PERSON in a line.
The @ must be at the beginning of the line or after a space, so the @ in a
URL such as https://example.com/a@b is not a person."
  (concat "\\(?:^\\|[[:space:]]\\)@" (regexp-quote person) "\\>"))

(defun altodo--line-has-person-p (person)
  "Return t if the current line has PERSON.
PERSON should be a string like \"john\" (without @)."
  (save-excursion
    (beginning-of-line)
    (and (or (altodo--task-p) (altodo--comment-p))
         (re-search-forward (altodo--person-search-regex person)
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

(defun altodo--line-date-value (kind)
  "Return the date of KIND on the current line as \"YYYY-MM-DD\", or nil.
KIND is `due' (\"-> DATE\") or `start' (\"DATE ->\").  The date is looked for
only on the lines where dates are recognized (see `altodo--date-line-p'),
with the spaces that the format specification requires, whatever
`altodo-date-format' is."
  (save-excursion
    (beginning-of-line)
    (when (altodo--date-line-p)
      (let* ((regex-info (altodo--date-regex-info))
             (regex (if (eq kind 'due)
                        (concat "\\(?:^\\| \\)-> " (nth 0 regex-info)
                                "\\(?: \\|$\\)")
                      (concat "\\(?:^\\| \\)" (nth 0 regex-info)
                              " ->\\(?: \\|$\\)"))))
        (when (re-search-forward regex (line-end-position) t)
          (format "%s-%s-%s"
                  (match-string (nth 2 regex-info))
                  (match-string (nth 3 regex-info))
                  (match-string (nth 4 regex-info))))))))

(defun altodo--line-due-date-p ()
  "Return non-nil if the current line has a due date."
  (and (altodo--line-date-value 'due) t))

(defun altodo--line-due-date-value ()
  "Get due date from current line.
Returns date string (e.g., \"2026-01-31\") or nil."
  (altodo--line-date-value 'due))

(defun altodo--days-to-week-end ()
  "Return the number of days from today to the last day of this week.
The week starts on `altodo-week-start-day' (0 is Sunday, 1 is Monday).
If the variable is nil, the week starts on Sunday."
  (let ((today-wday (nth 6 (decode-time (current-time))))
        (week-start (or altodo-week-start-day 0)))
    (mod (- (+ week-start 6) today-wday) 7)))

(defun altodo--days-to-month-end ()
  "Return the number of days from today to the last day of this month."
  (let* ((today-decoded (decode-time (current-time)))
         (today-day (nth 3 today-decoded))
         (month (nth 4 today-decoded))
         (year (nth 5 today-decoded))
         (next-month (if (= month 12) 1 (1+ month)))
         (next-year (if (= month 12) (1+ year) year))
         ;; Start from noon so that a daylight saving time change cannot
         ;; move the result to the previous day.
         (last-day (nth 3 (decode-time
                           (time-subtract
                            (encode-time 0 0 12 1 next-month next-year)
                            (* 24 60 60))))))
    (- last-day today-day)))

(defconst altodo--due-date-specific-conditions
  (list (cons 'overdue (lambda (days-diff) (< days-diff 0)))
        (cons 'tomorrow (lambda (days-diff) (= days-diff 1))))
  "Alist of (CONDITION . PREDICATE) that only the due date has.
PREDICATE gets the days from today to the due date.")

(defconst altodo--start-date-specific-conditions
  (list (cons 'passed (lambda (days-diff) (< days-diff 0)))
        (cons 'not-yet (lambda (days-diff) (> days-diff 0))))
  "Alist of (CONDITION . PREDICATE) that only the start date has.
PREDICATE gets the days from today to the start date.")

(defun altodo--date-matches-condition-p (date condition specific-conditions)
  "Return non-nil if DATE matches CONDITION.
DATE is a string such as \"2026-01-31\".  CONDITION is a symbol, a date
string, or a list (before/after/between/within/past), as parsed by
`altodo--parse-date-condition'.  SPECIFIC-CONDITIONS is the alist of the
conditions that only the due date or only the start date has.  A DATE that
does not exist matches nothing."
  (let* ((date-time (altodo--parse-normalized-date date))
         (days-diff (and date-time (altodo--days-diff date-time)))
         (specific (and (symbolp condition)
                        (assq condition specific-conditions))))
    (when days-diff
      (if specific
          (funcall (cdr specific) days-diff)
        (pcase condition
          ('today (= days-diff 0))
          ('this-week
           (and (>= days-diff 0) (<= days-diff (altodo--days-to-week-end))))
          ('this-month
           (and (>= days-diff 0) (<= days-diff (altodo--days-to-month-end))))
          ((pred stringp) (string= date condition))
          (`(before ,limit) (string< date limit))
          (`(after ,limit) (string> date limit))
          (`(between ,start ,end)
           (and (not (string< date start)) (not (string> date end))))
          (`(within ,days) (and (>= days-diff 0) (<= days-diff days)))
          (`(past ,days) (>= (- days-diff) days))
          (_ nil))))))

(defun altodo--parse-date-condition (condition-str relative-conditions label)
  "Parse the date condition string CONDITION-STR.
RELATIVE-CONDITIONS is the list of the names that stand for themselves as
symbols, such as \"overdue\".  LABEL (\"due\" or \"start\") is used in the error
message.  Return a symbol, a date string, or a list (before/after/between/
within/past).  The dates are written in `altodo-date-format'.  Signal an
error if CONDITION-STR is not a condition or has a date that does not exist."
  (let ((expected (or altodo-date-format "YYYY-MM-DD")))
    (cond
     ((member condition-str relative-conditions) (intern condition-str))
     ((string-match "^\\(before\\|after\\):\\(.+\\)$" condition-str)
      (let ((kind (match-string 1 condition-str))
            (date-str (match-string 2 condition-str)))
        (unless (altodo--parse-date date-str)
          (error "Invalid date format in '%s' condition: %s (expected format: %s)"
                 kind date-str expected))
        (list (intern kind) (altodo--normalize-date-string date-str))))
     ((string-match "^between:\\(.+\\):\\(.+\\)$" condition-str)
      (let ((start-str (match-string 1 condition-str))
            (end-str (match-string 2 condition-str)))
        (unless (and (altodo--parse-date start-str) (altodo--parse-date end-str))
          (error "Invalid date format in 'between' condition (expected format: %s)"
                 expected))
        (list 'between (altodo--normalize-date-string start-str)
              (altodo--normalize-date-string end-str))))
     ((string-match "^\\(within\\|past\\):\\([0-9]+\\)$" condition-str)
      (list (intern (match-string 1 condition-str))
            (string-to-number (match-string 2 condition-str))))
     ((altodo--parse-date condition-str)
      (altodo--normalize-date-string condition-str))
     (t (error "Invalid %s date condition: %s" label condition-str)))))

(defun altodo--due-date-matches-p (condition)
  "Check if current line\\='s due date matches CONDITION.
CONDITION: \\='overdue, \\='today, \\='tomorrow, \\='this-week, \\='this-month,
           string (date), or list (before/after/between/within/past).
Returns t if matches, nil otherwise."
  (let ((due-date (altodo--line-due-date-value)))
    (and due-date
         (altodo--date-matches-condition-p
          due-date condition altodo--due-date-specific-conditions))))

(defun altodo--parse-due-date-condition (condition-str)
  "Parse due date condition string CONDITION-STR.
Returns parsed condition (symbol, string, or list).
Supports altodo-date-format for date strings.
Signals error on invalid date format."
  (altodo--parse-date-condition
   condition-str
   '("overdue" "today" "tomorrow" "this-week" "this-month")
   "due"))


;; ========================================
;; 開始日フィルタ（start-date）
;; ========================================

(defun altodo--line-start-date-p ()
  "Return non-nil if the current line has a start date."
  (and (altodo--line-date-value 'start) t))

(defun altodo--line-start-date-value ()
  "Get start date from current line.
Returns date string (e.g., \"2026-01-01\") or nil."
  (altodo--line-date-value 'start))

(defun altodo--start-date-matches-p (condition)
  "Check if current line\\='s start date matches CONDITION.
CONDITION: \\='passed, \\='today, \\='not-yet, \\='this-week, \\='this-month,
           string (date), or list (before/after/between/within/past).
Returns t if matches, nil otherwise."
  (let ((start-date (altodo--line-start-date-value)))
    (and start-date
         (altodo--date-matches-condition-p
          start-date condition altodo--start-date-specific-conditions))))

(defun altodo--parse-start-date-condition (condition-str)
  "Parse start date condition string CONDITION-STR.
Returns parsed condition (symbol, string, or list).
Supports altodo-date-format for date strings.
Signals error on invalid date format."
  (altodo--parse-date-condition
   condition-str
   '("passed" "today" "not-yet" "this-week" "this-month")
   "start"))


(defun altodo--line-text-contains-p (text)
  "Return t if the current line has TEXT.
Return t if condition is true, nil otherwise."
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
  "Return t if the root parent task (indent=0) matches REGEXP.
The current line counts when it is the root task.
Return nil if no root parent task exists or REGEXP is nil."
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
  "Return t if STRING begins with a logic operator (and:, or:, not:).
Return t if condition is true, nil otherwise."
  (string-match-p (concat "^" altodo--dsl-logic-operators-regex) string))

;; ============================================================================
;; DSL Pattern Compiler
;; ============================================================================

(defun altodo--split-logic-args (args-string)
  "Split ARGS-STRING by top-level commas only.
Handles multiple logic operators at the same level.

Supports:
- Simple patterns: \"done,priority,cancelled\" → (\"done\" \"priority\"
\"cancelled\")
- Single logic operator: \"and:done,priority\" → (\"and:done,priority\")
- Multiple same-level operators: \"and:done,priority,and:cancelled,star\"
  → (\"and:done,priority\" \"and:cancelled,star\")

Limitations:
- Nested logic operators are NOT split: \"or:and:done,priority,cancelled\"
  → (\"or:and:done,priority,cancelled\") - treated as single element
- Deep nesting (2+ levels) is not supported"
  (let ((result nil)
        (i 0)
        (len (length args-string))
        (in-logic nil))
    (while (< i len)
      (cond
       ;; Found logic operator at start (not nested)
       ((and (not in-logic) (altodo--logic-operator-p (substring args-string i)))
        (setq in-logic t)
        (let* ((_ (string-match altodo--dsl-logic-operators-regex (substring args-string i)))
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

(defun altodo--line-heading-p ()
  "Return non-nil if the current line is a heading (ATX or Setext title)."
  (and (not (looking-at "^[ \t]*$"))
       (not (altodo--task-p))
       (not (altodo--comment-p))
       (not (altodo--multiline-comment-p))
       (altodo--heading-level)
       t))

(defun altodo--line-empty-p ()
  "Return non-nil if the current line is empty or has only spaces."
  (save-excursion
    (beginning-of-line)
    (looking-at "[ \t]*$")))

(defun altodo--split-multi-arg (arg)
  "Split the argument ARG of a multi-value pattern into a list of strings.
The values are separated by commas or vertical bars.  A comma cannot be used
inside a logic operation, where it separates the operands; use a bar there."
  (split-string arg "[,|]" t "[ \t]+"))

(defun altodo--compile-any-of-simple-patterns (names allowed type)
  "Return a predicate that is true if any simple pattern in NAMES matches.
ALLOWED is the list of the simple patterns that TYPE accepts.  Signal an
error if NAMES is empty or has a name that is not in ALLOWED."
  (unless names
    (error "No value for %s" type))
  (dolist (name names)
    (unless (member name allowed)
      (error "Unknown value for %s: %s (expected one of: %s)"
             type name (string-join allowed ", "))))
  (let ((predicates (mapcar (lambda (name)
                              (altodo--compile-normalized-pattern
                               (list 'simple name)))
                            names)))
    (lambda ()
      (cl-some #'funcall predicates))))

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
       ("task" #'altodo--task-p)
       ("comment" #'altodo--comment-p)
       ("multiline-comment" #'altodo--multiline-comment-p)
       ("heading" #'altodo--line-heading-p)
       ("empty-line" #'altodo--line-empty-p)
       ("any-line" #'always)
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
       ("heading" (progn
                    ;; Report an invalid regexp when the pattern is compiled.
                    (condition-case nil
                        (string-match-p arg "")
                      (invalid-regexp
                       (error "Invalid regexp for heading: %s" arg)))
                    (lambda ()
                      (altodo--line-in-heading-range-with-filter-p
                       arg t 'only-tasks))))
       ("multiline-comment-contains" (lambda () (altodo--multiline-comment-contains-regexp-p arg)))
       ;; Parse the condition once here, so that an invalid condition is
       ;; reported when the pattern is compiled, not on every line.
       ("due-date" (let ((condition (altodo--parse-due-date-condition arg)))
                     (lambda () (altodo--due-date-matches-p condition))))
       ("start-date" (let ((condition (altodo--parse-start-date-condition arg)))
                       (lambda () (altodo--start-date-matches-p condition))))
       ("tag-value" (altodo--parse-tag-value-condition arg))
       ("state-any" (altodo--compile-any-of-simple-patterns
                     (altodo--split-multi-arg arg)
                     '("done" "progress" "waiting" "open" "cancelled")
                     type))
       ("has-any-flag" (altodo--compile-any-of-simple-patterns
                        (altodo--split-multi-arg arg) '("priority" "star") type))
       ("has-any-tag" (let ((tags (altodo--split-multi-arg arg)))
                        (lambda () (altodo--line-has-any-tag-p tags))))
       ("has-all-tags" (let ((tags (altodo--split-multi-arg arg)))
                         (lambda () (altodo--line-has-all-tags-p tags))))
       ("has-any-person" (let ((persons (altodo--split-multi-arg arg)))
                           (lambda () (altodo--line-has-any-person-p persons))))
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

Returns a lambda function.  On error, returns a fallback lambda that matches
nothing."
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
    (let ((lines nil))
      (forward-line 1)
      ;; Decide from the text, not from a text property set by font-lock,
      ;; so that the result does not depend on what is fontified.
      (while (and (not (eobp))
                  (altodo--multiline-comment-p))
        (push (line-number-at-pos) lines)
        (forward-line 1))
      (nreverse lines))))

(defun altodo--indent-multiline-comments (lines indent-delta)
  "Indent multiline comment LINES by INDENT-DELTA spaces."
  (save-excursion
    (dolist (line-num lines)
      (goto-char (point-min))
      (forward-line (1- line-num))
      (let ((current-indent (altodo--get-current-indent)))
        (altodo--set-line-indent (max 0 (+ current-indent indent-delta)))))))

(defun altodo-indent-line ()
  "Indent current line for altodo-mode with smart task hierarchy."
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
              ;; `markdown-cycle' falls back to `indent-line-function', which
              ;; is this function; bind it to the Markdown one to avoid an
              ;; endless recursion.
              (let ((indent-line-function
                     (if (fboundp 'markdown-indent-line)
                         #'markdown-indent-line
                       #'indent-relative)))
                (if (fboundp 'markdown-cycle)
                    (markdown-cycle)
                  (indent-for-tab-command)))
              nil))))
      (when new-indent
        (let* ((indent-delta (- new-indent current-indent))
               ;; Collect the comment lines before changing the indentation:
               ;; they are a comment only while they are indented by 4 spaces
               ;; more than this line.
               (multiline-lines (when (and (or (altodo--task-p)
                                               (altodo--comment-p))
                                           (/= indent-delta 0))
                                  (altodo--get-multiline-comment-lines))))
          ;; 現在行をインデント
          (altodo--set-line-indent new-indent)
          ;; 複数行コメントも一緒にインデント（タスク/1行コメントの場合のみ）
          (when multiline-lines
            (altodo--indent-multiline-comments multiline-lines indent-delta))
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
  (ignore current-indent)
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
  "Handle RET key in altodo-mode."
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
  "Internal function for altodo-enter processing."
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
If INDENT-DEEPER is non-nil, add as subtask (one level deeper)."
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
  "Add a new subtask (indented one level deeper)."
  (interactive)
  (if (or (altodo--task-p) (altodo--comment-p))
      (altodo-add-task t)
    (message "Not on a task or comment line")))

(defun altodo-toggle-comment ()
  "Toggle between task and comment."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (cond
     ((looking-at altodo-task-regex)
      ;; Group 1 is the indentation.  Group 3 starts with the space after
      ;; the state mark, if any.
      (let ((new-text (save-match-data
                        (concat (match-string 1) altodo-comment-marker " "
                                (string-trim-left (match-string 3))))))
        (replace-match new-text nil t)))
     ((looking-at altodo-comment-regex)
      (replace-match "\\1[ ] \\2" nil nil)))))

;; === Flags ===
;; A task or `///' line can have a star flag (+) and a priority flag (!, !!,
;; !!!) together, in either order, each followed by one space.  The commands
;; write the star first.

(defun altodo--parse-flags (content)
  "Split CONTENT into its leading flags and the rest.
Return (STAR PRIORITY REST).  STAR is non-nil with a star flag, PRIORITY
is the level (1 to 3) or nil, and REST is the text after the flags.
A flag is the star or a run of the priority character, followed by a
space.  The order does not matter, and each kind counts once."
  (let ((pos (if (string-match "\\`[ \t]*" content) (match-end 0) 0))
        (regex (concat "\\(" (regexp-quote altodo-flag-star) "\\|"
                       (regexp-quote altodo-flag-priority) "+\\) "))
        (star nil)
        (priority nil)
        (done nil))
    (while (and (not done)
                (string-match regex content pos)
                (= (match-beginning 0) pos))
      (let ((flag (match-string 1 content)))
        (cond
         ((and (string= flag altodo-flag-star) (not star))
          (setq star t pos (match-end 0)))
         ((and (not (string= flag altodo-flag-star)) (not priority))
          (setq priority (min (length flag) 3) pos (match-end 0)))
         (t (setq done t)))))
    (list star priority (substring content pos))))

(defun altodo--format-flags (star priority rest)
  "Return the flags STAR and PRIORITY followed by REST, separated by spaces."
  (mapconcat #'identity
             (delq nil (list (and star altodo-flag-star)
                             (and priority
                                  (make-string priority
                                               (string-to-char
                                                altodo-flag-priority)))
                             (and (not (string-empty-p rest)) rest)))
             " "))

(defun altodo--get-priority-level ()
  "Get priority level (1-3) of current line, or nil if no priority flag."
  (save-excursion
    (beginning-of-line)
    (let ((content (cond
                    ((looking-at altodo-task-regex) (match-string 3))
                    ((looking-at altodo-comment-regex) (match-string 2)))))
      (when content
        (nth 1 (altodo--parse-flags content))))))

(defun altodo--remove-priority-from-string (str)
  "Remove the priority flag (!, !!, !!!) from STR, keeping the star flag."
  (pcase-let ((`(,star ,_ ,rest) (altodo--parse-flags str)))
    (altodo--format-flags star nil rest)))

(defun altodo--has-star-flag-p (str)
  "Return t if STR has star flag (+)."
  (and (nth 0 (altodo--parse-flags str)) t))

(defun altodo--remove-star-from-string (str)
  "Remove the star flag (+) from STR, keeping the priority flag."
  (pcase-let ((`(,_ ,priority ,rest) (altodo--parse-flags str)))
    (altodo--format-flags nil priority rest)))

(defun altodo--replace-flags (transform)
  "Rewrite the flags of the task or comment line at point.
TRANSFORM is called with the star, the priority and the rest of the line,
and returns the new content.  Return non-nil if the line was changed."
  (save-excursion
    (beginning-of-line)
    (cond
     ((looking-at altodo-task-regex)
      (let* ((indent (match-string 1))
             (state (match-string 2))
             (parsed (save-match-data (altodo--parse-flags (match-string 3))))
             (new (save-match-data (apply transform parsed))))
        (replace-match (format "%s[%s]%s" indent (or state " ")
                               (if (string-empty-p new) "" (concat " " new))))
        t))
     ((looking-at altodo-comment-regex)
      (let* ((indent (match-string 1))
             (parsed (save-match-data (altodo--parse-flags (match-string 2))))
             (new (save-match-data (apply transform parsed))))
        (replace-match (format "%s%s%s" indent altodo-comment-marker
                               (if (string-empty-p new) "" (concat " " new))))
        t))
     (t (message "Not on a task or comment line") nil))))

(defun altodo--set-priority-flag (level)
  "Set priority flag to LEVEL (1-3) on current line.
The star flag is kept."
  (altodo--replace-flags
   (lambda (star _priority rest)
     (altodo--format-flags star level rest))))

(defun altodo-set-priority-1 ()
  "Set priority flag to level 1 (!)."
  (interactive)
  (altodo--set-priority-flag 1))

(defun altodo-set-priority-2 ()
  "Set priority flag to level 2 (!!)."
  (interactive)
  (altodo--set-priority-flag 2))

(defun altodo-set-priority-3 ()
  "Set priority flag to level 3 (!!!)."
  (interactive)
  (altodo--set-priority-flag 3))

(defun altodo-toggle-star-flag ()
  "Toggle star flag (+) on current task or comment line.
The priority flag is kept."
  (interactive)
  (altodo--replace-flags
   (lambda (star priority rest)
     (altodo--format-flags (not star) priority rest)))
  nil)

(defun altodo-start-multiline-comment ()
  "Start a multiline comment at current indentation level + 4."
  (interactive)
  (if (or (altodo--task-p) (altodo--comment-p))
      (let ((indent (altodo--get-current-indent)))
        (end-of-line)
        (newline)
        (indent-to (+ indent altodo-indent-size)))
    (message "Not on a task or comment line")))

;;; Auto-mode

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.altodo\\'" . altodo-mode))


;;; Done Task Movement

(defcustom altodo-done-file-prefix "_done"
  "Prefix for done task files."
  :type 'string
  :group 'altodo)

(defcustom altodo-auto-move-interval 3600
  "Interval in seconds for auto-moving done tasks (default: 3600 = 1 hour).
Must be a positive number."
  :type 'natnum
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
                 buffer-file-name
                 (or (not altodo-auto-move-skip-done-files)
                     (not (altodo--is-done-file-p))))
        ;; An error in one buffer must not stop the other buffers.
        (condition-case err
            (altodo-move-all-done-tasks altodo-auto-save-after-move)
          (error
           (message "altodo: auto-move skipped %s: %s" (buffer-name)
                    (error-message-string err))))))))

(defun altodo-toggle-auto-move-timer ()
  "Toggle auto-move timer for done tasks."
  (interactive)
  (if altodo--auto-move-timer
      (altodo-stop-auto-move-timer)
    (altodo-start-auto-move-timer)))

(defun altodo-start-auto-move-timer ()
  "Start auto-move timer for done tasks."
  (interactive)
  (unless (and (numberp altodo-auto-move-interval)
               (> altodo-auto-move-interval 0))
    (user-error "The value of altodo-auto-move-interval must be a positive number: %S"
                altodo-auto-move-interval))
  (when altodo--auto-move-timer
    (cancel-timer altodo--auto-move-timer))
  (setq altodo--auto-move-timer
        (run-with-timer altodo-auto-move-interval altodo-auto-move-interval
                        #'altodo--auto-move-all-buffers))
  (force-mode-line-update t)
  (message "altodo: Auto-move timer started (interval: %d seconds)" altodo-auto-move-interval))

(defun altodo-stop-auto-move-timer ()
  "Stop auto-move timer for done tasks."
  (interactive)
  (when altodo--auto-move-timer
    (cancel-timer altodo--auto-move-timer)
    (setq altodo--auto-move-timer nil)
    (force-mode-line-update t)
    (message "altodo: Auto-move timer stopped")))

(defun altodo--get-done-file-path ()
  "Get the path to the done file for current buffer."
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

(defun altodo--insert-done-entry (heading task-line comments)
  "Insert TASK-LINE and COMMENTS under HEADING in the current buffer.
HEADING is (LEVEL-MARKS . TEXT) or nil.  The entry goes to the end of the
section of HEADING; a new section is created at the end of the buffer if
the heading does not exist.  The current buffer must support
`markdown-next-heading'."
  (goto-char (point-min))
  (let ((heading-found nil)
        (insert-pos nil))
    (when heading
      (let ((heading-pattern (concat "^" (regexp-quote (car heading)) "[ \t]+"
                                     (regexp-quote (string-trim (cdr heading)))
                                     "[ \t]*$")))
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
        (unless (bolp) (insert "\n"))))))

(defun altodo--write-file-atomically (file)
  "Write the current buffer to FILE through a temporary file.
The temporary file is in the directory of FILE and replaces FILE by a
rename, so a failed write leaves FILE as it was."
  (let ((temp-file (make-temp-file
                    (expand-file-name ".altodo-done-"
                                      (file-name-directory file)))))
    (unwind-protect
        (progn
          (write-region (point-min) (point-max) temp-file nil 'silent)
          (set-file-modes temp-file (or (file-modes file)
                                        (default-file-modes)))
          (rename-file temp-file file t)
          (setq temp-file nil))
      (when temp-file
        (ignore-errors (delete-file temp-file))))))

(defun altodo--append-to-done-file (done-file heading task-line comments)
  "Append task to DONE-FILE under HEADING with TASK-LINE and COMMENTS.
If a buffer visits DONE-FILE, append to that buffer, and save it unless it
had unsaved changes.  Otherwise rewrite the file atomically."
  (let ((visiting (find-buffer-visiting done-file)))
    (if visiting
        (with-current-buffer visiting
          (let ((was-modified (buffer-modified-p)))
            (save-excursion
              (save-restriction
                (widen)
                (altodo--insert-done-entry heading task-line comments)))
            (if was-modified
                (message "altodo: appended to %s (unsaved changes, not saved)"
                         (buffer-name))
              (save-buffer))))
      (with-temp-buffer
        (when (file-exists-p done-file)
          (insert-file-contents done-file))
        (markdown-mode)  ; Enable markdown-mode for helper functions
        (altodo--insert-done-entry heading task-line comments)
        (altodo--write-file-atomically done-file)))))

(defun altodo--delete-task-from-buffer ()
  "Delete current task and its multiline comments from buffer."
  (let ((start (line-beginning-position))
        (end nil))
    (let ((region (altodo--get-multiline-comment-region)))
      (if region
          (setq end (cdr region))
        (setq end (line-beginning-position 2))))
    (delete-region start end)))

(defun altodo--check-can-move-tasks (done-file)
  "Signal a `user-error' unless done tasks can be moved to DONE-FILE.
The buffer must be writable, because the task is deleted from it after it
is appended to the done file.  DONE-FILE must be writable."
  (when buffer-read-only
    (user-error "Cannot move tasks: %s is read-only" (buffer-name)))
  (unless (if (file-exists-p done-file)
              (and (file-regular-p done-file) (file-writable-p done-file))
            (file-writable-p (file-name-directory done-file)))
    (user-error "Cannot write the done file: %s" done-file)))

(defcustom altodo-move-unit 'subtree
  "Unit in which done tasks are moved to the done file.
`subtree' Move a done or cancelled task with all its subtasks.  A task whose
          subtasks are not all done or cancelled is not moved.  The batch
          move and the automatic move handle only tasks without a parent.
`line'    Move only the task line and its multi-line comments.  The subtasks
          stay in the buffer, and a done subtask leaves its parent."
  :group 'altodo
  :type '(choice (const :tag "Task with subtasks" subtree)
                 (const :tag "Task line only" line)))

(defcustom altodo-move-after-days nil
  "Minimum number of days since the `#done' tag for the batch and automatic move.
If nil, every done or cancelled task is moved.  If a number N, a task is
moved only when the date of its `#done' tag is N or more days ago.  A task
without a `#done' tag that has a date is not moved.  With the unit
`subtree', every task of the subtree must be old enough.  The manual move
ignores this option."
  :group 'altodo
  :type '(choice (const :tag "Move at once" nil)
                 (natnum :tag "Days since #done")))

(defun altodo--line-done-tag-value ()
  "Return the value of the `#done' tag on the current line, or nil.
The quotes of a double-quoted value are removed."
  (save-excursion
    (beginning-of-line)
    (when (re-search-forward (concat "\\(?:^\\|[ \t]\\)#done:\\("
                                     altodo--done-tag-value-regex "\\)")
                             (line-end-position) t)
      (string-trim (match-string-no-properties 1) "\"" "\""))))

(defun altodo--done-tag-time (value)
  "Return the time value of the `#done' tag VALUE, or nil if not a date.
VALUE is an ISO 8601 date or time (the date part is used), a Unix time in
seconds, or a date in `altodo-date-format'."
  (cond
   ((string-match "\\`\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)" value)
    (altodo--encode-date (string-to-number (match-string 1 value))
                         (string-to-number (match-string 2 value))
                         (string-to-number (match-string 3 value))))
   ((string-match-p "\\`[0-9]\\{9,\\}\\'" value)
    (seconds-to-time (string-to-number value)))
   (t (altodo--parse-date value))))

(defun altodo--done-tag-days-ago ()
  "Return the days from the `#done' tag on the current line to today.
Return nil if the line has no `#done' tag with a date."
  (let* ((value (altodo--line-done-tag-value))
         (time (and value (altodo--done-tag-time value))))
    (and time (round (- (altodo--days-diff time))))))

(defun altodo--old-enough-to-move-p (end)
  "Return non-nil if the done tasks from point to END are old enough to move.
Always true if `altodo-move-after-days' is nil.  With the unit `subtree'
every task up to END must be old enough, otherwise only the task at point."
  (or (null altodo-move-after-days)
      (save-excursion
        (let ((old-enough t)
              (limit (if (eq altodo-move-unit 'subtree)
                         end
                       (line-beginning-position 2))))
          (while (and old-enough (< (point) limit))
            (when (altodo--task-p)
              (let ((days (altodo--done-tag-days-ago)))
                (unless (and days (>= days altodo-move-after-days))
                  (setq old-enough nil))))
            (forward-line 1))
          old-enough))))

(defun altodo--task-subtree-end ()
  "Return the end position of the subtree of the task at point.
The subtree is the task line and the following lines that are indented
deeper than it: subtasks, `///' lines and multi-line comments.  A blank line
belongs to the subtree only if a task or `///' line that is indented deeper
follows it.  The end is the beginning of the line after the subtree."
  (save-excursion
    (let ((indent (altodo--leading-spaces))
          (end (line-beginning-position 2))
          (inside t))
      (forward-line 1)
      (while (and inside (not (eobp)))
        (if (looking-at "^$")
            (progn
              (while (and (not (eobp)) (looking-at "^$"))
                (forward-line 1))
              (unless (and (not (eobp))
                           (> (altodo--leading-spaces) indent)
                           (altodo--task-or-comment-line-p))
                (setq inside nil)))
          (if (<= (altodo--leading-spaces) indent)
              (setq inside nil)
            (setq end (line-beginning-position 2))
            (forward-line 1))))
      end)))

(defun altodo--subtree-completed-p (end)
  "Return non-nil if all tasks from point to END are done or cancelled."
  (save-excursion
    (let ((completed t))
      (while (and completed (< (point) end))
        (when (and (altodo--task-p)
                   (not (altodo--is-done-or-cancelled-task)))
          (setq completed nil))
        (forward-line 1))
      completed)))

(defun altodo--count-tasks (end)
  "Return the number of task lines from point to END."
  (save-excursion
    (let ((count 0))
      (while (< (point) end)
        (when (altodo--task-p)
          (setq count (1+ count)))
        (forward-line 1))
      count)))

(defun altodo--task-has-parent-p ()
  "Return non-nil if the task at point is a subtask of another task."
  (save-excursion
    (let ((indent (altodo--leading-spaces))
          (found nil)
          (parent nil))
      (when (> indent 0)
        (while (and (not found) (not (bobp)))
          (forward-line -1)
          (unless (looking-at "^$")
            (when (< (altodo--leading-spaces) indent)
              (setq found t
                    parent (altodo--task-p))))))
      parent)))

(defun altodo--indented-subtree-text (start end indent)
  "Return the text from START to END without the first INDENT spaces of a line."
  (let ((text (buffer-substring-no-properties start end)))
    (if (zerop indent)
        text
      (let ((pattern (format "^ \\{1,%d\\}" indent)))
        (mapconcat (lambda (line) (replace-regexp-in-string pattern "" line))
                   (split-string text "\n") "\n")))))

(defun altodo--move-task-to-done-file (unit)
  "Move the task at point to the done file in UNIT, `subtree' or `line'.
Signal a `user-error' if the task is not done or cancelled, if UNIT is
`subtree' and a subtask is not done, or if the move is not possible.
Return the number of tasks moved."
  (unless (buffer-file-name)
    (user-error "Buffer is not visiting a file"))
  (unless (altodo--is-done-or-cancelled-task)
    (user-error "Current line is not a done or cancelled task"))
  (let ((done-file (altodo--get-done-file-path))
        (heading (altodo--get-task-heading)))
    (altodo--check-can-move-tasks done-file)
    (if (eq unit 'subtree)
        (let* ((start (line-beginning-position))
               (end (altodo--task-subtree-end))
               (indent (altodo--leading-spaces)))
          (unless (altodo--subtree-completed-p end)
            (user-error "Cannot move: the task has subtasks that are not done"))
          (let* ((count (altodo--count-tasks end))
                 (text (altodo--indented-subtree-text start end indent))
                 (newline (string-search "\n" text))
                 (task-line (substring text 0 newline))
                 (rest (and newline (substring text (1+ newline))))
                 (comments (and rest (not (string-empty-p rest)) rest)))
            (altodo--append-to-done-file done-file heading task-line comments)
            (delete-region start end)
            (message "Moved %d task(s) to %s" count done-file)
            count))
      (let* ((task-data (altodo--extract-task-with-comments)))
        (altodo--append-to-done-file done-file heading
                                     (car task-data) (cdr task-data))
        (altodo--delete-task-from-buffer)
        (message "Moved task to %s" done-file)
        1))))

(defun altodo-move-done-tasks-at-point ()
  "Move the done or cancelled task at point to the done file.
The unit is set by `altodo-move-unit'."
  (interactive)
  (altodo--move-task-to-done-file altodo-move-unit)
  nil)

(defun altodo-move-done-task-alone ()
  "Move only the done or cancelled task line at point to the done file.
Its subtasks stay in the buffer, whatever `altodo-move-unit' is."
  (interactive)
  (altodo--move-task-to-done-file 'line)
  nil)

(defun altodo--movable-in-batch-p ()
  "Return non-nil if the done task at point is moved by the batch move.
With `altodo-move-unit' `subtree', that is a task without a parent whose
subtasks are all done or cancelled.  If `altodo-move-after-days' is set, the
`#done' dates must also be old enough."
  (and (if (eq altodo-move-unit 'line)
           t
         (and (not (altodo--task-has-parent-p))
              (save-excursion
                (altodo--subtree-completed-p (altodo--task-subtree-end)))))
       (altodo--old-enough-to-move-p (altodo--task-subtree-end))))

(defun altodo-move-all-done-tasks (&optional auto-save)
  "Move all done/cancelled tasks in buffer to done file.
The unit is set by `altodo-move-unit'.
If AUTO-SAVE is non-nil, save buffer after moving tasks."
  (interactive)
  (unless (buffer-file-name)
    (user-error "Buffer is not visiting a file"))
  
  (let ((count 0)
        (original-pos (point)))
    (goto-char (point-min))
    (while (not (eobp))
      (if (and (altodo--is-done-or-cancelled-task)
               (altodo--movable-in-batch-p))
          (setq count (+ count (altodo--move-task-to-done-file
                                altodo-move-unit)))
        (forward-line 1)))
    (when (and auto-save (buffer-modified-p))
      (save-buffer))
    (goto-char (min original-pos (point-max)))
    (message "Moved %d task(s) to done file" count)))


;;; Date Input

(defvar-local altodo--calendar-target nil
  "In the calendar buffer: (MARKER . KIND) of the line to set the date on.
KIND is `due' or `start'.")

(defun altodo--format-date-list (date)
  "Return DATE, a list (MONTH DAY YEAR), as a string in `altodo-date-format'."
  (format-time-string (or altodo-date-format "%Y-%m-%d")
                      (encode-time (list 0 0 12 (nth 1 date) (nth 0 date)
                                         (nth 2 date) nil -1 nil))))

(defun altodo--line-date-bounds (kind)
  "Return (START . END) of the date text of KIND on the current line, or nil.
KIND is `due' (the date after \"->\") or `start' (the date before it)."
  (save-excursion
    (beginning-of-line)
    (when (re-search-forward
           (if (eq kind 'due)
               (altodo--due-date-regex)
             (altodo--start-date-regex))
           (line-end-position) t)
      (cons (match-beginning 1) (match-end 1)))))

(defun altodo--current-line-date (kind)
  "Return the date of KIND on the current line as (MONTH DAY YEAR), or nil."
  (let ((value (if (eq kind 'due)
                   (altodo--line-due-date-value)
                 (altodo--line-start-date-value))))
    (when (and value (string-match "\\`\\([0-9]+\\)-\\([0-9]+\\)-\\([0-9]+\\)\\'" value))
      (list (string-to-number (match-string 2 value))
            (string-to-number (match-string 3 value))
            (string-to-number (match-string 1 value))))))

(defun altodo--set-line-date (kind date)
  "Set the date of KIND on the current line to DATE, a list (MONTH DAY YEAR).
KIND is `due' or `start'.  An existing date of KIND is replaced.  Otherwise
the date is added: a due date as \"-> DATE\", a start date as \"DATE ->\";
if the other date exists, the arrow is shared (\"START -> DUE\")."
  (unless (or (altodo--task-p) (altodo--comment-p))
    (user-error "Not on a task or comment line"))
  (let ((text (altodo--format-date-list date))
        (bounds (altodo--line-date-bounds kind)))
    (save-excursion
      (cond
       (bounds
        (goto-char (car bounds))
        (delete-region (car bounds) (cdr bounds))
        (insert text))
       ((eq kind 'due)
        (let ((start-bounds (altodo--line-date-bounds 'start)))
          (if start-bounds
              (progn (goto-char (+ (cdr start-bounds) 3))
                     (insert " " text))
            (end-of-line)
            (insert " -> " text))))
       (t
        (let ((due-bounds (altodo--line-date-bounds 'due)))
          (if due-bounds
              (progn (goto-char (- (car due-bounds) 3))
                     (insert text " "))
            (end-of-line)
            (insert " " text " ->"))))))))

(defun altodo--select-date-with-calendar (kind)
  "Open the calendar and set the date of KIND on the current line from it.
Move to a date and press RET; press q to cancel."
  (unless (or (altodo--task-p) (altodo--comment-p))
    (user-error "Not on a task or comment line"))
  (let ((marker (point-marker))
        (initial (or (altodo--current-line-date kind) (calendar-current-date))))
    (calendar)
    (with-current-buffer calendar-buffer
      (setq-local calendar-week-start-day altodo-week-start-day)
      (setq altodo--calendar-target (cons marker kind))
      (use-local-map
       (make-composed-keymap
        (let ((map (make-sparse-keymap)))
          (define-key map (kbd "RET") #'altodo-calendar-pick-date)
          map)
        calendar-mode-map))
      (calendar-redraw)
      (calendar-goto-date initial))
    (message "Move to a date and press RET to set the %s date (q: cancel)"
             kind)))

(defun altodo-calendar-pick-date ()
  "Set the date at the cursor on the task line that opened the calendar."
  (interactive)
  (unless altodo--calendar-target
    (user-error "This calendar was not opened by altodo"))
  (let ((date (calendar-cursor-to-date))
        (marker (car altodo--calendar-target))
        (kind (cdr altodo--calendar-target)))
    (unless date
      (user-error "Move the cursor to a date"))
    (with-current-buffer (marker-buffer marker)
      (save-excursion
        (goto-char marker)
        (altodo--set-line-date kind date)))
    (calendar-exit)
    (message "Set the %s date to %s" kind (altodo--format-date-list date))))

(defun altodo--input-date-in-minibuffer (kind)
  "Read a date in the minibuffer and set the date of KIND on the current line."
  (unless (or (altodo--task-p) (altodo--comment-p))
    (user-error "Not on a task or comment line"))
  (altodo--set-line-date
   kind (calendar-read-date nil (or (altodo--current-line-date kind)
                                    (calendar-current-date)))))

(defun altodo-select-due-calendar ()
  "Select the due date (-> DATE) of the task at point in a calendar window.
Move to a date and press RET; press q to cancel."
  (interactive)
  (altodo--select-date-with-calendar 'due))

(defun altodo-select-start-calendar ()
  "Select the start date (DATE ->) of the task at point in a calendar window.
Move to a date and press RET; press q to cancel."
  (interactive)
  (altodo--select-date-with-calendar 'start))

(defun altodo-input-due-date ()
  "Input the due date (-> DATE) of the task at point in the minibuffer."
  (interactive)
  (altodo--input-date-in-minibuffer 'due))

(defun altodo-input-start-date ()
  "Input the start date (DATE ->) of the task at point in the minibuffer."
  (interactive)
  (altodo--input-date-in-minibuffer 'start))


;;; Filter Functions

(defun altodo--filter-init ()
  "Initialize filter system."
  (add-to-invisibility-spec 'altodo-filter))


(defun altodo-filter-clear ()
  "Clear all filters.
In the sidebar, clear the filters of its altodo buffer."
  (interactive)
  (let ((source (bound-and-true-p altodo-sidebar--source-buffer)))
    (if (and source (buffer-live-p source))
        (with-current-buffer source
          (altodo-filter-clear))
      (mapc #'delete-overlay altodo--filter-overlays)
      (setq altodo--filter-overlays nil)
      (setq altodo--filter-mode nil)
      (altodo-sidebar--reset-selection)
      (message "Filter cleared"))))


;; The commands below apply a DSL pattern (see `altodo--compile-simple-pattern')
;; to the buffer, so that the commands, the sidebar and the patterns of
;; `.altodo-locals.el' have one meaning for "done", "overdue" and so on.

(defvar altodo-filter-pattern-history nil
  "History of the DSL patterns read by `altodo-filter-by-pattern'.")

(defun altodo--apply-dsl-filter (pattern mode)
  "Show only the lines that match the DSL PATTERN and remember MODE.
MODE is the symbol stored in `altodo--filter-mode'.  An invalid PATTERN
signals a `user-error' and changes nothing."
  (let ((predicate
         (condition-case err
             (let ((normalized (altodo--normalize-pattern pattern)))
               (unless (altodo--validate-pattern normalized)
                 (error "Invalid pattern structure: %S" normalized))
               (altodo--compile-normalized-pattern normalized))
           (error (user-error "Invalid DSL pattern \"%s\": %s" pattern
                              (error-message-string err))))))
    (altodo--filter-lines predicate)
    (setq altodo--filter-mode mode)
    (altodo-sidebar--reset-selection)))

(defun altodo-filter-by-pattern (pattern)
  "Show only the lines that match the DSL PATTERN.
PATTERN is written as in the `:pattern' of a sidebar entry, for example
\"and:open,due-date:overdue\".  See `altodo-debug-explain-pattern' to find
out why a pattern does not match what you expect."
  (interactive
   (list (read-string "DSL pattern: " nil 'altodo-filter-pattern-history)))
  (altodo--apply-dsl-filter pattern (intern (format "pattern:%s" pattern))))

(defun altodo-filter-show-done-only ()
  "Show only done tasks."
  (interactive)
  (altodo--apply-dsl-filter "done" 'done))

(defun altodo-filter-show-progress-only ()
  "Show only tasks in progress."
  (interactive)
  (altodo--apply-dsl-filter "progress" 'progress))

(defun altodo-filter-show-waiting-only ()
  "Show only waiting tasks."
  (interactive)
  (altodo--apply-dsl-filter "waiting" 'waiting))

(defun altodo-filter-show-open-only ()
  "Show only open tasks."
  (interactive)
  (altodo--apply-dsl-filter "open" 'open))

(defun altodo-filter-show-cancelled-only ()
  "Show only cancelled tasks."
  (interactive)
  (altodo--apply-dsl-filter "cancelled" 'cancelled))

(defun altodo-filter-show-priority ()
  "Show only tasks with priority flag."
  (interactive)
  (altodo--apply-dsl-filter "priority" 'priority))

(defun altodo-filter-show-star ()
  "Show only tasks with star flag."
  (interactive)
  (altodo--apply-dsl-filter "star" 'star))

(defun altodo-filter-show-tag (tag)
  "Show only tasks with TAG."
  (interactive "sTag: ")
  (altodo--apply-dsl-filter (format "tag:%s" tag) (intern (format "tag:%s" tag)))
  (message "Showing tasks with tag #%s" tag))

(defun altodo-filter-show-overdue ()
  "Show only tasks whose due date has passed."
  (interactive)
  (altodo--apply-dsl-filter "and:task,due-date:overdue" 'overdue)
  (message "Showing overdue tasks only"))

(defun altodo-filter-show-person (person)
  "Show only tasks with PERSON."
  (interactive "sPerson: ")
  (altodo--apply-dsl-filter (format "person:%s" person)
                            (intern (format "person:%s" person)))
  (message "Showing tasks with person @%s" person))


;;; Sidebar UI

;; Customization Variables

(defvar altodo-sidebar--buffer-alist nil
  "Alist mapping source-buffer to sidebar-buffer.")

(defcustom altodo-sidebar-position 'left
  "Position of sidebar window.
Either \\='left, \\='right, \\='above or \\='below.
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
  "Whether to move the focus to the source window after a filter is applied.
Selecting a filter entry of the sidebar applies it to the source buffer.
When this is non-nil, the source window is selected afterward; otherwise the
sidebar keeps the focus."
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
  '((:title "" :type calendar :nest 1)
    (:title "Status" :type group-header :nest 0)
    (:title "Open [ ] - %n" :type search-simple :pattern "open" :count-format t :nest 1)
    (:title "In Progress [@] - %n" :type search-simple :pattern "progress" :count-format t :nest 1)
    (:title "Waiting [w] - %n" :type search-simple :pattern "waiting" :count-format t :nest 1)
    (:title "Done [x] - %n" :type search-simple :pattern "done" :count-format t :nest 1)
    (:title "Cancelled [~] - %n" :type search-simple :pattern "cancelled" :count-format t :nest 1)

    (:title "Flags" :type group-header :nest 0)
    (:title "Priority (!) - %n" :type search-simple :pattern "priority" :count-format t :nest 1)
    (:title "Star (+) - %n" :type search-simple :pattern "star" :count-format t :nest 1)
    (:title "Due" :type group-header :nest 0)
    (:title "Open and Over Due - %n"
            :type search-simple
            :pattern "and:due-date:overdue,not:state-any:done|cancelled"
            :count-format t :nest 1
            :face altodo-sidebar-search-lambda-face
            :face-rules ((>= 1 error)))
    (:title "Open and Due Today - %n"
            :type search-simple
            :pattern "and:due-date:today,not:state-any:done|cancelled"
            :count-format t :nest 1
            :face altodo-sidebar-search-lambda-face
            :face-rules ((>= 1 error)))
    (:title "Open and Due This Week - %n"
            :type search-simple
            :pattern "and:due-date:this-week,not:due-date:today,not:state-any:done|cancelled"
            :count-format t :nest 1
            :face altodo-sidebar-search-lambda-face)
    (:title "Tags" :type group-header :nest 0)
    (:title "#%s - %n" :type dynamic :dynamic-type "tag" :count-format t :limit 5 :nest 1
            :exclude-tag ("id" "dep" "done") :tag-mode "name-only")

    (:title "People" :type group-header :nest 0)
    (:title "@%s - %n" :type dynamic :dynamic-type "person" :count-format t :limit 5 :nest 1)

    (:title "Headings" :type group-header :nest 0)
    (:title "%s - %n" :type dynamic :dynamic-type "heading" :count-format t :nest 1)

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

;; The selection state is the four variables below.  Change them only with
;; `altodo-sidebar--set-selection'.
(defvar-local altodo-sidebar--selected-filters nil
  "List of the selected filter entries of the sidebar.
Each element is an entry plist from altodo-filter-patterns.  It has one
element after a click on an entry (mode `single') and the entries chosen
with \\[altodo-sidebar-toggle-selection] in mode `multiple'.")

(defvar-local altodo-sidebar--combine-mode 'and
  "Combine mode for multiple filters: \\='and or \\='or.
Default: \\='and (more restrictive).")

(defvar-local altodo-sidebar--selection-mode nil
  "Current selection mode: \\='single, \\='multiple, or nil (no selection).")

(defvar-local altodo-sidebar--current-combined-predicate nil
  "Current combined predicate for multiple filter selection.
Set by altodo-sidebar--apply-combined-filter.
Used by altodo-sidebar--render for dynamic count calculation.")

(defun altodo-sidebar--set-selection (entries mode &optional predicate)
  "Set the selection of the sidebar of the current buffer.
ENTRIES are the selected filter entries, MODE is `single', `multiple' or nil,
and PREDICATE is the combined predicate of ENTRIES in mode `multiple'.
This is the only function that changes the three variables, so they do not
disagree.  Nothing happens when the buffer has no sidebar."
  (altodo--with-sidebar-buffer
   (lambda ()
     (setq altodo-sidebar--selected-filters entries
           altodo-sidebar--selection-mode mode
           altodo-sidebar--current-combined-predicate predicate))))

(defun altodo-sidebar--reset-selection ()
  "Clear the selection of the sidebar of the current buffer and redraw it.
Nothing happens when the buffer has no sidebar."
  (when (altodo--get-sidebar-buffer)
    (altodo-sidebar--set-selection nil nil)
    (altodo-sidebar-refresh)
    (altodo--update-sidebar-modeline)))

(defun altodo-sidebar--multiple-p ()
  "Return non-nil if the current sidebar buffer has a multiple selection."
  (and altodo-sidebar--selected-filters
       (not (eq altodo-sidebar--selection-mode 'single))))

(defun altodo-sidebar--entry-state (entry)
  "Return `selected', `active' or nil for the filter ENTRY.
The current buffer is the sidebar.  ENTRY is `active' when it was clicked
and `selected' when it is one of several entries chosen with s."
  (when (member entry altodo-sidebar--selected-filters)
    (if (eq altodo-sidebar--selection-mode 'single) 'active 'selected)))

;; Generic Sidebar Framework Functions

(defun altodo-sidebar--display (config)
  "Display sidebar with CONFIG.
CONFIG is a plist with :name, :position, :width, :dedicated, :entries.
Returns the displayed window."
  (let ((buf (get-buffer-create (plist-get config :name))))
    (altodo-sidebar--setup-buffer buf config)
    (let ((action (altodo-sidebar--make-display-action config)))
      (let ((win (display-buffer buf action)))
        ;; Render after window is displayed
        (altodo-sidebar--render buf config)
        win))))

;;; Sidebar Calendar and Agenda

(defcustom altodo-calendar-heavy-count 3
  "Number of due tasks on one day from which the calendar uses the heavy face."
  :group 'altodo-calendar
  :type 'natnum)

(defcustom altodo-calendar-priority 'due
  "Which date wins on a day that has both due and start dates.
It decides the face of the day in the sidebar calendar and the filter that
a click on the day applies: the tasks due that day, or the tasks that start
that day."
  :group 'altodo-calendar
  :type '(choice (const :tag "Due date" due)
                 (const :tag "Start date" start)))

(defface altodo-agenda-date-face
  '((t :inherit default))
  "Face for the date of a line of the sidebar agenda."
  :group 'altodo-calendar)

(defface altodo-agenda-today-face
  '((t :inherit default :weight bold))
  "Face for today in the sidebar agenda."
  :group 'altodo-calendar)

(defface altodo-agenda-overdue-face
  '((t :inherit (altodo-calendar-overdue-face error)))
  "Face for the overdue line of the sidebar agenda."
  :group 'altodo-calendar)

(defface altodo-agenda-empty-face
  '((t :inherit shadow))
  "Face for a day without tasks in the sidebar agenda."
  :group 'altodo-calendar)

(defface altodo-agenda-count-face
  '((t :weight bold))
  "Face for the counts in the sidebar agenda."
  :group 'altodo-calendar)

(defvar-local altodo-sidebar--calendar-month nil
  "Month shown by the sidebar calendar as (MONTH . YEAR), or nil for this month.")

(defun altodo--today-date-list ()
  "Return today as a list (MONTH DAY YEAR)."
  (let ((decoded (decode-time (altodo--today-start))))
    (list (nth 4 decoded) (nth 3 decoded) (nth 5 decoded))))

(defun altodo--date-key (date)
  "Return DATE, a list (MONTH DAY YEAR), as the string YYYY-MM-DD."
  (format "%04d-%02d-%02d" (nth 2 date) (nth 0 date) (nth 1 date)))

(defun altodo--normalized-date-key (value)
  "Return VALUE, a string YYYY-MM-DD, padded, or nil if it is not a real date."
  (when (and value
             (string-match "\\`\\([0-9]+\\)-\\([0-9]+\\)-\\([0-9]+\\)\\'" value))
    (let ((year (string-to-number (match-string 1 value)))
          (month (string-to-number (match-string 2 value)))
          (day (string-to-number (match-string 3 value))))
      (when (altodo--valid-date-p year month day)
        (format "%04d-%02d-%02d" year month day)))))

(defun altodo--collect-date-counts (source-buffer count-done)
  "Count the tasks per due date and start date in SOURCE-BUFFER.
Return a hash table from YYYY-MM-DD to (DUE . START).  Tasks that are done
or cancelled are counted only if COUNT-DONE is non-nil."
  (let ((table (make-hash-table :test 'equal)))
    (when (and source-buffer (buffer-live-p source-buffer))
      (with-current-buffer source-buffer
        (save-excursion
          (goto-char (point-min))
          (while (not (eobp))
            (when (and (altodo--task-p)
                       (or count-done
                           (not (altodo--is-done-or-cancelled-task))))
              (let ((due (altodo--normalized-date-key
                          (altodo--line-due-date-value)))
                    (start (altodo--normalized-date-key
                            (altodo--line-start-date-value))))
                (when due
                  (let ((entry (gethash due table (cons 0 0))))
                    (puthash due (cons (1+ (car entry)) (cdr entry)) table)))
                (when start
                  (let ((entry (gethash start table (cons 0 0))))
                    (puthash start (cons (car entry) (1+ (cdr entry))) table)))))
            (forward-line 1)))))
    table))

(defun altodo--overdue-count (counts today-key)
  "Return the number of due tasks before TODAY-KEY in the hash table COUNTS."
  (let ((total 0))
    (maphash (lambda (key value)
               (when (string< key today-key)
                 (setq total (+ total (car value)))))
             counts)
    total))

(defun altodo--day-kind (info target)
  "Return `due', `start' or nil: the kind of date that decides a day.
INFO is the cons (DUE . START) of the counts of the day, or nil.  TARGET is
`due', `start' or `both'.  A day with both kinds takes the kind of
`altodo-calendar-priority'."
  (let ((due (and info (memq target '(due both)) (> (car info) 0)))
        (start (and info (memq target '(start both)) (> (cdr info) 0))))
    (cond ((and due start) altodo-calendar-priority)
          (due 'due)
          (start 'start))))

(defun altodo--day-filter-entry (date kind)
  "Return the sidebar filter entry for the tasks of DATE.
DATE is a list (MONTH DAY YEAR).  KIND is `due' or `start'."
  (let ((text (altodo--format-date-list date)))
    (list :title (format "%s %s" (altodo--date-key date) kind)
          :type 'search-simple
          :pattern (format "%s-date:%s" kind text))))

(defun altodo--calendar-selection-p (entry config source-buffer)
  "Return non-nil if the filter ENTRY is selected or active in the sidebar.
CONFIG is the sidebar configuration and SOURCE-BUFFER the altodo buffer."
  (ignore config source-buffer)
  (altodo-sidebar--entry-state entry))

(defun altodo--calendar-day-info (date counts target today-key config source-buffer)
  "Return the day information of DATE for `altodo-calendar-insert'.
COUNTS is the hash table of `altodo--collect-date-counts'.  TARGET is
`due', `start' or `both'.  TODAY-KEY is the key of today.  CONFIG is the
sidebar configuration and SOURCE-BUFFER the altodo buffer.  Only a day that
has tasks of the target kind is a button."
  (let* ((key (altodo--date-key date))
         (info (gethash key counts))
         (kind (altodo--day-kind info target)))
    (when kind
      (let* ((entry (altodo--day-filter-entry date kind))
             (selected (altodo--calendar-selection-p entry config source-buffer)))
        (list :faces
              (delq nil
                    (list (and selected 'altodo-calendar-selected-face)
                          (and (eq kind 'due) (string< key today-key)
                               'altodo-calendar-overdue-face)
                          (if (eq kind 'due)
                              (if (>= (car info) altodo-calendar-heavy-count)
                                  'altodo-calendar-due-heavy-face
                                'altodo-calendar-due-face)
                            'altodo-calendar-start-face)))
              :action #'altodo-sidebar--apply-filter
              :properties (list 'sidebar-entry entry)
              :help (format "%d due, %d start" (car info) (cdr info)))))))

(defun altodo-sidebar--insert-calendar (entry config source-buffer sidebar-window)
  "Insert the month calendar of the sidebar ENTRY (type `calendar').
CONFIG is the sidebar configuration, SOURCE-BUFFER the altodo buffer and
SIDEBAR-WINDOW the window of the sidebar or nil.  The calendar is drawn by
`altodo-calendar-insert'.  Days that have tasks are buttons that filter the
tasks of the day.  The entry accepts the properties `:count-done' and
`:calendar-target' (`due', `start' or `both', the default)."
  (let* ((indent-width (* (or (plist-get entry :nest) 0) (plist-get config :indent)))
         (indent (make-string indent-width ?\s))
         (target (or (plist-get entry :calendar-target) 'both))
         (counts (altodo--collect-date-counts source-buffer
                                              (plist-get entry :count-done)))
         (today (altodo--today-date-list))
         (today-key (altodo--date-key today))
         (shown (or altodo-sidebar--calendar-month
                    (cons (nth 0 today) (nth 2 today))))
         (title (plist-get entry :title)))
    (when (and title (not (string-empty-p title)))
      (insert indent (propertize title 'face 'altodo-sidebar-group-header-face
                                 'read-only t)
              "\n"))
    (if (and sidebar-window (< (window-body-width sidebar-window)
                               (+ indent-width (altodo-calendar-width))))
        (insert indent (propertize "(sidebar is too narrow for the calendar)"
                                   'face 'altodo-agenda-empty-face 'read-only t)
                "\n")
      (altodo-calendar-insert
       (car shown) (cdr shown)
       :indent indent-width
       :week-start altodo-week-start-day
       :today today
       :nav-function #'altodo-sidebar--calendar-move
       :day-function (lambda (date)
                       (altodo--calendar-day-info date counts target today-key
                                                  config source-buffer))))))

(defun altodo--agenda-setting (entry property default)
  "Return the PROPERTY of the sidebar ENTRY, or DEFAULT if it has none."
  (if (plist-member entry property)
      (plist-get entry property)
    default))

(defun altodo--agenda-weekday-name (weekday)
  "Return the name of WEEKDAY (0 is Sunday) for the agenda.
When `altodo-calendar-day-names' is changed from its default, use it, so
that the agenda and the calendar show the same names.  Otherwise use the
abbreviation of the language of Emacs, such as \"Tue\"."
  (if (equal altodo-calendar-day-names altodo-calendar-default-day-names)
      (aref calendar-day-abbrev-array weekday)
    (aref altodo-calendar-day-names weekday)))

(defun altodo--agenda-format-date (date format)
  "Return DATE, a list (MONTH DAY YEAR), as a string in FORMAT.
FORMAT is `altodo' (the format `altodo-date-format'), `done-tag' (the format
`altodo-done-tag-datetime-format') or a string for `format-time-string'."
  (format-time-string
   (pcase format
     ('altodo (or altodo-date-format "%Y-%m-%d"))
     ('done-tag (or altodo-done-tag-datetime-format "%Y-%m-%d"))
     ((pred stringp) format)
     (_ "%Y-%m-%d"))
   (encode-time (list 0 0 12 (nth 1 date) (nth 0 date) (nth 2 date) nil -1 nil))))

(defun altodo--pad-right (text width)
  "Return TEXT padded with spaces on the right to WIDTH display columns."
  (concat text (make-string (max 0 (- width (string-width text))) ?\s)))

(defun altodo-sidebar--insert-agenda (entry config source-buffer _sidebar-window)
  "Insert the agenda of the sidebar ENTRY (type `agenda').
The agenda has one line per day from today, with the numbers of the due (D)
and start (S) dates.  CONFIG is the sidebar configuration and SOURCE-BUFFER
the altodo buffer.  The entry accepts `:days' (default 7), `:count-done',
`:agenda-overdue' and `:calendar-target' (`due', `start' or `both', the
default).  By default a line with the overdue tasks is shown; a nil
`:agenda-overdue' hides it.  The display is set with the properties of the
entry: `:date-format' (`altodo', the default, follows `altodo-date-format';
`done-tag' follows `altodo-done-tag-datetime-format'; a string is an own
format for `format-time-string'), `:show-weekday' (default t),
`:today-label' (\"Today\"), `:tomorrow-label' (\"Tomorrow\"),
`:overdue-label' (\"Overdue\") and `:label-newline' (nil; non-nil puts a
label on a line of its own)."
  (let* ((indent-width (* (or (plist-get entry :nest) 0) (plist-get config :indent)))
         (indent (make-string indent-width ?\s))
         (target (or (plist-get entry :calendar-target) 'both))
         (days (or (plist-get entry :days) 7))
         (date-format (altodo--agenda-setting entry :date-format 'altodo))
         (show-weekday (altodo--agenda-setting entry :show-weekday t))
         (today-label (altodo--agenda-setting entry :today-label "Today"))
         (tomorrow-label (altodo--agenda-setting entry :tomorrow-label "Tomorrow"))
         (overdue-label (altodo--agenda-setting entry :overdue-label "Overdue"))
         (newline (altodo--agenda-setting entry :label-newline nil))
         (show-overdue (and (> (altodo--overdue-count
                                (altodo--collect-date-counts
                                 source-buffer (plist-get entry :count-done))
                                (altodo--date-key (altodo--today-date-list)))
                               0)
                            (not (and (plist-member entry :agenda-overdue)
                                      (null (plist-get entry :agenda-overdue))))
                            (memq target '(due both))))
         ;; The column of the labels, when they share a line with the date.
         (label-width (if newline
                          0
                        (apply #'max (mapcar #'string-width
                                             (append (list today-label
                                                           tomorrow-label)
                                                     (and show-overdue
                                                          (list overdue-label)))))))
         ;; A line under a label is indented.
         (detail-indent (if newline (concat indent "  ") indent))
         (counts (altodo--collect-date-counts source-buffer
                                              (plist-get entry :count-done)))
         (today (altodo--today-date-list))
         (today-key (altodo--date-key today))
         (today-absolute (calendar-absolute-from-gregorian today))
         (title (plist-get entry :title))
         (overdue (altodo--overdue-count counts today-key)))
    (when (and title (not (string-empty-p title)))
      (insert indent (propertize title 'face 'altodo-sidebar-group-header-face
                                 'read-only t)
              "\n"))
    (when (and (> overdue 0) (not (and (plist-member entry :agenda-overdue)
                                       (null (plist-get entry :agenda-overdue))))
               (memq target '(due both)))
      (let ((overdue-entry (list :title "Overdue" :type 'search-simple
                                 :pattern "due-date:overdue"))
            (face nil))
        (setq face (if (altodo--calendar-selection-p overdue-entry config
                                                     source-buffer)
                       'altodo-calendar-selected-face
                     'altodo-agenda-overdue-face))
        (when (and newline (not (string-empty-p overdue-label)))
          (insert indent (propertize overdue-label 'face face 'read-only t) "\n"))
        (insert detail-indent)
        (let ((start (point)))
          (insert (if newline
                      (number-to-string overdue)
                    (string-trim-right
                     (concat (altodo--pad-right overdue-label label-width)
                             (if (> label-width 0) " " "")
                             (number-to-string overdue)))))
          (make-text-button start (point)
                            'type 'button
                            'face face
                            'follow-link t
                            'action #'altodo-sidebar--apply-filter
                            'sidebar-entry overdue-entry
                            'help-echo nil
                            'mouse-face 'highlight))
        (insert "\n")))
    (dotimes (index days)
      (let* ((date (calendar-gregorian-from-absolute (+ today-absolute index)))
             (key (altodo--date-key date))
             (info (gethash key counts))
             (due (if (memq target '(due both)) (or (car info) 0) 0))
             (start (if (memq target '(start both)) (or (cdr info) 0) 0))
             (kind (altodo--day-kind info target))
             (label (pcase index (0 today-label) (1 tomorrow-label) (_ "")))
             (weekday (and show-weekday
                           (altodo--agenda-weekday-name
                            (calendar-day-of-week date))))
             (counts-text (string-join
                           (delq nil (list (and (> due 0) (format "D%d" due))
                                           (and (> start 0) (format "S%d" start))))
                           " "))
             (date-text (string-join
                         (delq nil (list (altodo--agenda-format-date date date-format)
                                         weekday
                                         (and (not (string-empty-p counts-text))
                                              counts-text)))
                         " "))
             (text (if newline
                       date-text
                     (string-trim-right
                      (concat (altodo--pad-right label label-width)
                              (if (> label-width 0) " " "")
                              date-text))))
             (day-entry (and kind (altodo--day-filter-entry date kind)))
             (face (cond ((and day-entry
                               (altodo--calendar-selection-p day-entry config
                                                             source-buffer))
                          'altodo-calendar-selected-face)
                         ((null kind) 'altodo-agenda-empty-face)
                         ((= index 0) 'altodo-agenda-today-face)
                         (t 'altodo-agenda-date-face))))
        (when (and newline (not (string-empty-p label)))
          (insert indent (propertize label 'face face 'read-only t) "\n"))
        (insert detail-indent)
        (if (null kind)
            (insert (propertize text 'face face 'read-only t))
          (let ((button-start (point)))
            (insert text)
            (make-text-button button-start (point)
                              'type 'button
                              'face face
                              'follow-link t
                              'action #'altodo-sidebar--apply-filter
                              'sidebar-entry day-entry
                              'help-echo nil
                              'mouse-face 'highlight)
            (when (> (length counts-text) 0)
              (add-face-text-property (- (point) (length counts-text)) (point)
                                      'altodo-agenda-count-face))))
        (insert "\n")))))

(defun altodo-sidebar--calendar-move (delta)
  "Change the month of the sidebar calendar by DELTA; 0 is this month."
  (let ((buffer (altodo--get-sidebar-buffer)))
    (when buffer
      (with-current-buffer buffer
        (setq altodo-sidebar--calendar-month
              (if (zerop delta)
                  nil
                (let* ((today (altodo--today-date-list))
                       (shown (or altodo-sidebar--calendar-month
                                  (cons (nth 0 today) (nth 2 today))))
                       (total (+ (* 12 (cdr shown)) (1- (car shown)) delta)))
                  (cons (1+ (mod total 12)) (/ total 12)))))))
    (altodo-sidebar-refresh)))

(defun altodo-sidebar-calendar-next ()
  "Show the next month in the sidebar calendar."
  (interactive)
  (altodo-sidebar--calendar-move 1))

(defun altodo-sidebar-calendar-previous ()
  "Show the previous month in the sidebar calendar."
  (interactive)
  (altodo-sidebar--calendar-move -1))

(defun altodo-sidebar-calendar-today ()
  "Show this month in the sidebar calendar."
  (interactive)
  (altodo-sidebar--calendar-move 0))

(defun altodo-sidebar--render (buffer config)
  "Render entries in BUFFER based on CONFIG.
Clears BUFFER and inserts all entries from CONFIG.
Uses the source buffer (altodo main buffer) for counting."
  (let ((source-buffer (plist-get config :source-buffer))
        (sidebar-window (get-buffer-window buffer)))
    ;; The state is buffer-local: read it in BUFFER, whichever buffer is
    ;; current.
    (with-current-buffer buffer
      (let ((inhibit-read-only t)
            ;; A count is computed once for each entry in a drawing.
            (altodo--count-cache (make-hash-table :test 'eq))
            ;; The saved combined predicate is used as it is.
            (combined-predicate
             (when (and altodo-sidebar-dynamic-count-enabled
                        (eq altodo-sidebar--selection-mode 'multiple))
               altodo-sidebar--current-combined-predicate))
            (combine-mode altodo-sidebar--combine-mode))
        (altodo--release-heading-markers)
        (erase-buffer)
        (unless (and source-buffer (buffer-live-p source-buffer))
          (setq altodo-sidebar--current-combined-predicate nil
                combined-predicate nil))
        (dolist (entry (plist-get config :entries))
          (cond
           ((eq (plist-get entry :type) 'calendar)
            (altodo-sidebar--insert-calendar entry config source-buffer sidebar-window))
           ((eq (plist-get entry :type) 'agenda)
            (altodo-sidebar--insert-agenda entry config source-buffer sidebar-window))
           ((or (eq (plist-get entry :type) 'dynamic)
                (equal (plist-get entry :type) "dynamic"))
            (dolist (expanded (altodo--expand-dynamic-filter entry source-buffer combined-predicate))
              (altodo-sidebar--insert-entry expanded config source-buffer sidebar-window combined-predicate combine-mode)))
           (t
            (altodo-sidebar--insert-entry entry config source-buffer sidebar-window combined-predicate combine-mode))))
        ;; Each entry ends with a newline; drop the last one so that the
        ;; sidebar does not end with an empty line.
        (goto-char (point-max))
        (when (and (> (point-max) (point-min)) (eq (char-before) ?\n))
          (delete-char -1))))))

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
Returns the separator string or just TITLE if it doesn\\='t fit."
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
  "Create a separator line for SIDEBAR-WINDOW with proper width calculation.
The line is INDENT columns indented and has the TITLE and PATTERN.
Returns the full separator line string."
  (let* ((window-width (if sidebar-window
                          (window-body-width sidebar-window)
                          (window-body-width (selected-window))))
         (available-width (max 1 (- window-width (string-width indent))))
         (separator-text (altodo--make-separator-with-title title pattern available-width)))
    (concat indent separator-text)))

(defun altodo-sidebar--insert-entry (entry config &optional source-buffer sidebar-window combined-predicate combine-mode)
  "Insert ENTRY into sidebar buffer based on CONFIG.
Creates a clickable button with appropriate indentation and face.
SOURCE-BUFFER is the main altodo buffer for counting matches.
SIDEBAR-WINDOW is the sidebar window for width calculation.
COMBINED-PREDICATE is the combined predicate for dynamic count calculation.
COMBINE-MODE is \\='and or \\='or, used to determine whether to apply
combined-predicate.
The row has the face of `altodo-sidebar--get-face'.  A selected or active
entry has that face on the whole row.  Otherwise the face is added only
where the title has no face of its own, such as the number of `%n'."
  (let* ((state (altodo-sidebar--entry-state entry))
         (title (altodo--format-sidebar-title entry source-buffer
                                              combined-predicate combine-mode))
         (type (plist-get entry :type))
         (nest (or (plist-get entry :nest) 0))
         (action (and (not (member type '(separator group-header comment nil)))
                      (or (plist-get entry :action)
                          #'altodo-sidebar--apply-filter)))
         (indent (make-string (* nest (plist-get config :indent)) ?\s))
         (face (altodo-sidebar--get-face entry config source-buffer
                                         combined-predicate combine-mode)))
    (if (eq type 'separator)
        ;; Fill the line with the repeated pattern, with the title if any.
        (insert (propertize (altodo--make-separator-line
                             sidebar-window indent title
                             (or (plist-get entry :pattern) "─"))
                            'face face 'read-only t))
      (insert (propertize indent 'face face))
      (let ((start (point)))
        (insert (if state (substring-no-properties title) title))
        (altodo--apply-face-to-unfaced-text start (point) face)
        (if action
            (make-text-button start (point)
                              'type 'button
                              'follow-link t
                              'action action
                              'sidebar-entry entry
                              'sidebar-config config
                              'help-echo nil
                              'mouse-face 'highlight)
          (put-text-property (line-beginning-position) (point) 'read-only t))))
    (insert "\n")))

(defun altodo-sidebar--make-display-action (config)
  "Create display action from CONFIG.
Returns display action (function . alist) per GNU Emacs manual."
  `(display-buffer-in-side-window
    . ((side . ,(plist-get config :position))
       (slot . 0)
       (dedicated . side))))

(defun altodo-sidebar--setup-buffer (buffer config)
  "Setup BUFFER for sidebar display using CONFIG.
Enables `altodo-sidebar-mode', sets read-only, and configures mode-line."
  (ignore config)
  (with-current-buffer buffer
    (altodo-sidebar-mode)
    (setq buffer-read-only t)
    ;; Setup sidebar-specific mode-line (must be after the mode)
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
      (setq-local display-line-numbers nil))))

(defvar altodo-sidebar-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") 'altodo-sidebar--apply-filter-at-point)
    (define-key map (kbd "SPC") 'altodo-sidebar--apply-filter-at-point)
    (define-key map (kbd "c") 'altodo-filter-clear)
    (define-key map (kbd "r") 'altodo-sidebar-refresh)
    (define-key map (kbd "q") 'altodo-sidebar-hide)
    (define-key map (kbd "n") 'next-line)
    (define-key map (kbd "p") 'previous-line)
    ;; Multiple filter selection keybindings
    (define-key map (kbd "s") 'altodo-sidebar-toggle-selection)
    (define-key map (kbd "C-c C-a") 'altodo-sidebar-set-and-mode)
    (define-key map (kbd "C-c C-o") 'altodo-sidebar-set-or-mode)
    (define-key map (kbd "C-c C-t") 'altodo-sidebar-toggle-combine-mode)
    (define-key map (kbd "C-<mouse-1>") 'altodo-sidebar-mouse-toggle-selection)
    (define-key map (kbd "}") 'altodo-sidebar-calendar-next)
    (define-key map (kbd "{") 'altodo-sidebar-calendar-previous)
    (define-key map (kbd ".") 'altodo-sidebar-calendar-today)
    (define-key map (kbd "?") 'altodo-sidebar-help)
    (define-key map (kbd "h") 'altodo-sidebar-help)
    map)
  "Keymap for altodo sidebar.")

(define-derived-mode altodo-sidebar-mode special-mode "altodo-sidebar"
  "Major mode of the altodo sidebar buffer.
The buffer is read-only and lists the filters, the calendar and the agenda
of an altodo buffer.  Select an entry with \\[altodo-sidebar--apply-filter-at-point].

\\{altodo-sidebar-mode-map}"
  :group 'altodo)

(defun altodo-sidebar-help ()
  "Show the key bindings of the altodo sidebar in a help window."
  (interactive)
  (with-help-window "*altodo-sidebar-help*"
    (princ "altodo sidebar\n\n")
    (princ (concat "Select a filter with RET or SPC.  Select several filters with s\n"
                   "and combine them with AND (C-c C-a) or OR (C-c C-o);\n"
                   "C-c C-t toggles AND/OR.  Clear the filter with c.\n\n"))
    (princ (substitute-command-keys "\\{altodo-sidebar-mode-map}"))))

(defun altodo-sidebar--apply-filter-at-point ()
  "Apply filter at point in sidebar."
  (interactive)
  (let ((button (button-at (point))))
    (if button
        (let ((inhibit-read-only t))
          (if (button-get button 'sidebar-entry)
              (altodo-sidebar--apply-filter button)
            ;; A button of another kind, such as a month button.
            (button-activate button)))
      (message "No filter at point"))))

(defun altodo-sidebar--get-face (entry config &optional source-buffer combined-predicate combine-mode)
  "Return the face of the row of the filter ENTRY.
The current buffer is the sidebar.  CONFIG is not used.  SOURCE-BUFFER is
the altodo buffer, in which the count for `:face-rules' is taken.
COMBINED-PREDICATE and COMBINE-MODE make that count the same as the count in
the title (see `altodo--get-entry-count').
The first of these decides, from the highest priority:
1. `altodo-sidebar-selected-filter-face' or
   `altodo-sidebar-active-filter-face', see `altodo-sidebar--entry-state'
2. the first matching rule of `:face-rules', when `:count-format' is not nil
3. `:face'
4. the default face of the type, see `altodo-sidebar--default-face'
`:count-face-rules' and `:face-count' do not change the row; see
`altodo--count-face'."
  (ignore config)
  (pcase (altodo-sidebar--entry-state entry)
    ('selected 'altodo-sidebar-selected-filter-face)
    ('active 'altodo-sidebar-active-filter-face)
    (_
     (or (when (and (plist-get entry :face-rules)
                    (altodo--count-format-p entry))
           (altodo-sidebar--resolve-face
            (altodo--evaluate-face-rules
             (plist-get entry :face-rules)
             (altodo--get-entry-count entry source-buffer
                                      combined-predicate combine-mode))))
         (altodo-sidebar--resolve-face (plist-get entry :face))
         (altodo-sidebar--default-face (plist-get entry :type)
                                       (plist-get entry :nest))))))

(defun altodo-sidebar--resolve-face (face-spec)
  "Return FACE-SPEC as a value of the `face' text property, or nil.
FACE-SPEC can be:
- a face name, such as \\='bold
- a list of face names, such as \\='(bold error)
- a plist of face attributes, such as \\='(:foreground \"red\")
- a defface-style spec, such as \\='((t (:foreground \"red\"))); only
  its clause for all displays (the one with t) is used
Anything else, such as an odd plist, is invalid and gives nil."
  (cond
   ((null face-spec) nil)
   ((keywordp face-spec) nil)
   ((symbolp face-spec) face-spec)
   ((not (proper-list-p face-spec)) nil)
   ;; Plist of attributes.
   ((keywordp (car face-spec))
    (and (cl-evenp (length face-spec)) face-spec))
   ;; defface-style: the attributes of the `t' clause.
   ((consp (car face-spec))
    (let ((attributes (cadr (assq t face-spec))))
      (and (keywordp (car-safe attributes))
           (cl-evenp (length attributes))
           attributes)))
   ;; List of face names.
   ((cl-every (lambda (face) (and face (symbolp face) (not (keywordp face))))
              face-spec)
    face-spec)))

(defun altodo-sidebar--default-face (type nest)
  "Get default face for TYPE and NEST level.
Returns appropriate face based on entry type."
  (ignore nest)
  (cond
   ((eq type 'group-header) 'altodo-sidebar-group-header-face)
   ((memq type '(search-simple heading-jump)) 'altodo-sidebar-search-simple-face)
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

(defcustom altodo-locals-code-policy 'deny
  "How to treat code written in .altodo-locals.el.
The code is the `lambda' of a `search-lambda' entry, `:count-pattern-lambda',
and a `:command' other than the commands of this package.
`deny'    Never run it.  Selecting such an entry shows a message.
`confirm' Run it only when the SHA-256 of the file is in
          `altodo-trusted-locals'.  Selecting such an entry asks for trust.
`allow'   Always run it.
Allow it only for files that you trust."
  :group 'altodo
  :type '(choice (const :tag "Never run" deny)
                 (const :tag "Run after confirming the file" confirm)
                 (const :tag "Always run" allow)))

(defcustom altodo-trusted-locals nil
  "Alist of (FILE . SHA256) of .altodo-locals.el files trusted by the user.
Used when `altodo-locals-code-policy' is `confirm'.  FILE is an absolute path.
The trust ends when the content of the file changes."
  :group 'altodo
  :type '(alist :key-type file :value-type string))

(defun altodo--entry-has-code-p (entry)
  "Return non-nil if the sidebar ENTRY has code written by the user.
A `:command' that names a command of this package is not user code."
  (let ((command (plist-get entry :command)))
    (or (eq (plist-get entry :type) 'search-lambda)
        (plist-get entry :count-pattern-lambda)
        (and command
             (not (and (symbolp command)
                       (string-prefix-p "altodo-" (symbol-name command))
                       (commandp command)))))))

(defun altodo--locals-file-hash (file)
  "Return the SHA-256 of the content of FILE, or nil if FILE is unreadable."
  (when (file-readable-p file)
    (with-temp-buffer
      (set-buffer-multibyte nil)
      (insert-file-contents-literally file)
      (secure-hash 'sha256 (current-buffer)))))

(defun altodo--locals-file-trusted-p (file ask)
  "Return non-nil if FILE is trusted under the `confirm' policy.
When ASK is non-nil and FILE is not trusted, ask the user, and save the
SHA-256 of FILE to `altodo-trusted-locals' if the user trusts it."
  (let ((hash (altodo--locals-file-hash file)))
    (cond
     ((null hash) nil)
     ((equal (cdr (assoc file altodo-trusted-locals)) hash) t)
     ((and ask
           (y-or-n-p (format "Run the code in %s (SHA-256 %s)? "
                             file (substring hash 0 12))))
      (customize-save-variable
       'altodo-trusted-locals
       (cons (cons file hash)
             (cl-remove file altodo-trusted-locals :key #'car :test #'equal)))
      t))))

(defun altodo--entry-code-permitted-p (entry &optional ask)
  "Return non-nil if the code of the sidebar ENTRY may run.
An ENTRY without `:locals-code' (not from .altodo-locals.el) is permitted.
Otherwise `altodo-locals-code-policy' decides.  When ASK is non-nil, tell the
user why the code does not run, or ask for trust under the `confirm' policy."
  (let ((file (plist-get entry :locals-code)))
    (cond
     ((null file) t)
     ((eq altodo-locals-code-policy 'allow) t)
     ((and (eq altodo-locals-code-policy 'confirm)
           (altodo--locals-file-trusted-p file ask)))
     (t (when ask
          (message "The code in %s does not run (altodo-locals-code-policy: %s)"
                   file altodo-locals-code-policy))
        nil))))

(defvar altodo--locals-warnings nil
  "Alist ((FILE . MESSAGE) . MODIFICATION-TIME) of the warnings already shown.")

(defun altodo--warn-locals-once (file message)
  "Warn about MESSAGE for the locals FILE once per modification of FILE.
The settings are read each time the sidebar is drawn, so the same problem
would otherwise be reported at every redraw."
  (let* ((key (cons file message))
         (stamp (file-attribute-modification-time (file-attributes file)))
         (shown (assoc key altodo--locals-warnings)))
    (unless (and shown (equal (cdr shown) stamp))
      (setq altodo--locals-warnings
            (cons (cons key stamp)
                  (assoc-delete-all key altodo--locals-warnings)))
      (display-warning 'altodo (format "%s: %s" file message) :warning))))

(defvar altodo--locals-cache nil
  "Alist (FILE STAMP . DATA) of the .altodo-locals.el files read.
STAMP identifies the state of the file, so a changed file is read again.")

(defun altodo--locals-file-stamp (file)
  "Return the modification time, size and inode of FILE."
  (let ((attributes (file-attributes file)))
    (list (file-attribute-modification-time attributes)
          (file-attribute-size attributes)
          (file-attribute-inode-number attributes))))

(defun altodo--load-locals-file ()
  "Load .altodo-locals.el from the same directory as the current buffer.
Returns alist with configuration, or nil if the file is not found, cannot be
read, or is not an alist (a warning is shown once for the last two).
The sidebar asks for the settings at each drawing, so the content is kept
until the file changes."
  (when buffer-file-name
    (let* ((locals-file (expand-file-name ".altodo-locals.el"
                                          (file-name-directory buffer-file-name)))
           (stamp (and (file-exists-p locals-file)
                       (altodo--locals-file-stamp locals-file)))
           (cached (assoc locals-file altodo--locals-cache)))
      (cond
       ((null stamp) nil)
       ((and cached (equal (cadr cached) stamp)) (cddr cached))
       (t (let ((data (altodo--read-locals-file locals-file)))
            (setq altodo--locals-cache
                  (cons (cons locals-file (cons stamp data))
                        (assoc-delete-all locals-file altodo--locals-cache)))
            data))))))

(defun altodo--read-locals-file (locals-file)
  "Read LOCALS-FILE and return its alist, or nil with a warning."
  (condition-case err
      (let ((data (with-temp-buffer
                    (insert-file-contents locals-file)
                    ;; `#.' would run code before the policy applies.
                    (let ((read-eval nil))
                      (read (current-buffer))))))
        (if (and (proper-list-p data)
                 (cl-every (lambda (item)
                             (and (consp item) (symbolp (car item))))
                           data))
            data
          (altodo--warn-locals-once
           locals-file "ignored: the content must be an alist")
          nil))
    (error
     (altodo--warn-locals-once
      locals-file
      (format "cannot read: %s" (error-message-string err)))
     nil)))

(defun altodo--valid-filter-entry-p (entry)
  "Return non-nil if ENTRY is a plist with a string :title and a symbol :type."
  (and (proper-list-p entry)
       (keywordp (car entry))
       (stringp (plist-get entry :title))
       (symbolp (plist-get entry :type))))

(defun altodo--get-filter-patterns ()
  "Get filter patterns from .altodo-locals.el.
Returns list of pattern plists or nil if not found.  An entry that is not a
plist with a string :title is ignored, with a warning shown once."
  (let* ((file (expand-file-name ".altodo-locals.el"
                                 (file-name-directory (or buffer-file-name
                                                          default-directory))))
         (patterns (cdr (assq 'altodo-filter-patterns
                              (altodo--load-locals-file))))
         (valid (and (proper-list-p patterns)
                     (seq-filter #'altodo--valid-filter-entry-p patterns))))
    (when (and patterns
               (or (not (proper-list-p patterns))
                   (/= (length valid) (length patterns))))
      (altodo--warn-locals-once
       file
       (format "ignored %d invalid entries of altodo-filter-patterns (an entry must be a plist with a string :title)"
               (if (proper-list-p patterns)
                   (- (length patterns) (length valid))
                 1))))
    (mapcar (lambda (entry)
              (if (altodo--entry-has-code-p entry)
                  (append entry (list :locals-code file))
                entry))
            valid)))

(defun altodo--get-locals-value (key)
  "Get value for KEY from .altodo-locals.el.
Returns value or nil if not found."
  (let ((locals (altodo--load-locals-file)))
    (cdr (assq key locals))))

(defun altodo--heading-level ()
  "Get heading level of current line.
Returns integer (1, 2, 3, ...) if current line is a heading, nil otherwise.
Supports both ATX (# ## ###) and Setext (=== or ---) syntax."
  (save-excursion
    (beginning-of-line)
    ;; Check ATX syntax
    (if (looking-at "^\\(#+\\)[ \t]+")
        (length (match-string 1))
      ;; Check Setext syntax (next line).  `forward-line' returns 0 only
      ;; when there is a next line, so no line counting is needed.
      (when (and (zerop (forward-line 1))
                 (looking-at "^\\(=+\\|-+\\)[ \t]*$"))
        (if (looking-at "^=+")
            1
          2)))))

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
      (when (and (zerop (forward-line 1))
                 (looking-at "^\\(=+\\|-+\\)[ \t]*$"))
        (forward-line -1)
        (beginning-of-line)
        (when (looking-at "^\\(.+\\)$")
          (match-string 1))))))

(defun altodo--compute-all-heading-ranges ()
  "Compute all heading ranges in buffer and cache them.
Returns alist of (heading-text . (start . end)), in buffer order.
The range of an ATX heading starts at the line after the heading and
ends before the next heading of the same or a higher level, or at the end
of the buffer.  The buffer is scanned once."
  (let ((entries nil)
        (open nil))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (let ((level (altodo--heading-level)))
          (when level
            (let ((line-start (line-beginning-position)))
              ;; This heading ends the open headings of the same or a
              ;; deeper level.
              (while (and open (<= level (car (car open))))
                (setcdr (cdr (cdr (pop open))) line-start))
              (when (looking-at "^#+[ \t]+\\(.+\\)$")
                (let ((entry (cons (match-string-no-properties 1)
                                   (cons (line-beginning-position 2) nil))))
                  (push entry entries)
                  (push (cons level entry) open))))))
        (forward-line 1))
      (dolist (item open)
        (setcdr (cdr (cdr item)) (point-max))))
    (setq altodo--heading-cache-tick (buffer-chars-modified-tick)
          altodo--heading-range-table (make-hash-table :test 'equal))
    (setq altodo--heading-cache (nreverse entries))))

(defun altodo--find-heading-range (heading-regexp &optional include-children)
  "Find range of lines under heading matching HEADING-REGEXP.
INCLUDE-CHILDREN: if t, include child headings; if nil, exclude them.
Returns (start . end) where start is line after heading, end is before next
same-level heading.
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
HEADING-REGEXP: regexp searched in the text of each heading; the lines
under every heading with a match, including its child headings, are in range
INCLUDE-CHILDREN: ignored, child headings are always included
HEADINGS-OPTION: \\='all, \\='all-without-heading-line, \\='only-tasks,
\\='only-tasks-without-heading-line (default: \\='only-tasks)
Returns t if line should be displayed, nil otherwise."
  (ignore include-children)
  (let ((position (point))
        (headings-option (or headings-option 'only-tasks)))
    (when (seq-some (lambda (range)
                      (and (>= position (car range))
                           (< position (cdr range))))
                    (altodo--heading-ranges-matching heading-regexp))
      (let ((is-heading (altodo--heading-level))
            (is-line-with-content (or (altodo--task-p)
                                      (altodo--comment-p)
                                      (altodo--multiline-comment-p))))
        (pcase headings-option
          ('all t)
          ('all-without-heading-line (not is-heading))
          ((or 'only-tasks 'only-tasks-without-heading-line)
           (and is-line-with-content (not is-heading)))
          (_ nil))))))

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
Returns t if current task/comment line has multiline comments containing
REGEXP, nil otherwise."
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
Returns the text after the task bracket (e.g., \\='[ ]\\=' or \\='[x]\\=').
Returns nil if current line is not a task line.
Returns plain text without any face properties."
  (when (altodo--task-p)
    (save-excursion
      (beginning-of-line)
      (when (re-search-forward "^[ ]*\\[[^]]*\\][ ]*\\(.*\\)$" (line-end-position) t)
        (substring-no-properties (match-string 1))))))

(defconst altodo--person-in-body-regex
  "\\(?:^\\|[[:space:]]\\)@\\([^[:space:]]+\\)"
  "Regexp for @person in a task body; group 1 is the name.
The @ must be at the beginning or after a space.")

(defun altodo--line-extract-person-value ()
  "Extract @person from current line\\='s task body.
Returns person name or nil if not found.
Only searches in task body (after the task bracket).
Supports ASCII and multi-byte characters (Japanese, etc).
Returns plain text without any face properties."
  (let ((body (altodo--line-task-body)))
    (when body
      (when (string-match altodo--person-in-body-regex body)
        (let ((person (match-string 1 body)))
          ;; Exclude @ followed by ] or [
          (unless (or (string-match "^\\]" person)
                      (string-match "^\\[" person))
            ;; Return plain text without face properties
            (substring-no-properties person)))))))

(defun altodo--line-extract-all-tags (tag-mode)
  "Extract all tags from current line based on TAG-MODE.
TAG-MODE: \"all\" (both), \"name-only\" (names only), \"with-value\" (value
tags only).
Returns list of tag strings (without #).
Uses `altodo-tag-with-value-regex' and `altodo-tag-without-value-regex'."
  (let ((tags nil)
        (with-value-names nil))
    (save-excursion
      (beginning-of-line)
      ;; 値付きタグを抽出
      (while (re-search-forward altodo-tag-with-value-regex (line-end-position) t)
        (let ((name (substring (substring-no-properties (match-string 1)) 1))
              (value (substring-no-properties (match-string 2))))
          (when (and (string-prefix-p "\"" value) (string-suffix-p "\"" value))
            (setq value (substring value 1 -1)))
          (push name with-value-names)
          (cond
           ((equal tag-mode "name-only")
            (push name tags))
           ((member tag-mode '("all" "with-value"))
            (push (concat name ":" value) tags)))))
      ;; 値なしタグを抽出（with-value モード以外）
      (unless (equal tag-mode "with-value")
        (beginning-of-line)
        (while (re-search-forward altodo-tag-without-value-regex (line-end-position) t)
          (let ((name (substring (substring-no-properties (match-string 1)) 1)))
            (unless (member name with-value-names)
              (push name tags))))))
    (nreverse tags)))

(defun altodo--line-extract-all-persons ()
  "Extract all @person tags from current line\\='s task body.
Returns list of person name strings (without @)."
  (let ((body (altodo--line-task-body))
        (persons nil))
    (when body
      (let ((start 0))
        (while (string-match altodo--person-in-body-regex body start)
          (let ((person (match-string 1 body)))
            (unless (or (string-match "^\\]" person)
                        (string-match "^\\[" person))
              (push (substring-no-properties person) persons)))
          (setq start (match-end 0)))))
    (nreverse persons)))

(defun altodo--collect-dynamic-values (dynamic-type source-buffer &optional tag-mode)
  "Collect values of DYNAMIC-TYPE from SOURCE-BUFFER.
TAG-MODE: \"all\", \"name-only\" (default), \"with-value\".
Returns alist of (value . count)."
  (altodo--collect-dynamic-values-with-exclude dynamic-type source-buffer tag-mode nil nil nil))

(defun altodo--should-exclude-value (value dynamic-type exclude-person exclude-tag exclude-tag-value)
  "Check if VALUE should be excluded based on DYNAMIC-TYPE.
The lists EXCLUDE-PERSON, EXCLUDE-TAG and EXCLUDE-TAG-VALUE are the exclusions.
Return t if value should be excluded, nil otherwise."
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

(defun altodo--extract-dynamic-values (dynamic-type &optional tag-mode)
  "Extract values of DYNAMIC-TYPE from current line.
TAG-MODE: \"all\", \"name-only\" (default), \"with-value\".
Returns list of value strings."
  (cond
   ((equal dynamic-type "person")
    (altodo--line-extract-all-persons))
   ((equal dynamic-type "tag")
    (altodo--line-extract-all-tags (or tag-mode "name-only")))
   ((equal dynamic-type "due")
    (let ((v (altodo--line-extract-tag-value "due")))
      (when v (list v))))
   ((equal dynamic-type "start")
    (let ((v (altodo--line-extract-tag-value "start")))
      (when v (list v))))))

(defun altodo--collect-dynamic-values-with-exclude (dynamic-type source-buffer &optional tag-mode exclude-person exclude-tag exclude-tag-value predicate)
  "Collect values of DYNAMIC-TYPE from SOURCE-BUFFER with exclusions.
TAG-MODE: \"all\", \"name-only\" (default), \"with-value\".
EXCLUDE-PERSON, EXCLUDE-TAG, EXCLUDE-TAG-VALUE are lists of patterns to exclude.
PREDICATE is an optional predicate function to filter lines (called at line
beginning).
Returns alist of (value . count)."
  (with-current-buffer source-buffer
    (let ((values (make-hash-table :test 'equal)))
      (save-excursion
        (goto-char (point-min))
        (while (not (eobp))
          (when (and (altodo--task-p)
                     (or (not predicate) (funcall predicate)))
            (dolist (value (altodo--extract-dynamic-values dynamic-type tag-mode))
              (when (not (altodo--should-exclude-value value dynamic-type
                                                      exclude-person exclude-tag exclude-tag-value))
                (puthash value (1+ (gethash value values 0)) values))))
          (forward-line 1)))
      (let ((result nil))
        (maphash (lambda (k v) (push (cons k v) result)) values)
        result))))

(defun altodo--sort-dynamic-values (alist sort-by)
  "Sort ALIST by SORT-BY.\n\"alpha\" for alphabetical, \"count\" for count descending."
  (sort alist
        (if (equal sort-by "count")
            (lambda (a b) (> (cdr a) (cdr b)))
          (lambda (a b) (string< (car a) (car b))))))

(defun altodo--limit-dynamic-values (alist limit)
  "Limit ALIST to LIMIT rows.  If LIMIT is nil or 0, return all."
  (if (and (integerp limit) (> limit 0))
      (cl-subseq alist 0 (min limit (length alist)))
    alist))

(defun altodo--collect-headings (count-open)
  "Return the headings of the current buffer in buffer order.
Each element is a list (TEXT LEVEL POSITION OPEN-COUNT).  ATX and Setext
headings are collected; lines in a fenced code block are skipped.
When COUNT-OPEN is non-nil, OPEN-COUNT is the number of tasks that are
neither done nor cancelled, from the heading to the next heading of any
level.  Otherwise it is 0."
  (save-excursion
    (save-restriction
      (widen)
      (goto-char (point-min))
      (let ((headings nil)
            (in-fence nil))
        (while (not (eobp))
          (cond
           ((looking-at "^ \\{0,3\\}\\(?:```\\|~~~\\)")
            (setq in-fence (not in-fence)))
           (in-fence)
           ((looking-at "^\\(#+\\)[ \t]+\\(.+\\)$")
            (push (list (match-string-no-properties 2)
                        (length (match-string 1))
                        (line-beginning-position)
                        0)
                  headings))
           ((and count-open headings (looking-at altodo-task-regex))
            (unless (member (match-string 2) (list altodo-state-done
                                                   altodo-state-cancelled))
              (cl-incf (nth 3 (car headings)))))
           ;; Setext heading: a text line followed by "===" or "---".
           ((and (looking-at "^[^ \t\n]")
                 (memq (char-after (1+ (line-end-position))) '(?= ?-))
                 (not (looking-at altodo-comment-regex))
                 (save-excursion
                   (forward-line 1)
                   (looking-at "^\\(=+\\|-+\\)[ \t]*$")))
            (push (list (buffer-substring-no-properties
                         (line-beginning-position) (line-end-position))
                        (save-excursion
                          (forward-line 1)
                          (if (eq (char-after) ?=) 1 2))
                        (line-beginning-position)
                        0)
                  headings)
            (forward-line 1)))
          (forward-line 1))
        (nreverse headings)))))

(defun altodo--heading-indent-offset (level indent-by-level)
  "Return the number of extra indent levels of a heading of LEVEL.
INDENT-BY-LEVEL is nil (no extra indent), t (indent from level 2), or an
integer N: the headings up to level N are not indented and a deeper
heading is indented by LEVEL minus N steps.  An integer below 1 is
treated like t."
  (cond
   ((null indent-by-level) 0)
   (t (max 0 (- level (if (integerp indent-by-level)
                          (max 1 indent-by-level)
                        1))))))

(defvar-local altodo--heading-markers nil
  "Markers made for the `heading-jump' entries of the last drawing.
The sidebar releases them before it draws again, because a marker of a
buffer is updated at each edit until it is released or collected.")

(defun altodo--release-heading-markers ()
  "Release the markers in `altodo--heading-markers'."
  (mapc (lambda (marker) (set-marker marker nil)) altodo--heading-markers)
  (setq altodo--heading-markers nil))

(defun altodo--inherited-properties (entry excluded)
  "Return the properties of the dynamic ENTRY as a plist, except EXCLUDED.
The expanded entries take them over, so that :face-rules, :display-context
and the like work as they do for an entry that is not dynamic."
  (let (result)
    (cl-loop for (key value) on entry by #'cddr
             unless (memq key excluded)
             do (setq result (nconc result (list key value))))
    result))

(defconst altodo--dynamic-own-properties
  '(:title :type :pattern :nest :count-format :action :command :marker
    :count-pattern-simple :count-pattern-lambda :dynamic-type
    :tag-mode :tag-ignore-value :sort-by :sort :limit :level :indent-by-level
    :exclude-person :exclude-tag :exclude-tag-value)
  "Properties of a dynamic entry that its expanded entries do not take over.")

(defun altodo--expand-heading-filter (entry source-buffer)
  "Expand the heading filter ENTRY to `heading-jump' entries.
The headings are taken from SOURCE-BUFFER in buffer order.  The count of
`%n' (tasks neither done nor cancelled) is computed only when :title
contains `%n' and :count-format is not nil."
  (when (buffer-live-p source-buffer)
    (let* ((title (plist-get entry :title))
           (levels (let ((value (plist-get entry :level)))
                     (if (listp value) value (list value))))
           (limit (plist-get entry :limit))
           (count-p (and (altodo--count-format-p entry)
                         (or (string-match-p "%n" title)
                             (plist-get entry :face-rules)
                             (plist-get entry :count-face-rules))))
           (inherited (altodo--inherited-properties
                       entry (cons :face-count altodo--dynamic-own-properties)))
           (indent-by-level (if (plist-member entry :indent-by-level)
                                (plist-get entry :indent-by-level)
                              t))
           (nest (or (plist-get entry :nest) 0))
           (headings (with-current-buffer source-buffer
                       (altodo--collect-headings count-p))))
      (when levels
        (setq headings (seq-filter (lambda (heading)
                                     (memq (nth 1 heading) levels))
                                   headings)))
      (when (and (integerp limit) (> limit 0))
        (setq headings (seq-take headings limit)))
      (mapcar
       (lambda (heading)
         (pcase-let ((`(,text ,level ,position ,open-count) heading))
           `(:title ,(replace-regexp-in-string
                      "%[snl]"
                      (lambda (placeholder)
                        (pcase (aref placeholder 1)
                          (?s text)
                          (?l (number-to-string level))
                          (_ (if (not count-p)
                                 placeholder
                               (let ((count-face
                                      (altodo--count-face entry open-count))
                                     (count-text (number-to-string open-count)))
                                 (if count-face
                                     (propertize count-text 'face count-face)
                                   count-text))))))
                      title t t)
             :type heading-jump
             :nest ,(+ nest (altodo--heading-indent-offset level indent-by-level))
             :marker ,(let ((marker (set-marker (make-marker) position
                                                source-buffer)))
                        (push marker altodo--heading-markers)
                        marker)
             ,@(when count-p `(:count-format t :count-value ,open-count))
             ,@inherited)))
       headings))))

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
  (if (equal (plist-get entry :dynamic-type) "heading")
      (altodo--expand-heading-filter entry source-buffer)
    (altodo--expand-value-filter entry source-buffer combined-predicate)))

(defun altodo--expand-value-filter (entry source-buffer &optional combined-predicate)
  "Expand the dynamic filter ENTRY that collects values to filter entries.
SOURCE-BUFFER and COMBINED-PREDICATE are as in `altodo--expand-dynamic-filter'."
  (let* ((dynamic-type (plist-get entry :dynamic-type))
         (tag-mode (or (plist-get entry :tag-mode)
                       (when (plist-get entry :tag-ignore-value) "name-only")
                       "name-only"))
         (sort-by (or (plist-get entry :sort-by) "alpha"))
         (limit (plist-get entry :limit))
         (count-format (altodo--count-format-p entry))
         (nest (or (plist-get entry :nest) 0))
         (inherited (altodo--inherited-properties
                     entry altodo--dynamic-own-properties))
         (title (plist-get entry :title))
         (exclude-person (plist-get entry :exclude-person))
         (exclude-tag (plist-get entry :exclude-tag))
         (exclude-tag-value (plist-get entry :exclude-tag-value))
         ;; 複合フィルタ下での値収集
         (alist (altodo--collect-dynamic-values-with-exclude
                 dynamic-type source-buffer tag-mode
                 exclude-person exclude-tag exclude-tag-value combined-predicate))
         (sorted (if (member dynamic-type '("person" "tag"))
                     (altodo--sort-dynamic-values alist sort-by)
                   (altodo--sort-dynamic-values alist "alpha")))
         (limited (altodo--limit-dynamic-values sorted limit)))
    (mapcar (lambda (item)
              (let* ((value (car item))
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
                  ,@(when count-format `(:count-format ,count-format))
                  ,@inherited)))
            limited)))

(defun altodo--find-line-with-tag (tag value)
  "Find line number with #TAG:VALUE.
Returns line number (1-based) or nil if not found."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward (format "#%s:%s\\(?:[ \t]\\|$\\)"
                                     (regexp-quote tag) (regexp-quote value))
                             nil t)
      (line-number-at-pos))))

(defun altodo-goto-dependency ()
  "Jump to dependency target line.
If current line has #dep:xxx, jump to line with #id:xxx."
  (interactive)
  (let ((dep-id (altodo--line-extract-tag-value "dep")))
    (if dep-id
        (let ((target-line (altodo--find-line-with-tag "id" dep-id)))
          (if target-line
              (progn
                (goto-char (point-min))
                (forward-line (1- target-line))
                (message "Jumped to dependency: #id:%s" dep-id))
            (message "Dependency target not found: #id:%s" dep-id)))
      (message "No dependency tag found on current line"))))

(defun altodo--has-seq-tasks-tag ()
  "Check if current line has #seq-tasks tag."
  (save-excursion
    (beginning-of-line)
    ;; The whole tag name: `#seq-tasks-foo' is another tag.
    (re-search-forward "\\(?:^\\|[ \t]\\)#seq-tasks\\(?:[ \t]\\|$\\)"
                       (line-end-position) t)))

(defun altodo--is-seq-tasks-child-blocked-p ()
  "Return non-nil if the current line is a blocked child of a seq-tasks task.
A child of a task with the tag #seq-tasks is blocked while the sibling
right above it is neither done nor cancelled.  The first child is never
blocked.  A task without indentation has no parent, so it is not checked;
searching for its parent would scan up to the beginning of the buffer."
  (when (and (altodo--task-p)
             (> (altodo--get-current-indent) 0))
    (let ((indent (altodo--get-current-indent))
          (previous-sibling-open nil)
          (previous-sibling-seen nil)
          (parent-is-seq-tasks nil)
          (done nil))
      (save-excursion
        (beginning-of-line)
        (while (and (not done) (zerop (forward-line -1)))
          (when (looking-at altodo-task-regex)
            ;; `altodo--get-current-indent' changes the match data.
            (let ((state (match-string 2))
                  (line-indent (altodo--get-current-indent)))
              (cond
               ((and (= line-indent indent) (not previous-sibling-seen))
                (setq previous-sibling-seen t
                      previous-sibling-open
                      (not (altodo--task-is-completed
                            (altodo--normalize-state state)))))
               ((< line-indent indent)
                (setq done t
                      parent-is-seq-tasks
                      (and (= line-indent (- indent altodo-indent-size))
                           (altodo--has-seq-tasks-tag)))))))))
      (and parent-is-seq-tasks previous-sibling-open))))

;;; Helper: face of text

(defun altodo--apply-face-to-unfaced-text (start end face)
  "Apply FACE to text between START and END that lacks face property."
  (let ((pos start))
    (while (< pos end)
      (let ((next (or (next-single-property-change pos 'face nil end) end)))
        (unless (get-text-property pos 'face)
          (put-text-property pos next 'face face))
        (setq pos next)))))

;;; Sidebar Title Expansion

(defvar altodo--reported-face-rules nil
  "Invalid face rules that were reported, so that each is reported once.")

(defun altodo--report-invalid-face-rule (rule)
  "Show a message that the face RULE is invalid, once for each RULE."
  (unless (member rule altodo--reported-face-rules)
    (push rule altodo--reported-face-rules)
    (message "altodo: ignored the invalid face rule %S" rule)))

(defun altodo--face-rule-valid-p (rule)
  "Return non-nil if RULE has the form (OP NUMBER FACE).
OP is one of the comparison operators.  Only these are called: the rules
may come from .altodo-locals.el."
  (and (proper-list-p rule)
       (= (length rule) 3)
       (memq (nth 0 rule) '(< > <= >= = /=))
       (numberp (nth 1 rule))))

(defun altodo--evaluate-face-rules (rules count)
  "Evaluate RULES against COUNT, return first matching face or nil.
RULES: ((OP N FACE) ...) e.g. ((>= 10 \\='face1) (>= 1 \\='face2) (= 0
\\='face3)).  An invalid rule is skipped and reported once."
  (cond
   ((not (proper-list-p rules))
    (altodo--report-invalid-face-rule rules)
    nil)
   ((integerp count)
    (catch 'found
      (dolist (rule rules)
        (cond
         ((not (altodo--face-rule-valid-p rule))
          (altodo--report-invalid-face-rule rule))
         ((funcall (nth 0 rule) count (nth 1 rule))
          (throw 'found (nth 2 rule)))))))))

(defvar altodo--count-cache nil
  "Hash table (ENTRY to count) while the sidebar is drawn, otherwise nil.
The buffer does not change during a drawing, so the title and the face of an
entry can share one count.")

(defvar-local altodo--count-memo nil
  "Counts of the filter entries in this buffer, as (STAMP . TABLE).
TABLE maps an entry to its count without a combined predicate.  It is used
while STAMP is the same, see `altodo--count-memo-stamp'.")

(defun altodo--count-memo-stamp ()
  "Return what the counts of the current buffer depend on.
These are the text, the narrowing and today (for dates), so a click, a
selection or a change of AND/OR does not count the buffer again."
  (list (buffer-chars-modified-tick) (point-min) (point-max)
        (altodo--today-date-list)))

(defun altodo--count-memoizable-p (entry)
  "Return non-nil if the count of ENTRY depends only on the buffer.
A function as the pattern may read anything, so its count is not kept."
  (seq-every-p (lambda (key)
                 (let ((value (plist-get entry key)))
                   (or (null value) (stringp value))))
               '(:pattern :count-pattern-simple :count-pattern-lambda)))

(defun altodo--memoized-entry-count (entry source-buffer)
  "Return the count of ENTRY in SOURCE-BUFFER, kept while the buffer is the same."
  (with-current-buffer (or source-buffer (current-buffer))
    (let ((stamp (altodo--count-memo-stamp)))
      (unless (equal (car altodo--count-memo) stamp)
        (setq altodo--count-memo (cons stamp (make-hash-table :test 'equal))))
      (let ((cached (gethash entry (cdr altodo--count-memo) 'miss)))
        (if (not (eq cached 'miss))
            cached
          (let ((count (altodo--compute-entry-count entry source-buffer)))
            ;; nil: the code of ENTRY is not permitted to run (yet).
            (when (and count (altodo--count-memoizable-p entry))
              (puthash entry count (cdr altodo--count-memo)))
            count))))))

(defun altodo--get-entry-count (entry &optional source-buffer combined-predicate combine-mode)
  "Get match count for ENTRY from SOURCE-BUFFER, using `altodo--count-cache'.
COMBINED-PREDICATE and COMBINE-MODE are as in `altodo--compute-entry-count'.
Without COMBINED-PREDICATE the count is also kept while the buffer does not
change (`altodo--memoized-entry-count')."
  (let ((compute
         (lambda ()
           (if combined-predicate
               (altodo--compute-entry-count entry source-buffer
                                            combined-predicate combine-mode)
             (altodo--memoized-entry-count entry source-buffer)))))
    (if (null altodo--count-cache)
        (funcall compute)
      (let ((cached (gethash entry altodo--count-cache 'miss)))
        (if (not (eq cached 'miss))
            cached
          (puthash entry (funcall compute) altodo--count-cache))))))

(defun altodo--compute-entry-count (entry &optional source-buffer combined-predicate combine-mode)
  "Get match count for ENTRY from SOURCE-BUFFER.
If COMBINED-PREDICATE is provided, count only lines matching both ENTRY and
COMBINED-PREDICATE.
COMBINE-MODE is \\='and or \\='or, used to determine whether to apply
combined-predicate.
Returns integer (number of matching lines), or nil if the code of ENTRY
is not permitted to run.  An entry with :count-value (an expanded heading)
has the count already."
  (when (altodo--entry-code-permitted-p entry)
    (if (plist-member entry :count-value)
        (plist-get entry :count-value)
      (let* ((type (plist-get entry :type))
             (pattern (plist-get entry :pattern))
             (count-pattern-simple (plist-get entry :count-pattern-simple))
             (count-pattern-lambda (plist-get entry :count-pattern-lambda))
             ;; Only the task lines are counted unless the entry says nil.
             (exclude-others (if (plist-member entry :count-exclude-others)
                                 (plist-get entry :count-exclude-others)
                               t))
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
            (altodo--count-matching-lines effective-predicate exclude-others source-buffer)))))))

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

(defun altodo--count-format-p (entry)
  "Return non-nil if `%n' of the filter ENTRY is replaced with the count.
:count-format is t when ENTRY does not have it."
  (if (plist-member entry :count-format)
      (plist-get entry :count-format)
    t))

(defun altodo--count-face (entry count)
  "Return the face of the number COUNT of the filter ENTRY, or nil.
:count-face-rules wins over :face-count."
  (or (when (plist-get entry :count-face-rules)
        (altodo--evaluate-face-rules (plist-get entry :count-face-rules) count))
      (plist-get entry :face-count)))

(defun altodo--format-sidebar-title (pattern-spec &optional source-buffer combined-predicate combine-mode)
  "Generate :title from PATTERN-SPEC.
Replace %n with match count unless :count-format is nil.
Apply :face-count or :count-face-rules to the count if specified.
SOURCE-BUFFER is the main altodo buffer for counting matches.
COMBINED-PREDICATE is the combined predicate for dynamic count calculation.
COMBINE-MODE is \\='and or \\='or, used to determine whether to apply
combined-predicate.
Returns formatted title string."
  (let ((title (plist-get pattern-spec :title)))
    (if (not (and (stringp title)
                  (altodo--count-format-p pattern-spec)
                  (string-match "%n" title)))
        title
      (let* ((count (altodo--get-entry-count pattern-spec source-buffer combined-predicate combine-mode))
             (count-str (if count (number-to-string count) "?"))
             (resolved-face (altodo-sidebar--resolve-face
                             (altodo--count-face pattern-spec count))))
        (when resolved-face
          (setq count-str (propertize count-str 'face resolved-face)))
        (replace-regexp-in-string "%n" count-str title t t)))))

;;; Strikethrough Matcher

(defun altodo-sidebar-make-config (&optional source-buffer)
  "Create sidebar config for altodo.
Reads patterns from .altodo-locals.el and customization variables.
Returns config plist ready for altodo-sidebar--display.
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

(defun altodo-sidebar--setup-sidebar-window (sidebar-win source-buffer)
  "Setup SIDEBAR-WIN with SOURCE-BUFFER context.
Disables `tooltip-mode', sets source buffer, and positions cursor."
  (with-selected-window sidebar-win
    (setq-local altodo-sidebar--source-buffer source-buffer)
    (when (fboundp 'tooltip-mode)
      (setq-local tooltip-mode nil))
    (goto-char (point-min))
    (recenter 0)))

(defun altodo-sidebar-show ()
  "Display altodo sidebar.
Creates sidebar buffer with filter patterns from .altodo-locals.el."
  (interactive)
  (altodo--register-sidebar-faces)
  (let ((source-buffer (current-buffer)))
    (let ((sidebar-win (altodo-sidebar--display (altodo-sidebar-make-config))))
      (when sidebar-win
        (altodo-sidebar--setup-sidebar-window sidebar-win source-buffer)
        ;; Initialize modeline with default mode
        (let ((sidebar-buf (altodo-sidebar--get-buffer source-buffer)))
          (when sidebar-buf
            (with-current-buffer sidebar-buf
              (altodo--update-sidebar-modeline))))))))

(defun altodo--get-display-context-option (entry)
  "Return the :display-context of filter ENTRY.
The value is `all', `heading-only' or `none'.  It defaults to `heading-only'."
  (if (plist-member entry :display-context)
      (plist-get entry :display-context)
    'heading-only))

(defun altodo-sidebar--jump-to-heading (entry source-buffer)
  "Move point to the heading of the `heading-jump' ENTRY in SOURCE-BUFFER.
Select the window of SOURCE-BUFFER and put the heading near its top.
When a filter hides the heading line, clear the filter first."
  (let* ((marker (plist-get entry :marker))
         ;; Clearing the filter redraws the sidebar, which releases MARKER.
         (position (and (markerp marker)
                        (eq (marker-buffer marker) source-buffer)
                        (marker-position marker))))
    (if (not (and position
                  (with-current-buffer source-buffer
                    (save-excursion
                      (goto-char position)
                      (altodo--heading-level)))))
        (message "The heading no longer exists.  Refresh the sidebar")
      (with-current-buffer source-buffer
        (when (seq-some (lambda (overlay)
                          (and (eq (overlay-get overlay 'category)
                                   'altodo-filter)
                               (overlay-get overlay 'invisible)))
                        (overlays-at position))
          (altodo-filter-clear)))
      (select-window (or (get-buffer-window source-buffer)
                         (display-buffer source-buffer)))
      (goto-char position)
      (recenter 0))))

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

      ;; The jump must stay: `save-window-excursion' would undo it.
      (if (eq type 'heading-jump)
          (altodo-sidebar--jump-to-heading entry source-buffer)
        ;; Save window configuration to prevent scrolling
        (save-window-excursion
          (cond
           ;; Group header or separator - do nothing
           ((memq type '(group-header separator)))

           ;; Code from .altodo-locals.el that is not permitted to run
           ((not (altodo--entry-code-permitted-p entry t)))

           ;; Command - execute command in source buffer
           ((eq type 'command)
            (when command
              (with-current-buffer source-buffer
                (call-interactively command))))

           ;; Search - apply the pattern or the predicate to the source buffer
           ((and pattern (memq type '(search-simple search-lambda)))
            (altodo-sidebar--set-selection (list entry) 'single)
            (with-current-buffer source-buffer
              (altodo--filter-lines (altodo--compile-filter-predicate entry)
                                    show-multiline
                                    (altodo--get-display-context-option entry)))
            (altodo-sidebar-refresh)
            (altodo--update-sidebar-modeline))

           ;; No pattern or unknown type
           (t
            (message "No action for type=%s pattern=%s" type pattern))))
        ;; Outside `save-window-excursion', which would restore the focus.
        (when (and altodo-sidebar-focus-after-activation
                   (memq type '(search-simple search-lambda)))
          (altodo-sidebar--select-source-window source-buffer))))))

(defun altodo-sidebar--select-source-window (source-buffer)
  "Select the window of SOURCE-BUFFER, if the buffer is shown."
  (let ((window (get-buffer-window source-buffer)))
    (when window
      (select-window window))))


(defun altodo-sidebar-hide ()
  "Hide altodo sidebar."
  (interactive)
  (let ((buf (altodo--get-sidebar-buffer)))
    (when buf
      (delete-windows-on buf))))

(defun altodo-sidebar-toggle ()
  "Toggle altodo sidebar visibility."
  (interactive)
  (let ((buf (altodo--get-sidebar-buffer)))
    (if (and buf (get-buffer-window buf))
        (altodo-sidebar-hide)
      (altodo-sidebar-show))))

(defun altodo-sidebar-refresh ()
  "Refresh altodo sidebar."
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
            (altodo-sidebar--render buf config)
            ;; Restore cursor position
            (goto-char (min cursor-pos (point-max)))))))))

;;; Multiple Filter Selection Functions

(defun altodo-sidebar--toggle-filter-selection (entry)
  "Toggle ENTRY in multiple selection mode.
Add or remove ENTRY from altodo-sidebar--selected-filters.
If no filters are selected after removal, clear the filter.
A click on an entry is not part of a multiple selection: the first entry
chosen after a click starts a new selection.
A heading entry cannot be selected."
  (when (eq (plist-get entry :type) 'heading-jump)
    (message "A heading entry cannot be selected"))
  (when (and (not (eq (plist-get entry :type) 'heading-jump))
             (or (altodo--with-sidebar-buffer
                  (lambda () (member entry altodo-sidebar--selected-filters)))
                 (altodo--entry-code-permitted-p entry t)))
    (altodo--with-sidebar-buffer
     (lambda ()
       (let* ((cursor-pos (point))
              (current (unless (eq altodo-sidebar--selection-mode 'single)
                         altodo-sidebar--selected-filters))
              (selected (if (member entry current)
                            (delete entry (copy-sequence current))
                          (cons entry current)))
              (source-buf altodo-sidebar--source-buffer))
         (if (null selected)
             ;; Nothing is selected: clear the filter and the selection.
             (when (and source-buf (buffer-live-p source-buf))
               (with-current-buffer source-buf
                 (altodo-filter-clear)))
           (altodo-sidebar--set-selection selected 'multiple)
           (altodo-sidebar--apply-combined-filter)
           ;; Refresh sidebar to update faces
           (altodo-sidebar-refresh)
           (altodo--update-sidebar-modeline))
         (goto-char (min cursor-pos (point-max))))))))

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

          ;; Keep the predicate for the counts of the next drawing.
          (altodo--with-sidebar-buffer
           (lambda ()
             (altodo-sidebar--set-selection selected-filters
                                            altodo-sidebar--selection-mode
                                            combined-predicate)))

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
    (if (not button)
        (message "No filter on this line")
      (let ((entry (button-get button 'sidebar-entry)))
        (if entry
            (altodo-sidebar--toggle-filter-selection entry)
          (message "No filter entry at point"))))))

(defun altodo-sidebar-set-and-mode ()
  "Set AND mode for multiple filter combination.
Command: `altodo-sidebar-set-and-mode'"
  (interactive)
  (altodo--with-sidebar-buffer
   (lambda ()
     (setq altodo-sidebar--combine-mode 'and)
     (when (altodo-sidebar--multiple-p)
       (altodo-sidebar--apply-combined-filter)
       (altodo-sidebar-refresh))
     (altodo--update-sidebar-modeline))))

(defun altodo-sidebar-set-or-mode ()
  "Set OR mode for multiple filter combination.
Command: `altodo-sidebar-set-or-mode'"
  (interactive)
  (altodo--with-sidebar-buffer
   (lambda ()
     (setq altodo-sidebar--combine-mode 'or)
     (when (altodo-sidebar--multiple-p)
       (altodo-sidebar--apply-combined-filter)
       (altodo-sidebar-refresh))
     (altodo--update-sidebar-modeline))))

(defun altodo-sidebar-toggle-combine-mode ()
  "Toggle AND/OR mode for multiple filter combination.
Command: `altodo-sidebar-toggle-combine-mode'"
  (interactive)
  (altodo--with-sidebar-buffer
   (lambda ()
     (if (not (altodo-sidebar--multiple-p))
         (message "No filters selected")
       (setq altodo-sidebar--combine-mode
             (if (eq altodo-sidebar--combine-mode 'and) 'or 'and))
       (altodo-sidebar--apply-combined-filter)
       (altodo-sidebar-refresh)))))

(defun altodo-sidebar--toggle-combine-mode ()
  "Toggle between AND and OR combine modes."
  (interactive)
  (setq altodo-sidebar--combine-mode
        (if (eq altodo-sidebar--combine-mode 'and) 'or 'and))
  (force-mode-line-update))

(defun altodo-sidebar--get-mode-line-string ()
  "Generate mode-line string for multiple selection display.
Returns nil if no filters selected, otherwise returns display string."
  (when (altodo-sidebar--multiple-p)
    (let ((mode-str (upcase (symbol-name altodo-sidebar--combine-mode))))
      (concat " Multiple: " (number-to-string (length altodo-sidebar--selected-filters))
              " filters, "
              (propertize mode-str
                          'mouse-face 'mode-line-highlight
                          'local-map (make-mode-line-mouse-map 'mouse-1
                                                               'altodo-sidebar--toggle-combine-mode)
                          'help-echo "mouse-1: toggle AND/OR")))))

(defun altodo-sidebar-mouse-toggle-selection (event)
  "Toggle multiple selection via mouse EVENT.
Control and the left mouse button toggle the selection.
Command: `altodo-sidebar-mouse-toggle-selection'"
  (interactive "e")

  (let* ((pos (posn-point (event-start event)))
         (button (button-at pos)))
    (if (not button)
        (message "No filter at point")
      (let ((entry (button-get button 'sidebar-entry)))
        (if entry
            (altodo-sidebar--toggle-filter-selection entry)
          (message "No filter entry at point"))))))


(provide 'altodo)

;;; altodo.el ends here
