;;; altodo-calendar.el --- Mini calendar for the altodo sidebar  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 altodo contributors

;; Author: twofaults
;; Maintainer: twofaults
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: calendar, convenience
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

;; A small library that draws a month calendar in the current buffer.  It
;; depends only on `calendar'.  altodo uses it for the calendar of its
;; sidebar, but it knows nothing about altodo and can be used by other
;; packages.
;;
;; Main function:
;;
;;   (altodo-calendar-insert MONTH YEAR &rest OPTIONS)
;;
;; It inserts the title line, the weekday names and the weeks at point.
;; OPTIONS is a property list:
;;
;;   :indent N          Indent of every line (default 0).
;;   :week-start N      First day of the week, 0 for Sunday (default
;;                      `calendar-week-start-day').
;;   :today DATE        Date of today as (MONTH DAY YEAR) (default
;;                      `calendar-current-date').
;;   :day-function F    Function called with a date (MONTH DAY YEAR).  It
;;                      returns nil or a property list with
;;                        :faces       faces for the day, strongest first
;;                        :action      function; makes the day a button
;;                        :properties  more properties of the button
;;                        :help        text for `help-echo'
;;   :nav-function F    Function called with -1, 1 or 0 when the button for
;;                      the previous month, the next month or this month is
;;                      activated.  Without it there are no buttons.
;;   :show-nav BOOL     Show the buttons `<' and `>' (default
;;                      `altodo-calendar-show-nav').  The month name stays
;;                      a button that returns to this month.
;;
;; Every day cell has the text property `altodo-calendar-date'.
;;
;; The names of the weekdays and months, their faces, the title format and
;; the holidays can be customized: see the group `altodo-calendar'.
;; Saturdays and Sundays get their own faces.  Holidays are found by
;; `altodo-calendar-holiday-function'; the default knows the Japanese
;; national holidays.  `altodo-calendar-emacs-holiday' uses
;; `calendar-holidays' of Emacs instead.

;;; Code:

(require 'calendar)
(require 'cl-lib)
(require 'subr-x)

(declare-function calendar-check-holidays "holidays" (date))

;;; Customization

(defgroup altodo-calendar nil
  "Mini calendar of the altodo sidebar."
  :group 'calendar
  :prefix "altodo-calendar-")

(defcustom altodo-calendar-day-names ["Su" "Mo" "Tu" "We" "Th" "Fr" "Sa"]
  "Names of the weekdays, from Sunday.  A vector of 7 strings.
Every column is as wide as the widest name (at least 2 columns)."
  :type '(vector string string string string string string string))

(defcustom altodo-calendar-month-names
  ["January" "February" "March" "April" "May" "June" "July" "August"
   "September" "October" "November" "December"]
  "Names of the months, from January.  A vector of 12 strings."
  :type '(vector string string string string string string
                 string string string string string string))

(defcustom altodo-calendar-title-format "%s %d"
  "Format of the title line.
It gets the name of the month and the year, as in `format'.  Use
\"%2$d, %1$s\" to put the year first."
  :type 'string)

(defcustom altodo-calendar-show-nav t
  "Whether to show the buttons `<' and `>' on the title line."
  :type 'boolean)

(defcustom altodo-calendar-holiday-function #'altodo-calendar-japanese-holiday
  "Function that returns the name of the holiday on a date, or nil.
It is called with a date (MONTH DAY YEAR).  Set it to nil to show no
holidays, or to `altodo-calendar-emacs-holiday' to use `calendar-holidays'."
  :type '(choice (const :tag "No holidays" nil)
                 (const :tag "Japanese national holidays"
                        altodo-calendar-japanese-holiday)
                 (const :tag "Holidays of Emacs (calendar-holidays)"
                        altodo-calendar-emacs-holiday)
                 function))

;;; Faces

(defface altodo-calendar-header-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for the title (month and year) of the calendar.")

(defface altodo-calendar-nav-face
  '((t :inherit link))
  "Face for the buttons `<' and `>' of the calendar.")

(defface altodo-calendar-weekday-face
  '((t :inherit shadow))
  "Face for the name of a weekday from Monday to Friday.")

(defface altodo-calendar-day-face
  '((t :inherit default))
  "Face for a normal day of the calendar.")

(defface altodo-calendar-sunday-face
  '((t :inherit error :weight normal))
  "Face for Sundays (red by default).")

(defface altodo-calendar-saturday-face
  '((t :inherit font-lock-function-name-face))
  "Face for Saturdays (blue by default).")

(defface altodo-calendar-holiday-face
  '((t :inherit altodo-calendar-sunday-face))
  "Face for holidays (red by default).")

(defface altodo-calendar-today-face
  '((t :inherit region :box (:line-width -1)))
  "Face for today.  The background is the selection color by default.")

(defface altodo-calendar-selected-face
  '((t :inherit highlight :weight bold :underline t))
  "Face for a day that the caller marks as selected.")

(defface altodo-calendar-due-face
  '((t :inherit error :inverse-video t))
  "Face for a day with due tasks (red background by default).")

(defface altodo-calendar-due-heavy-face
  '((t :inherit warning :inverse-video t :weight bold))
  "Face for a day with many due tasks.")

(defface altodo-calendar-overdue-face
  '((t :weight bold :underline t))
  "Face added to a day with due tasks in the past.")

(defface altodo-calendar-start-face
  '((t :inherit font-lock-function-name-face :inverse-video t))
  "Face for a day with start dates (blue background by default).")

(defcustom altodo-calendar-day-name-faces
  [altodo-calendar-sunday-face altodo-calendar-weekday-face
   altodo-calendar-weekday-face altodo-calendar-weekday-face
   altodo-calendar-weekday-face altodo-calendar-weekday-face
   altodo-calendar-saturday-face]
  "Faces of the names of the weekdays, from Sunday.  A vector of 7 faces."
  :type '(vector face face face face face face face))

;;; Japanese national holidays

(defvar altodo-calendar--holiday-cache nil
  "Alist of (YEAR . HASH-TABLE) of the Japanese holidays already computed.
The hash table maps (MONTH . DAY) to the name of the holiday.")

(defun altodo-calendar--nth-weekday (year month weekday nth)
  "Return the day of the NTH WEEKDAY (0 is Sunday) of MONTH in YEAR."
  (let ((first (calendar-day-of-week (list month 1 year))))
    (+ 1 (mod (- weekday first) 7) (* 7 (1- nth)))))

(defun altodo-calendar--equinox-day (year spring)
  "Return the day of the equinox holiday of YEAR for 1980 to 2099, or nil.
SPRING non-nil means the vernal equinox (March), else the autumnal
equinox (September).  The values come from the approximation formula
that is valid for these years; outside them there is no holiday."
  (when (<= 1980 year 2099)
    (floor (- (+ (if spring 20.8431 23.2488)
                 (* 0.242194 (- year 1980)))
              (floor (- year 1980) 4)))))

(defun altodo-calendar--japanese-base-holidays (year)
  "Return an alist ((MONTH . DAY) . NAME) of the holidays of YEAR by law.
Substitute holidays and holidays between holidays are not included."
  (let ((list nil))
    (cl-flet ((add (month day name) (push (cons (cons month day) name) list)))
      (when (>= year 1949) (add 1 1 "元日"))
      (when (>= year 1949)
        (if (>= year 2000)
            (add 1 (altodo-calendar--nth-weekday year 1 1 2) "成人の日")
          (add 1 15 "成人の日")))
      (when (>= year 1967) (add 2 11 "建国記念の日"))
      (cond ((>= year 2020) (add 2 23 "天皇誕生日"))
            ((>= year 1989) (when (<= year 2018) (add 12 23 "天皇誕生日")))
            ((>= year 1949) (add 4 29 "天皇誕生日")))
      (let ((spring (altodo-calendar--equinox-day year t)))
        (when spring (add 3 spring "春分の日")))
      (cond ((>= year 2007) (add 4 29 "昭和の日"))
            ((>= year 1989) (add 4 29 "みどりの日")))
      (when (>= year 1949) (add 5 3 "憲法記念日"))
      (when (>= year 2007) (add 5 4 "みどりの日"))
      (when (>= year 1949) (add 5 5 "こどもの日"))
      (cond ((= year 2020) (add 7 23 "海の日"))
            ((= year 2021) (add 7 22 "海の日"))
            ((>= year 2003)
             (add 7 (altodo-calendar--nth-weekday year 7 1 3) "海の日"))
            ((>= year 1996) (add 7 20 "海の日")))
      (cond ((= year 2020) (add 8 10 "山の日"))
            ((= year 2021) (add 8 8 "山の日"))
            ((>= year 2016) (add 8 11 "山の日")))
      (cond ((>= year 2003)
             (add 9 (altodo-calendar--nth-weekday year 9 1 3) "敬老の日"))
            ((>= year 1966) (add 9 15 "敬老の日")))
      (let ((autumn (altodo-calendar--equinox-day year nil)))
        (when autumn (add 9 autumn "秋分の日")))
      (cond ((= year 2020) (add 7 24 "スポーツの日"))
            ((= year 2021) (add 7 23 "スポーツの日"))
            ((>= year 2022)
             (add 10 (altodo-calendar--nth-weekday year 10 1 2) "スポーツの日"))
            ((>= year 2000)
             (add 10 (altodo-calendar--nth-weekday year 10 1 2) "体育の日"))
            ((>= year 1966) (add 10 10 "体育の日")))
      (when (>= year 1948) (add 11 3 "文化の日"))
      (when (>= year 1948) (add 11 23 "勤労感謝の日"))
      (pcase year
        (1959 (add 4 10 "皇太子明仁親王の結婚の儀"))
        (1989 (add 2 24 "昭和天皇の大喪の礼"))
        (1990 (add 11 12 "即位礼正殿の儀"))
        (1993 (add 6 9 "皇太子徳仁親王の結婚の儀"))
        (2019 (add 5 1 "天皇の即位の日")
              (add 10 22 "即位礼正殿の儀"))))
    list))

(defun altodo-calendar--japanese-holidays-of-year (year)
  "Return a hash table from (MONTH . DAY) to the holiday name for YEAR.
It includes the holidays between two holidays (since 1986) and the
substitute holidays (since 1973)."
  (let ((table (make-hash-table :test 'equal)))
    (dolist (entry (altodo-calendar--japanese-base-holidays year))
      (puthash (car entry) (cdr entry) table))
    (cl-flet ((holiday-p (absolute)
                (let ((date (calendar-gregorian-from-absolute absolute)))
                  (and (= (nth 2 date) year)
                       (gethash (cons (nth 0 date) (nth 1 date)) table))))
              (put-holiday (absolute name)
                (let ((date (calendar-gregorian-from-absolute absolute)))
                  (puthash (cons (nth 0 date) (nth 1 date)) name table))))
      ;; A weekday between two holidays is a holiday.
      (when (>= year 1986)
        (let ((base (copy-sequence (hash-table-keys table))))
          (dolist (key base)
            (let* ((absolute (+ 2 (calendar-absolute-from-gregorian
                                   (list (car key) (cdr key) year))))
                   (middle (1- absolute)))
              (when (and (holiday-p absolute)
                         (not (holiday-p middle))
                         (/= (mod middle 7) 0))
                (put-holiday middle "国民の休日"))))))
      ;; A holiday on a Sunday: the next day (Monday only before 2007, else
      ;; the first day that is not a holiday) is a substitute holiday.
      (when (>= year 1973)
        (let ((sundays nil))
          (maphash (lambda (key _name)
                     (let ((absolute (calendar-absolute-from-gregorian
                                      (list (car key) (cdr key) year))))
                       (when (and (= (mod absolute 7) 0)
                                  (or (> year 1973) (>= (car key) 5)
                                      (and (= (car key) 4) (>= (cdr key) 12))))
                         (push absolute sundays))))
                   table)
          (dolist (sunday (sort sundays #'<))
            (let ((day (1+ sunday)))
              (if (< year 2007)
                  (unless (holiday-p day)
                    (put-holiday day "振替休日"))
                (while (holiday-p day)
                  (setq day (1+ day)))
                (put-holiday day "振替休日")))))))
    table))

(defun altodo-calendar-japanese-holiday (date)
  "Return the name of the Japanese national holiday on DATE, or nil.
DATE is a list (MONTH DAY YEAR).  The holidays follow the law on national
holidays from 1948.  The equinox holidays are computed for 1980 to 2099
only; other years have none."
  (let* ((year (nth 2 date))
         (cached (assq year altodo-calendar--holiday-cache)))
    (unless cached
      (setq cached (cons year (altodo-calendar--japanese-holidays-of-year year)))
      (push cached altodo-calendar--holiday-cache)
      (when (> (length altodo-calendar--holiday-cache) 12)
        (setq altodo-calendar--holiday-cache
              (cl-subseq altodo-calendar--holiday-cache 0 12))))
    (gethash (cons (nth 0 date) (nth 1 date)) (cdr cached))))

(defun altodo-calendar-emacs-holiday (date)
  "Return the name of the first holiday of `calendar-holidays' on DATE, or nil.
DATE is a list (MONTH DAY YEAR).  `calendar-holidays' must be set, for
example by a package for the holidays of your country."
  (require 'holidays)
  (car (calendar-check-holidays date)))

;;; Drawing

(defun altodo-calendar-cell-width ()
  "Return the width of a day column: the widest weekday name, at least 2."
  (max 2 (apply #'max (mapcar #'string-width altodo-calendar-day-names))))

(defun altodo-calendar-width ()
  "Return the width of the calendar: 7 columns and 6 spaces."
  (+ (* 7 (altodo-calendar-cell-width)) 6))

(defun altodo-calendar--pad-left (text width)
  "Return TEXT padded with spaces on the left to WIDTH columns."
  (concat (make-string (max 0 (- width (string-width text))) ?\s) text))

(defun altodo-calendar--insert-button (text face function)
  "Insert TEXT with FACE as a button for FUNCTION, which takes no argument."
  (let ((start (point)))
    (insert text)
    (make-text-button start (point)
                      'type 'button
                      'face face
                      'follow-link t
                      'action (lambda (_button) (funcall function))
                      'help-echo nil
                      'mouse-face 'highlight)))

(defun altodo-calendar--insert-title (month year indent nav-function show-nav)
  "Insert the title line of MONTH and YEAR, indented by INDENT.
NAV-FUNCTION and SHOW-NAV are as for `altodo-calendar-insert'."
  (let* ((name (aref altodo-calendar-month-names (1- month)))
         (title (format altodo-calendar-title-format name year))
         (buttons (and nav-function show-nav))
         (room (- (altodo-calendar-width) (if buttons 2 0)
                  (string-width title)))
         (left (max 0 (/ room 2)))
         (right (max 0 (- room left))))
    (insert (make-string indent ?\s))
    (when buttons
      (altodo-calendar--insert-button
       "<" 'altodo-calendar-nav-face (lambda () (funcall nav-function -1))))
    (insert (make-string left ?\s))
    (if nav-function
        (altodo-calendar--insert-button
         title 'altodo-calendar-header-face (lambda () (funcall nav-function 0)))
      (insert (propertize title 'face 'altodo-calendar-header-face)))
    (insert (make-string right ?\s))
    (when buttons
      (altodo-calendar--insert-button
       ">" 'altodo-calendar-nav-face (lambda () (funcall nav-function 1))))
    (insert "\n")))

(defun altodo-calendar--day-faces (info date today weekday holiday)
  "Return the faces of the cell of DATE.
INFO is the plist from the day function.  TODAY is today's date, WEEKDAY
the day of the week of DATE (0 for Sunday), and HOLIDAY its holiday name."
  (append (plist-get info :faces)
          (and (equal date today) '(altodo-calendar-today-face))
          (cond (holiday '(altodo-calendar-holiday-face))
                ((= weekday 0) '(altodo-calendar-sunday-face))
                ((= weekday 6) '(altodo-calendar-saturday-face)))
          '(altodo-calendar-day-face)))

(defun altodo-calendar--insert-cell (date text info faces help)
  "Insert the cell TEXT of DATE with FACES.
INFO is the plist from the day function; HELP is the text for `help-echo'.
A cell with an :action in INFO is a button."
  (let ((start (point))
        (action (plist-get info :action)))
    (insert text)
    (if action
        (apply #'make-text-button start (point)
               'type 'button
               'face faces
               'follow-link t
               'action action
               'help-echo help
               'mouse-face 'highlight
               (plist-get info :properties))
      (put-text-property start (point) 'face faces)
      (when help
        (put-text-property start (point) 'help-echo help)))
    (put-text-property start (point) 'altodo-calendar-date date)))

(defun altodo-calendar-insert (month year &rest options)
  "Insert the calendar of MONTH in YEAR at point.
OPTIONS is a property list: :indent, :week-start, :today, :day-function,
:nav-function and :show-nav.  See the Commentary of this file."
  (let* ((indent (or (plist-get options :indent) 0))
         (week-start (or (plist-get options :week-start) calendar-week-start-day))
         (today (or (plist-get options :today) (calendar-current-date)))
         (day-function (plist-get options :day-function))
         (nav-function (plist-get options :nav-function))
         (show-nav (if (plist-member options :show-nav)
                       (plist-get options :show-nav)
                     altodo-calendar-show-nav))
         (cell-width (altodo-calendar-cell-width))
         (first-offset (mod (- (calendar-day-of-week (list month 1 year))
                               week-start)
                            7))
         (days (calendar-last-day-of-month month year))
         (rows (ceiling (+ first-offset days) 7)))
    (altodo-calendar--insert-title month year indent nav-function show-nav)
    ;; Names of the weekdays.
    (insert (make-string indent ?\s))
    (dotimes (column 7)
      (let ((weekday (mod (+ week-start column) 7)))
        (when (> column 0) (insert " "))
        (insert (propertize
                 (altodo-calendar--pad-left
                  (aref altodo-calendar-day-names weekday) cell-width)
                 'face (aref altodo-calendar-day-name-faces weekday)))))
    (insert "\n")
    ;; The weeks.
    (dotimes (row rows)
      (insert (make-string indent ?\s))
      (let ((last-column (if (= row (1- rows))
                             (mod (+ first-offset days -1) 7)
                           6)))
        (dotimes (column (1+ last-column))
          (let ((day (- (+ (* row 7) column 1) first-offset)))
            (when (> column 0) (insert " "))
            (if (or (< day 1) (> day days))
                (insert (make-string cell-width ?\s))
              (let* ((date (list month day year))
                     (weekday (mod (+ week-start column) 7))
                     (holiday (and altodo-calendar-holiday-function
                                   (funcall altodo-calendar-holiday-function date)))
                     (info (and day-function (funcall day-function date)))
                     (help (let ((parts (delq nil (list holiday
                                                        (plist-get info :help)))))
                             (and parts (string-join parts ", ")))))
                (altodo-calendar--insert-cell
                 date
                 (altodo-calendar--pad-left (number-to-string day) cell-width)
                 info
                 (altodo-calendar--day-faces info date today weekday holiday)
                 help))))))
      (insert "\n"))))

(provide 'altodo-calendar)
;;; altodo-calendar.el ends here
