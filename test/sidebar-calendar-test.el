;;; sidebar-calendar-test.el --- Tests for the calendar and agenda of the sidebar  -*- lexical-binding: t; -*-

;;; Commentary:
;; T20261018-97: entries of `altodo-filter-patterns' with the type `calendar'
;; and `agenda'.  Today is fixed at 2026-03-10 (a Tuesday).

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defconst sidebar-calendar-test--text
  (concat "[ ] a -> 2026-03-10\n"
          "[ ] b -> 2026-03-10\n"
          "[ ] c -> 2026-03-12 #t\n"
          "[ ] d 2026-03-14 ->\n"
          "[ ] old -> 2026-03-01\n"
          "[x] fin -> 2026-03-10\n"
          "[ ] bad -> 2026-02-30\n")
  "Sample tasks.  Done tasks and dates that do not exist are not counted.")

(defun sidebar-calendar-test--render (entries &optional text indent)
  "Render ENTRIES in a sidebar for TEXT and return the sidebar buffer.
The caller kills the buffer.  INDENT is the indent width per nest level."
  (let ((source (generate-new-buffer " calendar-source"))
        (sidebar (generate-new-buffer " calendar-sidebar")))
    (with-current-buffer source
      (insert (or text sidebar-calendar-test--text))
      (altodo-mode))
    (altodo-test-with-today 2026 3 10
      (altodo-sidebar--render
       sidebar (list :entries entries :indent (or indent 2)
                     :source-buffer source)))
    sidebar))

(defmacro sidebar-calendar-test--with-render (var entries &rest body)
  "Bind VAR to the sidebar buffer rendered for ENTRIES and run BODY."
  (declare (indent 2))
  `(let ((,var (sidebar-calendar-test--render ,entries)))
     (unwind-protect
         (with-current-buffer ,var ,@body)
       (kill-buffer ,var))))

(defun sidebar-calendar-test--day-position (day)
  "Return the position of the cell of DAY in the weeks of the calendar."
  (save-excursion
    (goto-char (point-min))
    (re-search-forward "^Mo Tu\\|^Su Mo")
    (forward-line 1)
    (re-search-forward (format "\\_<%d\\_>" day))
    (match-beginning 0)))

(defun sidebar-calendar-test--faces-of-day (day)
  "Return the faces of the cell of DAY in the current sidebar buffer."
  (let ((face (get-text-property (sidebar-calendar-test--day-position day) 'face)))
    (if (listp face) face (list face))))

(defun sidebar-calendar-test--button-at-day-p (day)
  "Return non-nil if the cell of DAY is a button."
  (button-at (sidebar-calendar-test--day-position day)))

;;; The calendar

(ert-deftest sidebar-calendar-renders-month-grid ()
  "The calendar shows the title line, the weekdays, and the weeks."
  (sidebar-calendar-test--with-render buffer '((:type calendar))
    (let ((text (buffer-string)))
      (should (string-match-p "^<  *March 2026  *>$" text))
      (should (string-match-p "^Su Mo Tu We Th Fr Sa *$" text))
      (should (string-match-p "^ 8  9 10 11 12 13 14 *$" text))
      (should (string-match-p "^29 30 31 *$" text)))))

(ert-deftest sidebar-calendar-shows-the-title-and-indent ()
  "A `:title' is a line above the calendar, and `:nest' indents it."
  (sidebar-calendar-test--with-render buffer '((:title "Cal" :type calendar :nest 1))
    (let ((lines (split-string (buffer-string) "\n")))
      (should (equal (nth 0 lines) "  Cal"))
      (should (string-prefix-p "  <" (nth 1 lines)))
      (should (string-prefix-p "  Su Mo" (nth 2 lines))))))

(ert-deftest sidebar-calendar-faces-by-day ()
  "Days get faces from their due and start dates, weekday, holiday and today."
  (sidebar-calendar-test--with-render buffer '((:type calendar))
    ;; Today (Tuesday) with 2 due tasks: the due face wins over today's.
    (should (equal (sidebar-calendar-test--faces-of-day 10)
                   '(altodo-calendar-due-face altodo-calendar-today-face
                                              altodo-calendar-day-face)))
    ;; Thursday with 1 due task.
    (should (equal (sidebar-calendar-test--faces-of-day 12)
                   '(altodo-calendar-due-face altodo-calendar-day-face)))
    ;; Saturday with a start date.
    (should (equal (sidebar-calendar-test--faces-of-day 14)
                   '(altodo-calendar-start-face altodo-calendar-saturday-face
                                                altodo-calendar-day-face)))
    ;; Sunday without tasks.
    (should (equal (sidebar-calendar-test--faces-of-day 8)
                   '(altodo-calendar-sunday-face altodo-calendar-day-face)))
    ;; A past Sunday with an open due task.
    (should (equal (sidebar-calendar-test--faces-of-day 1)
                   '(altodo-calendar-overdue-face altodo-calendar-due-face
                                                  altodo-calendar-sunday-face
                                                  altodo-calendar-day-face)))
    ;; A holiday (the vernal equinox, a Friday).
    (should (equal (sidebar-calendar-test--faces-of-day 20)
                   '(altodo-calendar-holiday-face altodo-calendar-day-face)))
    ;; A normal day.
    (should (equal (sidebar-calendar-test--faces-of-day 17)
                   '(altodo-calendar-day-face)))))

(ert-deftest sidebar-calendar-heavy-face ()
  "A day with `altodo-calendar-heavy-count' due tasks gets the heavy face."
  (let ((altodo-calendar-heavy-count 2))
    (sidebar-calendar-test--with-render buffer '((:type calendar))
      (should (memq 'altodo-calendar-due-heavy-face
                    (sidebar-calendar-test--faces-of-day 10)))
      (should-not (memq 'altodo-calendar-due-face
                        (sidebar-calendar-test--faces-of-day 10)))
      (should-not (memq 'altodo-calendar-due-heavy-face
                        (sidebar-calendar-test--faces-of-day 12))))))

(ert-deftest sidebar-calendar-only-days-with-tasks-are-buttons ()
  "Days with tasks are buttons; others are plain text."
  (sidebar-calendar-test--with-render buffer '((:type calendar))
    (dolist (day '(1 10 12 14))
      (should (sidebar-calendar-test--button-at-day-p day)))
    (dolist (day '(2 11 13))
      (should-not (sidebar-calendar-test--button-at-day-p day)))))

(ert-deftest sidebar-calendar-target-selects-due-or-start ()
  "`:calendar-target' limits the calendar to due or start dates."
  (sidebar-calendar-test--with-render buffer '((:type calendar :calendar-target due))
    (should (sidebar-calendar-test--button-at-day-p 12))
    (should-not (sidebar-calendar-test--button-at-day-p 14)))
  (sidebar-calendar-test--with-render buffer '((:type calendar :calendar-target start))
    (should-not (sidebar-calendar-test--button-at-day-p 12))
    (should (sidebar-calendar-test--button-at-day-p 14))))

(ert-deftest sidebar-calendar-count-done ()
  "`:count-done' also counts done tasks."
  (let ((text "[x] fin -> 2026-03-20\n"))
    (let ((buffer (sidebar-calendar-test--render '((:type calendar)) text)))
      (unwind-protect
          (with-current-buffer buffer
            (should-not (sidebar-calendar-test--button-at-day-p 20)))
        (kill-buffer buffer)))
    (let ((buffer (sidebar-calendar-test--render
                   '((:type calendar :count-done t)) text)))
      (unwind-protect
          (with-current-buffer buffer
            (should (sidebar-calendar-test--button-at-day-p 20)))
        (kill-buffer buffer)))))

(ert-deftest sidebar-calendar-week-start-day ()
  "The week starts on `altodo-week-start-day'."
  (let ((altodo-week-start-day 0))
    (sidebar-calendar-test--with-render buffer '((:type calendar))
      (should (string-match-p "^Su Mo Tu We Th Fr Sa *$" (buffer-string)))
      ;; With Sunday first, the 8th is in the second row, first column.
      (should (equal (sidebar-calendar-test--faces-of-day 8)
                     '(altodo-calendar-sunday-face altodo-calendar-day-face))))))

(ert-deftest sidebar-calendar-another-month ()
  "`altodo-sidebar--calendar-month' selects the month shown."
  (let ((source (generate-new-buffer " calendar-source"))
        (sidebar (generate-new-buffer " calendar-sidebar")))
    (unwind-protect
        (progn
          (with-current-buffer source (insert "[ ] a -> 2026-04-15\n") (altodo-mode))
          (with-current-buffer sidebar (setq altodo-sidebar--calendar-month '(4 . 2026)))
          (altodo-test-with-today 2026 3 10
            (altodo-sidebar--render
             sidebar (list :entries '((:type calendar)) :indent 2
                           :source-buffer source)))
          (with-current-buffer sidebar
            (should (string-match-p "April 2026" (buffer-string)))
            (should (sidebar-calendar-test--button-at-day-p 15))))
      (kill-buffer source)
      (kill-buffer sidebar))))

(ert-deftest sidebar-calendar-day-button-filters-the-day ()
  "The filter entry of a day matches the tasks of the kind."
  (altodo-test-with-today 2026 3 10
    (altodo-test-with-buffer "[ ] a -> 2026-03-10\n[ ] b 2026-03-10 ->\n[ ] c -> 2026-03-11\n"
      (let ((due (altodo-sidebar-calendar-test--predicate '(3 10 2026) 'due))
            (start (altodo-sidebar-calendar-test--predicate '(3 10 2026) 'start)))
        (should (funcall due))
        (should-not (funcall start))
        (forward-line 1)
        (should-not (funcall due))
        (should (funcall start)))))
  (should (equal (plist-get (altodo--day-filter-entry '(3 10 2026) 'due) :pattern)
                 "due-date:2026-03-10"))
  (should (equal (plist-get (altodo--day-filter-entry '(3 10 2026) 'start) :pattern)
                 "start-date:2026-03-10")))

(defun altodo-sidebar-calendar-test--predicate (date kind)
  "Return the predicate of the filter entry of DATE and KIND."
  (altodo--compile-simple-pattern
   (plist-get (altodo--day-filter-entry date kind) :pattern)))

(ert-deftest sidebar-calendar-priority-decides-a-day-with-both-kinds ()
  "A day with due and start tasks takes `altodo-calendar-priority'."
  (let ((text "[ ] a -> 2026-03-12\n[ ] b 2026-03-12 ->\n"))
    (dolist (case '((due . altodo-calendar-due-face)
                    (start . altodo-calendar-start-face)))
      (let* ((altodo-calendar-priority (car case))
             (buffer (sidebar-calendar-test--render '((:type calendar)) text)))
        (unwind-protect
            (with-current-buffer buffer
              (should (equal (sidebar-calendar-test--faces-of-day 12)
                             (list (cdr case) 'altodo-calendar-day-face)))
              (should (equal (plist-get
                              (button-get (sidebar-calendar-test--button-at-day-p 12)
                                          'sidebar-entry)
                              :pattern)
                             (format "%s-date:2026-03-12" (car case)))))
          (kill-buffer buffer))))))

(ert-deftest sidebar-calendar-day-with-one-kind-uses-that-kind ()
  "With `both', a day with only start tasks filters by the start date."
  (let ((altodo-calendar-priority 'due))
    (sidebar-calendar-test--with-render buffer '((:type calendar))
      (should (equal (plist-get (button-get (sidebar-calendar-test--button-at-day-p 14)
                                            'sidebar-entry)
                                :pattern)
                     "start-date:2026-03-14")))))

(ert-deftest sidebar-calendar-day-pattern-follows-date-format ()
  "The pattern of a day is written in `altodo-date-format'."
  (let ((altodo-date-format "%Y/%m/%d"))
    (should (equal (plist-get (altodo--day-filter-entry '(3 10 2026) 'due) :pattern)
                   "due-date:2026/03/10"))))

(ert-deftest sidebar-calendar-selected-day-uses-the-selection-face ()
  "A day whose filter is selected gets the selection face first."
  (let ((source (generate-new-buffer " calendar-source"))
        (sidebar (generate-new-buffer " calendar-sidebar")))
    (unwind-protect
        (progn
          (with-current-buffer source (insert "[ ] a -> 2026-03-12\n") (altodo-mode))
          (with-current-buffer sidebar
            (setq altodo-sidebar--selected-filters
                  (list (altodo--day-filter-entry '(3 12 2026) 'due))))
          (altodo-test-with-today 2026 3 10
            (altodo-sidebar--render
             sidebar (list :entries '((:type calendar)) :indent 2
                           :source-buffer source)))
          (with-current-buffer sidebar
            (should (eq (car (sidebar-calendar-test--faces-of-day 12))
                        'altodo-calendar-selected-face))))
      (kill-buffer source)
      (kill-buffer sidebar))))

(ert-deftest sidebar-calendar-narrow-sidebar-shows-a-note ()
  "A sidebar window narrower than the calendar shows a note instead."
  (let ((source (generate-new-buffer " calendar-source"))
        (sidebar (generate-new-buffer " calendar-sidebar")))
    (unwind-protect
        (cl-letf (((symbol-function 'get-buffer-window) (lambda (&rest _) 'window))
                  ((symbol-function 'window-body-width) (lambda (&rest _) 15)))
          (with-current-buffer source (insert "[ ] a\n") (altodo-mode))
          (altodo-sidebar--render
           sidebar (list :entries '((:type calendar)) :indent 2
                         :source-buffer source))
          (with-current-buffer sidebar
            (should (string-match-p "too narrow" (buffer-string)))
            (should-not (string-match-p "March" (buffer-string)))))
      (kill-buffer source)
      (kill-buffer sidebar))))

(ert-deftest sidebar-calendar-is-first-in-the-default-patterns ()
  "The default sidebar patterns start with the calendar."
  (should (eq (plist-get (car altodo-default-filter-patterns) :type) 'calendar))
  (let ((buffer (sidebar-calendar-test--render altodo-default-filter-patterns)))
    (unwind-protect
        (with-current-buffer buffer
          (goto-char (point-min))
          (should (looking-at " *<"))
          (should (search-forward "Status" nil t)))
      (kill-buffer buffer))))

(ert-deftest sidebar-agenda-weekday-follows-the-calendar-day-names ()
  "The agenda uses `altodo-calendar-day-names' when it is changed."
  (let ((altodo-calendar-day-names ["日" "月" "火" "水" "木" "金" "土"]))
    (sidebar-calendar-test--with-render buffer
        '((:type agenda :days 2 :date-format "%m/%d"))
      (should (string-match-p "03/10 火" (buffer-string)))
      (should (string-match-p "03/11 水" (buffer-string))))))

(ert-deftest sidebar-agenda-weekday-default-is-english-abbreviation ()
  "With the default names, the agenda shows the three-letter abbreviation."
  (should (equal altodo-calendar-day-names altodo-calendar-default-day-names))
  (sidebar-calendar-test--with-render buffer
      '((:type agenda :days 2 :date-format "%m/%d"))
    (should (string-match-p "03/10 Tue" (buffer-string)))))

(ert-deftest sidebar-calendar-default-patterns-in-a-narrow-sidebar ()
  "In a narrow sidebar the default patterns show a note and the other entries."
  (let ((source (generate-new-buffer " calendar-source"))
        (sidebar (generate-new-buffer " calendar-sidebar")))
    (unwind-protect
        (cl-letf (((symbol-function 'get-buffer-window) (lambda (&rest _) 'window))
                  ((symbol-function 'window-body-width) (lambda (&rest _) 16)))
          (with-current-buffer source (insert "[ ] a\n") (altodo-mode))
          (altodo-sidebar--render
           sidebar (list :entries altodo-default-filter-patterns :indent 2
                         :source-buffer source))
          (with-current-buffer sidebar
            (should (string-match-p "too narrow" (buffer-string)))
            (should (string-match-p "^Status" (buffer-string)))))
      (kill-buffer source)
      (kill-buffer sidebar))))

;;; The agenda

(ert-deftest sidebar-agenda-renders-days-and-counts ()
  "The agenda has one line per day with the due (D) and start (S) counts.
The date follows `altodo-date-format' by default."
  (sidebar-calendar-test--with-render buffer '((:type agenda :days 5))
    (should (equal (buffer-string)
                   (concat "Overdue  1\n"
                           "Today    2026-03-10 Tue D2\n"
                           "Tomorrow 2026-03-11 Wed\n"
                           "         2026-03-12 Thu D1\n"
                           "         2026-03-13 Fri\n"
                           "         2026-03-14 Sat S1")))))

(ert-deftest sidebar-agenda-date-follows-altodo-date-format ()
  "With `altodo' the date is in `altodo-date-format'; `done-tag' follows the #done format."
  (let ((altodo-date-format "%Y/%m/%d")
        (altodo-done-tag-datetime-format "%d.%m.%Y")
        (text "[ ] a -> 2026/03/10\n"))
    (dolist (case '((nil . "Today    2026/03/10 Tue D1")
                    (done-tag . "Today    10.03.2026 Tue D1")))
      (let* ((entry (append '(:type agenda :days 1 :agenda-overdue nil)
                            (and (car case) (list :date-format (car case)))))
             (buffer (sidebar-calendar-test--render (list entry) text)))
        (unwind-protect
            (with-current-buffer buffer
              (should (equal (buffer-string) (cdr case))))
          (kill-buffer buffer))))))

(ert-deftest sidebar-agenda-done-tag-format-without-setting-is-the-date ()
  "With `done-tag' and no #done format, the date has no time."
  (let ((altodo-done-tag-datetime-format nil))
    (sidebar-calendar-test--with-render buffer
        '((:type agenda :days 1 :agenda-overdue nil :date-format done-tag))
      (should (equal (buffer-string) "Today    2026-03-10 Tue D2")))))

(ert-deftest sidebar-agenda-own-date-format-and-weekday ()
  "An own format string replaces the date; the weekday can be hidden."
  (sidebar-calendar-test--with-render buffer
      '((:type agenda :days 2 :agenda-overdue nil :date-format "%m/%d"))
    (should (equal (buffer-string) "Today    03/10 Tue D2\nTomorrow 03/11 Wed")))
  (sidebar-calendar-test--with-render buffer
      '((:type agenda :days 2 :agenda-overdue nil :date-format "%m/%d" :show-weekday nil))
    (should (equal (buffer-string) "Today    03/10 D2\nTomorrow 03/11")))
  (sidebar-calendar-test--with-render buffer
      '((:type agenda :days 1 :agenda-overdue nil :date-format "%b %e (%a)"
               :show-weekday nil))
    (should (equal (buffer-string) "Today    Mar 10 (Tue) D2")))
  )

(ert-deftest sidebar-agenda-labels-can-be-set ()
  "The labels of today, tomorrow and overdue come from the options or the entry."
  (sidebar-calendar-test--with-render buffer
      '((:type agenda :days 2 :date-format "%m/%d" :today-label "今日"
               :tomorrow-label "明日" :overdue-label "期限超過"))
    (should (equal (buffer-string)
                   (concat "期限超過 1\n"
                           "今日     03/10 Tue D2\n"
                           "明日     03/11 Wed"))))
  (sidebar-calendar-test--with-render buffer
      '((:type agenda :days 2 :date-format "%m/%d" :today-label "Now"
               :tomorrow-label "Next" :overdue-label "Late"))
    (should (equal (buffer-string)
                   "Late 1\nNow  03/10 Tue D2\nNext 03/11 Wed")))
  ;; An empty label leaves the column empty.
  (sidebar-calendar-test--with-render buffer
      '((:type agenda :days 2 :agenda-overdue nil :date-format "%m/%d"
               :today-label "" :tomorrow-label ""))
    (should (equal (buffer-string) "03/10 Tue D2\n03/11 Wed"))))

(ert-deftest sidebar-agenda-label-on-its-own-line ()
  "With `:label-newline' the label is a line and the date is indented below it."
  (sidebar-calendar-test--with-render buffer
      '((:type agenda :days 3 :date-format "%m/%d" :label-newline t))
    (should (equal (buffer-string)
                   (concat "Overdue\n  1\n"
                           "Today\n  03/10 Tue D2\n"
                           "Tomorrow\n  03/11 Wed\n"
                           "  03/12 Thu D1"))))
  (sidebar-calendar-test--with-render buffer
      '((:type agenda :days 1 :agenda-overdue nil :date-format "%m/%d"
               :label-newline nil))
    (should (equal (buffer-string) "Today    03/10 Tue D2"))))

(ert-deftest sidebar-agenda-label-line-keeps-the-nest-indent ()
  "The label line and the date line are indented by `:nest'."
  (sidebar-calendar-test--with-render buffer
      '((:title "Next" :type agenda :days 1 :nest 1 :label-newline t
               :agenda-overdue nil :date-format "%m/%d"))
    (should (equal (buffer-string) "  Next\n  Today\n    03/10 Tue D2"))))

(ert-deftest sidebar-agenda-options ()
  "`:agenda-overdue' hides the overdue line; the target limits the counts."
  (sidebar-calendar-test--with-render buffer '((:title "Agenda" :type agenda :days 2
                                                       :agenda-overdue nil
                                                       :calendar-target due
                                                       :date-format "%m/%d"))
    (should (equal (buffer-string)
                   "Agenda\nToday    03/10 Tue D2\nTomorrow 03/11 Wed"))))

(ert-deftest sidebar-agenda-faces-and-buttons ()
  "Lines with tasks are buttons; lines without are plain and dimmed."
  (sidebar-calendar-test--with-render buffer '((:type agenda :days 3))
    (goto-char (point-min))
    (should (button-at (point)))
    (should (eq (get-text-property (point) 'face) 'altodo-agenda-overdue-face))
    (forward-line 1)
    (should (button-at (point)))
    (should (eq (get-text-property (point) 'face) 'altodo-agenda-today-face))
    (forward-line 1)
    (should-not (button-at (point)))
    (should (eq (get-text-property (point) 'face) 'altodo-agenda-empty-face))))

(ert-deftest sidebar-agenda-overdue-button-filters-overdue ()
  "The overdue line applies the `due-date:overdue' filter."
  (sidebar-calendar-test--with-render buffer '((:type agenda :days 1))
    (goto-char (point-min))
    (should (equal (plist-get (button-get (button-at (point)) 'sidebar-entry)
                              :pattern)
                   "due-date:overdue"))))

(ert-deftest sidebar-calendar-click-on-a-day-filters-the-buffer ()
  "Pressing a day of the real sidebar filters the tasks of that day."
  (let ((source (generate-new-buffer "calendar-click.altodo"))
        (altodo-default-filter-patterns '((:title "Cal" :type calendar)))
        (altodo-sidebar-position 'left))
    (unwind-protect
        (cl-letf (((symbol-function 'window-body-width) (lambda (&rest _) 60)))
          (altodo-test-with-today 2026 3 10
            (with-current-buffer source
              (insert sidebar-calendar-test--text)
              (altodo-mode))
            (switch-to-buffer source)
            (altodo-sidebar-show)
            (let ((sidebar (altodo--get-sidebar-buffer source)))
              (with-current-buffer sidebar
                (altodo-sidebar--apply-filter
                 (sidebar-calendar-test--button-at-day-p 12)))
              ;; Only the task due on the 12th stays visible.
              (with-current-buffer source
                (should (= (length altodo--filter-overlays) 6)))
              ;; The sidebar was drawn again with the day selected.
              (with-current-buffer sidebar
                (should (eq (car (sidebar-calendar-test--faces-of-day 12))
                            'altodo-calendar-selected-face))))))
      (when-let ((sidebar (altodo--get-sidebar-buffer source)))
        (kill-buffer sidebar))
      (kill-buffer source))))

;;; Navigation

(ert-deftest sidebar-calendar-navigation-moves-by-month ()
  "The month buttons move the shown month; the title returns to this month."
  (let ((sidebar (generate-new-buffer " calendar-sidebar"))
        (refreshed 0))
    (unwind-protect
        (cl-letf (((symbol-function 'altodo--get-sidebar-buffer) (lambda (&rest _) sidebar))
                  ((symbol-function 'altodo-sidebar-refresh) (lambda () (setq refreshed (1+ refreshed)))))
          (altodo-test-with-today 2026 3 10
            (altodo-sidebar--calendar-move 1)
            (should (equal (buffer-local-value 'altodo-sidebar--calendar-month sidebar)
                           '(4 . 2026)))
            (dotimes (_ 4) (altodo-sidebar--calendar-move -1))
            (should (equal (buffer-local-value 'altodo-sidebar--calendar-month sidebar)
                           '(12 . 2025)))
            (altodo-sidebar--calendar-move 0)
            (should-not (buffer-local-value 'altodo-sidebar--calendar-month sidebar))
            (should (= refreshed 6))))
      (kill-buffer sidebar))))

(ert-deftest sidebar-calendar-navigation-commands ()
  "The commands move to the next, previous and this month."
  (let ((moves nil))
    (cl-letf (((symbol-function 'altodo-sidebar--calendar-move)
               (lambda (delta) (push delta moves))))
      (altodo-sidebar-calendar-next)
      (altodo-sidebar-calendar-previous)
      (altodo-sidebar-calendar-today))
    (should (equal (nreverse moves) '(1 -1 0)))
    (should (eq (lookup-key altodo-sidebar-mode-map (kbd "}")) 'altodo-sidebar-calendar-next))
    (should (eq (lookup-key altodo-sidebar-mode-map (kbd "{")) 'altodo-sidebar-calendar-previous))
    (should (eq (lookup-key altodo-sidebar-mode-map (kbd ".")) 'altodo-sidebar-calendar-today))))

(ert-deftest sidebar-calendar-return-key-presses-a-month-button ()
  "RET on a month button runs its action, and on a day button applies the filter."
  (let ((moves nil))
    (sidebar-calendar-test--with-render buffer '((:type calendar))
      (cl-letf (((symbol-function 'altodo-sidebar--calendar-move)
                 (lambda (delta) (push delta moves))))
        (goto-char (point-min))
        (should (looking-at "<"))
        (altodo-sidebar--apply-filter-at-point)
        (should (equal moves '(-1)))))))

(ert-deftest sidebar-calendar-nav-buttons-can-be-hidden ()
  "`altodo-calendar-show-nav' hides `<' and `>'; the month name stays a button."
  (let ((altodo-calendar-show-nav nil))
    (sidebar-calendar-test--with-render buffer '((:type calendar))
      (let ((first-line (buffer-substring (point-min) (line-end-position))))
        (should-not (string-match-p "[<>]" first-line))
        (should (string-match-p "March 2026" first-line)))
      (goto-char (point-min))
      (search-forward "March")
      (should (button-at (1- (point)))))))

(provide 'sidebar-calendar-test)
;;; sidebar-calendar-test.el ends here
