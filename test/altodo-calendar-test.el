;;; altodo-calendar-test.el --- Tests for the library altodo-calendar  -*- lexical-binding: t; -*-

;;; Commentary:
;; The mini calendar library: the grid, the names and their faces, the
;; buttons, the options, and the holidays.

;;; Code:

(require 'ert)
(require 'altodo-calendar)

(defun altodo-calendar-test--render (month year &rest options)
  "Return the text of the calendar of MONTH in YEAR made with OPTIONS."
  (with-temp-buffer
    (apply #'altodo-calendar-insert month year options)
    (buffer-string)))

(defun altodo-calendar-test--lines (text)
  "Return the lines of TEXT without the trailing spaces.
The title line is also trimmed on the left, as it is centered."
  (let ((lines (mapcar #'string-trim-right (split-string text "\n" t))))
    (cons (string-trim-left (car lines)) (cdr lines))))

(defun altodo-calendar-test--position (date)
  "Return the position of the cell of DATE in the current buffer."
  (let ((position (point-min)) (found nil))
    (while (and (not found) position (< position (point-max)))
      (if (equal (get-text-property position 'altodo-calendar-date) date)
          (setq found position)
        (setq position (next-single-property-change
                        position 'altodo-calendar-date nil (point-max)))))
    found))

;;; The grid

(ert-deftest altodo-calendar-test-grid-monday-first ()
  "The weeks start on the given weekday, with right-aligned days."
  (should (equal (altodo-calendar-test--lines
                  (altodo-calendar-test--render 3 2026 :week-start 1))
                 '("March 2026"
                   "Mo Tu We Th Fr Sa Su"
                   "                   1"
                   " 2  3  4  5  6  7  8"
                   " 9 10 11 12 13 14 15"
                   "16 17 18 19 20 21 22"
                   "23 24 25 26 27 28 29"
                   "30 31"))))

(ert-deftest altodo-calendar-test-grid-sunday-first ()
  "With Sunday first, the 1st of March 2026 is in the first column."
  (should (equal (altodo-calendar-test--lines
                  (altodo-calendar-test--render 3 2026 :week-start 0))
                 '("March 2026"
                   "Su Mo Tu We Th Fr Sa"
                   " 1  2  3  4  5  6  7"
                   " 8  9 10 11 12 13 14"
                   "15 16 17 18 19 20 21"
                   "22 23 24 25 26 27 28"
                   "29 30 31"))))

(ert-deftest altodo-calendar-test-february-and-leap-year ()
  "The last day of February depends on the leap year."
  (should (string-match-p "\\<29\\>" (altodo-calendar-test--render 2 2024)))
  (should-not (string-match-p "\\<29\\>" (altodo-calendar-test--render 2 2026))))

(ert-deftest altodo-calendar-test-indent ()
  "Every line is indented."
  (dolist (line (split-string (altodo-calendar-test--render 3 2026 :indent 3) "\n" t))
    (should (string-prefix-p "   " line))))

(ert-deftest altodo-calendar-test-day-cells-have-the-date ()
  "Every day cell has the text property `altodo-calendar-date'."
  (with-temp-buffer
    (altodo-calendar-insert 3 2026 :week-start 1)
    (goto-char (point-min))
    (search-forward "17")
    (should (equal (get-text-property (1- (point)) 'altodo-calendar-date)
                   '(3 17 2026)))))

;;; Names and widths

(ert-deftest altodo-calendar-test-long-day-names-set-the-width ()
  "The columns are as wide as the widest weekday name."
  (let ((altodo-calendar-day-names ["Sun" "Mon" "Tues" "Wed" "Thu" "Fri" "Sat"]))
    (should (= (altodo-calendar-cell-width) 4))
    (should (= (altodo-calendar-width) 34))
    (should (equal (nth 1 (altodo-calendar-test--lines
                           (altodo-calendar-test--render 3 2026 :week-start 0)))
                   " Sun  Mon Tues  Wed  Thu  Fri  Sat"))
    (should (equal (nth 2 (altodo-calendar-test--lines
                           (altodo-calendar-test--render 3 2026 :week-start 0)))
                   "   1    2    3    4    5    6    7"))))

(ert-deftest altodo-calendar-test-wide-characters-count-two-columns ()
  "Names with wide characters are aligned by display width."
  (let ((altodo-calendar-day-names ["日" "月" "火" "水" "木" "金" "土"]))
    (should (= (altodo-calendar-cell-width) 2))
    (let ((lines (altodo-calendar-test--lines
                  (altodo-calendar-test--render 3 2026 :week-start 0))))
      (should (equal (nth 1 lines) "日 月 火 水 木 金 土"))
      (should (= (string-width (nth 1 lines)) 20)))))

(ert-deftest altodo-calendar-test-month-names-and-title-format ()
  "The month names and the title format can be set."
  (let ((altodo-calendar-month-names
         ["1月" "2月" "3月" "4月" "5月" "6月" "7月" "8月" "9月" "10月" "11月" "12月"])
        (altodo-calendar-title-format "%2$d年 %1$s"))
    (should (equal (car (altodo-calendar-test--lines
                         (altodo-calendar-test--render 3 2026)))
                   "2026年 3月"))))

(ert-deftest altodo-calendar-test-day-name-faces ()
  "The names of the weekdays get the faces of `altodo-calendar-day-name-faces'."
  (with-temp-buffer
    (altodo-calendar-insert 3 2026 :week-start 1)
    (goto-char (point-min))
    (forward-line 1)
    (should (eq (get-text-property (point) 'face) 'altodo-calendar-weekday-face))
    (end-of-line)
    (should (eq (get-text-property (1- (point)) 'face) 'altodo-calendar-sunday-face))
    (goto-char (point-min))
    (forward-line 1)
    (forward-char 15)
    (should (eq (get-text-property (point) 'face) 'altodo-calendar-saturday-face)))
  (let ((altodo-calendar-day-name-faces
         (make-vector 7 'altodo-calendar-header-face)))
    (with-temp-buffer
      (altodo-calendar-insert 3 2026 :week-start 1)
      (goto-char (point-min))
      (forward-line 1)
      (should (eq (get-text-property (point) 'face) 'altodo-calendar-header-face)))))

;;; Faces of the days

(defun altodo-calendar-test--faces (date &rest options)
  "Return the faces of the cell of DATE in the calendar made with OPTIONS."
  (with-temp-buffer
    (apply #'altodo-calendar-insert (nth 0 date) (nth 2 date) options)
    (let ((face (get-text-property (altodo-calendar-test--position date) 'face)))
      (if (listp face) face (list face)))))

(ert-deftest altodo-calendar-test-weekend-and-holiday-faces ()
  "Saturdays, Sundays, holidays and normal days get their faces."
  (let ((altodo-calendar-holiday-function #'altodo-calendar-japanese-holiday))
    (should (equal (altodo-calendar-test--faces '(3 14 2026))
                   '(altodo-calendar-saturday-face altodo-calendar-day-face)))
    (should (equal (altodo-calendar-test--faces '(3 15 2026))
                   '(altodo-calendar-sunday-face altodo-calendar-day-face)))
    (should (equal (altodo-calendar-test--faces '(3 20 2026))
                   '(altodo-calendar-holiday-face altodo-calendar-day-face)))
    (should (equal (altodo-calendar-test--faces '(3 17 2026))
                   '(altodo-calendar-day-face)))
    ;; A holiday on a Saturday is a holiday (2026-11-03 is a Tuesday;
    ;; 2025-11-22 is a Saturday that is not).
    (should (equal (altodo-calendar-test--faces '(11 3 2026))
                   '(altodo-calendar-holiday-face altodo-calendar-day-face)))))

(ert-deftest altodo-calendar-test-no-holiday-function ()
  "Without a holiday function, holidays look like normal days."
  (let ((altodo-calendar-holiday-function nil))
    (should (equal (altodo-calendar-test--faces '(3 20 2026))
                   '(altodo-calendar-day-face)))))

(ert-deftest altodo-calendar-test-today-face-and-order ()
  "Today gets its face after the faces of the day function."
  (should (equal (altodo-calendar-test--faces '(3 17 2026) :today '(3 17 2026))
                 '(altodo-calendar-today-face altodo-calendar-day-face)))
  (should (equal (altodo-calendar-test--faces
                  '(3 17 2026) :today '(3 17 2026)
                  :day-function (lambda (_date) '(:faces (altodo-calendar-due-face))))
                 '(altodo-calendar-due-face altodo-calendar-today-face
                                            altodo-calendar-day-face))))

(ert-deftest altodo-calendar-test-day-function-makes-buttons ()
  "A day with an :action is a button with the given properties and help."
  (with-temp-buffer
    (let ((called nil))
      (altodo-calendar-insert
       3 2026 :week-start 1
       :day-function (lambda (date)
                       (when (= (nth 1 date) 12)
                         (list :faces '(altodo-calendar-due-face)
                               :action (lambda (button)
                                         (setq called (button-get button 'mark)))
                               :properties '(mark yes)
                               :help "one task"))))
      (let* ((position (altodo-calendar-test--position '(3 12 2026)))
             (button (button-at position)))
        (should button)
        (should (equal (get-text-property position 'help-echo) "one task"))
        (button-activate button)
        (should (eq called 'yes))
        (should-not (button-at (altodo-calendar-test--position '(3 13 2026))))))))

(ert-deftest altodo-calendar-test-holiday-name-in-help ()
  "The name of a holiday is in the help text."
  (with-temp-buffer
    (altodo-calendar-insert 5 2026 :week-start 1)
    (let ((position (altodo-calendar-test--position '(5 6 2026))))
      (should (equal (get-text-property position 'help-echo) "振替休日")))))

;;; Month buttons

(ert-deftest altodo-calendar-test-nav-buttons ()
  "The buttons call the navigation function with -1, 1 and 0."
  (let ((calls nil))
    (with-temp-buffer
      (altodo-calendar-insert 3 2026 :nav-function (lambda (delta) (push delta calls)))
      (goto-char (point-min))
      (button-activate (button-at (point)))
      (search-forward ">")
      (button-activate (button-at (1- (point))))
      (search-backward "March")
      (button-activate (button-at (point))))
    (should (equal (nreverse calls) '(-1 1 0)))))

(ert-deftest altodo-calendar-test-nav-buttons-can-be-hidden ()
  "With :show-nav nil, only the month name is a button."
  (with-temp-buffer
    (altodo-calendar-insert 3 2026 :nav-function #'ignore :show-nav nil)
    (let ((first-line (buffer-substring (point-min) (line-end-position))))
      (should-not (string-match-p "[<>]" first-line)))
    (goto-char (point-min))
    (search-forward "March")
    (should (button-at (1- (point)))))
  (with-temp-buffer
    (let ((altodo-calendar-show-nav nil))
      (altodo-calendar-insert 3 2026 :nav-function #'ignore))
    (should-not (string-match-p "<" (buffer-string)))))

(ert-deftest altodo-calendar-test-no-buttons-without-nav-function ()
  "Without a navigation function the title is plain text."
  (with-temp-buffer
    (altodo-calendar-insert 3 2026)
    (should-not (string-match-p "[<>]" (buffer-substring (point-min) (line-end-position))))
    (should-not (button-at (point-min)))))

;;; Japanese holidays

(defun altodo-calendar-test--holidays (year)
  "Return the Japanese holidays of YEAR as a list of (MONTH DAY NAME)."
  (let (result)
    (dotimes (index 366)
      (let* ((absolute (+ (calendar-absolute-from-gregorian (list 1 1 year)) index))
             (date (calendar-gregorian-from-absolute absolute)))
        (when (= (nth 2 date) year)
          (let ((name (altodo-calendar-japanese-holiday date)))
            (when name (push (list (nth 0 date) (nth 1 date) name) result))))))
    (nreverse result)))

(ert-deftest altodo-calendar-test-japanese-holidays-2026 ()
  "The holidays of 2026."
  (should (equal (mapcar (lambda (h) (list (nth 0 h) (nth 1 h)))
                         (altodo-calendar-test--holidays 2026))
                 '((1 1) (1 12) (2 11) (2 23) (3 20) (4 29) (5 3) (5 4) (5 5) (5 6)
                   (7 20) (8 11) (9 21) (9 22) (9 23) (10 12) (11 3) (11 23)))))

(ert-deftest altodo-calendar-test-japanese-holidays-2025 ()
  "The holidays of 2025, with substitute holidays on Mondays."
  (should (equal (mapcar (lambda (h) (list (nth 0 h) (nth 1 h)))
                         (altodo-calendar-test--holidays 2025))
                 '((1 1) (1 13) (2 11) (2 23) (2 24) (3 20) (4 29) (5 3) (5 4) (5 5)
                   (5 6) (7 21) (8 11) (9 15) (9 23) (10 13) (11 3) (11 23) (11 24)))))

(ert-deftest altodo-calendar-test-japanese-holiday-names ()
  "The names of some holidays."
  (should (equal (altodo-calendar-japanese-holiday '(1 1 2026)) "元日"))
  (should (equal (altodo-calendar-japanese-holiday '(1 12 2026)) "成人の日"))
  (should (equal (altodo-calendar-japanese-holiday '(5 6 2026)) "振替休日"))
  (should (equal (altodo-calendar-japanese-holiday '(9 22 2026)) "国民の休日"))
  (should (equal (altodo-calendar-japanese-holiday '(10 12 2026)) "スポーツの日"))
  (should-not (altodo-calendar-japanese-holiday '(3 17 2026))))

(ert-deftest altodo-calendar-test-japanese-holidays-of-the-olympic-years ()
  "2020 and 2021 moved the Marine Day, Sports Day and Mountain Day."
  (let ((h2020 (altodo-calendar-test--holidays 2020))
        (h2021 (altodo-calendar-test--holidays 2021)))
    (dolist (date '((7 23 "海の日") (7 24 "スポーツの日") (8 10 "山の日")))
      (should (member date h2020)))
    (should-not (altodo-calendar-japanese-holiday '(7 20 2020)))
    (should-not (altodo-calendar-japanese-holiday '(10 12 2020)))
    (dolist (date '((7 22 "海の日") (7 23 "スポーツの日") (8 8 "山の日") (8 9 "振替休日")))
      (should (member date h2021)))
    (should-not (altodo-calendar-japanese-holiday '(8 11 2021)))))

(ert-deftest altodo-calendar-test-japanese-holidays-of-2019 ()
  "2019 had the accession holidays and no Emperor's Birthday."
  (let ((holidays (altodo-calendar-test--holidays 2019)))
    (dolist (date '((4 29 "昭和の日") (4 30 "国民の休日") (5 1 "天皇の即位の日")
                    (5 2 "国民の休日") (5 3 "憲法記念日") (5 6 "振替休日")
                    (10 22 "即位礼正殿の儀")))
      (should (member date holidays)))
    (should-not (altodo-calendar-japanese-holiday '(12 23 2019)))
    (should-not (altodo-calendar-japanese-holiday '(2 23 2019)))))

(ert-deftest altodo-calendar-test-japanese-holidays-before-2020 ()
  "The rules before the recent changes."
  ;; Coming of Age Day: 15 January until 1999, the second Monday after.
  (should (equal (altodo-calendar-japanese-holiday '(1 15 1999)) "成人の日"))
  (should (equal (altodo-calendar-japanese-holiday '(1 10 2000)) "成人の日"))
  ;; The Emperor's Birthday and Greenery Day.
  (should (equal (altodo-calendar-japanese-holiday '(4 29 1988)) "天皇誕生日"))
  (should (equal (altodo-calendar-japanese-holiday '(4 29 1990)) "みどりの日"))
  (should (equal (altodo-calendar-japanese-holiday '(12 23 1990)) "天皇誕生日"))
  (should (equal (altodo-calendar-japanese-holiday '(4 29 2008)) "昭和の日"))
  ;; Greenery Day moved to 4 May in 2007; before it 4 May was a citizens' holiday.
  (should (equal (altodo-calendar-japanese-holiday '(5 4 2007)) "みどりの日"))
  (should (equal (altodo-calendar-japanese-holiday '(5 4 1990)) "国民の休日"))
  ;; Marine Day and Respect for the Aged Day.
  (should (equal (altodo-calendar-japanese-holiday '(7 20 1996)) "海の日"))
  (should (equal (altodo-calendar-japanese-holiday '(7 21 2003)) "海の日"))
  (should (equal (altodo-calendar-japanese-holiday '(9 15 2002)) "敬老の日"))
  (should (equal (altodo-calendar-japanese-holiday '(9 15 2003)) "敬老の日"))
  ;; Health and Sports Day.
  (should (equal (altodo-calendar-japanese-holiday '(10 10 1999)) "体育の日"))
  (should (equal (altodo-calendar-japanese-holiday '(10 9 2000)) "体育の日"))
  ;; A citizens' holiday between two holidays in 2009.
  (should (equal (altodo-calendar-japanese-holiday '(9 22 2009)) "国民の休日")))

(ert-deftest altodo-calendar-test-substitute-holiday-rules ()
  "Before 2007 the substitute holiday is the Monday; after it, the next free day."
  ;; 1990-11-03 was a Saturday; 1991-11-03 a Sunday, so 11-04 was a substitute.
  (should (equal (altodo-calendar-japanese-holiday '(11 4 1991)) "振替休日"))
  ;; 2013-05-05 was a Sunday: 05-06 is a substitute holiday.
  (should (equal (altodo-calendar-japanese-holiday '(5 6 2013)) "振替休日"))
  ;; 2024-05-05 Sunday, 05-06 Monday substitute.
  (should (equal (altodo-calendar-japanese-holiday '(5 6 2024)) "振替休日"))
  ;; 2012-04-29 was a Sunday: 04-30 was a substitute.
  (should (equal (altodo-calendar-japanese-holiday '(4 30 2012)) "振替休日")))

(ert-deftest altodo-calendar-test-equinox-years ()
  "The equinox holidays are computed for 1980 to 2099 only."
  (should (equal (altodo-calendar-japanese-holiday '(3 20 2025)) "春分の日"))
  (should (equal (altodo-calendar-japanese-holiday '(9 23 2025)) "秋分の日"))
  (should (equal (altodo-calendar-japanese-holiday '(3 21 2023)) "春分の日"))
  (should (equal (altodo-calendar-japanese-holiday '(9 22 2024)) "秋分の日"))
  (should-not (altodo-calendar-japanese-holiday '(3 21 2100)))
  (should-not (altodo-calendar-japanese-holiday '(3 21 1979))))

(ert-deftest altodo-calendar-test-holidays-before-the-law ()
  "There are no holidays before the law of 1948."
  (should-not (altodo-calendar-japanese-holiday '(1 1 1947)))
  (should-not (altodo-calendar-japanese-holiday '(11 3 1947)))
  (should (equal (altodo-calendar-japanese-holiday '(11 3 1948)) "文化の日")))

;;; Holidays of Emacs

(ert-deftest altodo-calendar-test-emacs-holiday-function ()
  "`altodo-calendar-emacs-holiday' uses `calendar-holidays'."
  (require 'holidays)
  (let ((calendar-holidays '((holiday-fixed 3 3 "Doll Festival"))))
    (should (equal (altodo-calendar-emacs-holiday '(3 3 2026)) "Doll Festival"))
    (should-not (altodo-calendar-emacs-holiday '(3 4 2026)))
    (let ((altodo-calendar-holiday-function #'altodo-calendar-emacs-holiday))
      (should (equal (altodo-calendar-test--faces '(3 3 2026))
                     '(altodo-calendar-holiday-face altodo-calendar-day-face))))))

(provide 'altodo-calendar-test)
;;; altodo-calendar-test.el ends here
