;;; calendar-date-test.el --- Tests for the date input commands  -*- lexical-binding: t; -*-

;;; Commentary:
;; T20261018-90: `altodo-select-due-calendar', `altodo-select-start-calendar',
;; `altodo-input-due-date' and `altodo-input-start-date'.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defun calendar-date-test--set (text kind date)
  "Return TEXT after setting the date of KIND to DATE on its first line."
  (altodo-test-with-buffer text
    (altodo--set-line-date kind date)
    (buffer-string)))

;;; Setting a date on a line

(ert-deftest calendar-date-set-due-on-plain-line ()
  "A due date is appended as `-> DATE'."
  (should (equal (calendar-date-test--set "[ ] a #t\n" 'due '(3 20 2026))
                 "[ ] a #t -> 2026-03-20\n")))

(ert-deftest calendar-date-set-start-on-plain-line ()
  "A start date is appended as `DATE ->'."
  (should (equal (calendar-date-test--set "[ ] a #t\n" 'start '(3 1 2026))
                 "[ ] a #t 2026-03-01 ->\n")))

(ert-deftest calendar-date-replace-existing-dates ()
  "An existing date of the same kind is replaced."
  (should (equal (calendar-date-test--set "[ ] a -> 2026-02-02\n" 'due '(3 20 2026))
                 "[ ] a -> 2026-03-20\n"))
  (should (equal (calendar-date-test--set "[ ] a 2026-01-01 -> 2026-02-02\n"
                                          'start '(1 15 2026))
                 "[ ] a 2026-01-15 -> 2026-02-02\n")))

(ert-deftest calendar-date-share-the-arrow ()
  "A due date after a start date, and a start date before a due date, share `->'."
  (should (equal (calendar-date-test--set "[ ] a 2026-01-01 -> later\n"
                                          'due '(3 20 2026))
                 "[ ] a 2026-01-01 -> 2026-03-20 later\n"))
  (should (equal (calendar-date-test--set "[ ] a -> 2026-02-02\n"
                                          'start '(1 15 2026))
                 "[ ] a 2026-01-15 -> 2026-02-02\n")))

(ert-deftest calendar-date-set-follows-date-format ()
  "The date is written in `altodo-date-format'."
  (let ((altodo-date-format "%Y/%m/%d"))
    (should (equal (calendar-date-test--set "[ ] a\n" 'due '(3 5 2026))
                   "[ ] a -> 2026/03/05\n"))
    (should (equal (calendar-date-test--set "[ ] a -> 2026/01/01\n" 'due '(3 5 2026))
                   "[ ] a -> 2026/03/05\n"))))

(ert-deftest calendar-date-set-on-comment-line ()
  "A `///' line can have a date."
  (should (equal (calendar-date-test--set "/// note\n" 'due '(3 20 2026))
                 "/// note -> 2026-03-20\n")))

(ert-deftest calendar-date-set-refused-on-other-lines ()
  "A line that is not a task or comment line is refused."
  (altodo-test-with-buffer "plain text\n"
    (should-error (altodo--set-line-date 'due '(3 20 2026)) :type 'user-error)
    (should-error (altodo-input-due-date) :type 'user-error)
    (should-error (altodo-select-due-calendar) :type 'user-error)
    (should (equal (buffer-string) "plain text\n"))))

(ert-deftest calendar-date-current-line-date ()
  "The date on the line is returned as (MONTH DAY YEAR)."
  (altodo-test-with-buffer "[ ] a 2026-01-15 -> 2026-02-02\n"
    (should (equal (altodo--current-line-date 'start) '(1 15 2026)))
    (should (equal (altodo--current-line-date 'due) '(2 2 2026)))))

;;; The minibuffer commands

(ert-deftest calendar-date-input-commands-use-calendar-read-date ()
  "The minibuffer commands set the date read by `calendar-read-date'."
  (altodo-test-with-buffer "[ ] a\n"
    (let ((defaults nil))
      (cl-letf (((symbol-function 'calendar-read-date)
                 (lambda (&optional _noday default)
                   (push default defaults)
                   '(4 9 2026))))
        (altodo-input-due-date)
        (altodo-input-start-date))
      (should (equal (buffer-string) "[ ] a 2026-04-09 -> 2026-04-09\n"))
      (should (= (length defaults) 2))
      ;; Neither line had a start date, so both defaults are today.
      (should (equal (car defaults) (calendar-current-date))))))

(ert-deftest calendar-date-input-default-is-the-existing-date ()
  "The default of the prompt is the date already on the line."
  (altodo-test-with-buffer "[ ] a -> 2026-05-06\n"
    (let ((default nil))
      (cl-letf (((symbol-function 'calendar-read-date)
                 (lambda (&optional _noday date) (setq default date) date)))
        (altodo-input-due-date))
      (should (equal default '(5 6 2026))))))

;;; The calendar window

(defmacro calendar-date-test--with-calendar-cleanup (&rest body)
  "Run BODY and kill the calendar buffer afterward."
  (declare (indent 0))
  `(unwind-protect (progn ,@body)
     (when (get-buffer calendar-buffer)
       (with-current-buffer calendar-buffer (set-buffer-modified-p nil))
       (kill-buffer calendar-buffer))))

(ert-deftest calendar-date-select-in-calendar-window ()
  "RET in the calendar sets the date on the line that opened it."
  (calendar-date-test--with-calendar-cleanup
    (altodo-test-with-buffer "[ ] a\n"
      (let ((source (current-buffer)))
        (altodo-select-due-calendar)
        (with-current-buffer calendar-buffer
          (should (eq (lookup-key (current-local-map) (kbd "RET"))
                      #'altodo-calendar-pick-date))
          (calendar-goto-date '(3 20 2026))
          (altodo-calendar-pick-date))
        (should (equal (with-current-buffer source (buffer-string))
                       "[ ] a -> 2026-03-20\n"))))))

(ert-deftest calendar-date-select-start-in-calendar-window ()
  "The start command sets `DATE ->'."
  (calendar-date-test--with-calendar-cleanup
    (altodo-test-with-buffer "[ ] a\n"
      (let ((source (current-buffer)))
        (altodo-select-start-calendar)
        (with-current-buffer calendar-buffer
          (calendar-goto-date '(1 2 2026))
          (altodo-calendar-pick-date))
        (should (equal (with-current-buffer source (buffer-string))
                       "[ ] a 2026-01-02 ->\n"))))))

(ert-deftest calendar-date-calendar-uses-the-week-start-day ()
  "The calendar starts the week on `altodo-week-start-day'."
  (calendar-date-test--with-calendar-cleanup
    (altodo-test-with-buffer "[ ] a\n"
      (let ((altodo-week-start-day 1))
        (altodo-select-due-calendar)
        (with-current-buffer calendar-buffer
          (should (= calendar-week-start-day 1))
          (goto-char (point-min))
          (should (search-forward "Mo Tu We Th Fr Sa Su" nil t)))))))

(ert-deftest calendar-date-calendar-opens-at-the-existing-date ()
  "The cursor starts at the date already on the line."
  (calendar-date-test--with-calendar-cleanup
    (altodo-test-with-buffer "[ ] a -> 2026-05-06\n"
      (altodo-select-due-calendar)
      (with-current-buffer calendar-buffer
        (should (equal (calendar-cursor-to-date) '(5 6 2026)))))))

(ert-deftest calendar-date-quit-leaves-the-line-unchanged ()
  "Leaving the calendar with q changes nothing."
  (calendar-date-test--with-calendar-cleanup
    (altodo-test-with-buffer "[ ] a\n"
      (let ((source (current-buffer)))
        (altodo-select-due-calendar)
        (with-current-buffer calendar-buffer (calendar-exit))
        (should (equal (with-current-buffer source (buffer-string)) "[ ] a\n"))))))

(ert-deftest calendar-date-key-bindings ()
  "The calendar commands are on `C-c C-e d' and `C-c C-e s'."
  (altodo-test-with-buffer "[ ] a\n"
    (should (commandp (lookup-key altodo-mode-map (kbd "C-c C-e d"))))
    (should (commandp (lookup-key altodo-mode-map (kbd "C-c C-e s"))))))

(provide 'calendar-date-test)
;;; calendar-date-test.el ends here
