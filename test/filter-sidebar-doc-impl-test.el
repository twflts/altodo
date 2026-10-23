;;; filter-sidebar-doc-impl-test.el --- Filter and sidebar behavior of the design document  -*- lexical-binding: t; -*-

;;; Commentary:

;; Each test covers a finding of
;; `.claude/memo/examine/filter-sidebar-doc-review-20261024/review.md'
;; (B1 to B9, S1 to S12), where the implementation did not do what
;; `doc/design-filter.md' says.

;;; Code:

(add-to-list 'load-path (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defun filter-sidebar-doc-visible-lines ()
  "Return the numbers of the lines of the current buffer that are visible."
  (let (lines)
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (unless (get-char-property (point) 'invisible)
          (push (line-number-at-pos) lines))
        (forward-line 1)))
    (nreverse lines)))

(defun filter-sidebar-doc-matches (text pattern)
  "Return the numbers of the lines of TEXT that match the DSL PATTERN."
  (altodo-test-with-buffer text
    (let ((predicate (altodo--compile-simple-pattern pattern))
          lines)
      (while (not (eobp))
        (when (funcall predicate)
          (push (line-number-at-pos) lines))
        (forward-line 1))
      (nreverse lines))))

(defmacro filter-sidebar-doc-with-messages (var &rest body)
  "Run BODY with the messages collected in VAR (a list, newest first)."
  (declare (indent 1))
  `(let ((,var nil))
     (cl-letf (((symbol-function 'message)
                (lambda (format &rest args)
                  (when format (push (apply #'format format args) ,var)))))
       ,@body)))


;;; B1, B2: size and position of the sidebar

(ert-deftest filter-sidebar-doc-display-action-size ()
  "B1: the size is passed to the side window."
  (let ((action (lambda (position size)
                  (cdr (altodo-sidebar--make-display-action
                        (list :position position :width size))))))
    (should (equal (alist-get 'window-width (funcall action 'left 0.2)) 0.2))
    (should (equal (alist-get 'window-width (funcall action 'right 30)) 30))
    (should (equal (alist-get 'window-height (funcall action 'below 0.3)) 0.3))
    (should (equal (alist-get 'window-height (funcall action 'above 8.0)) 8))
    (should-not (assq 'window-width (funcall action 'left nil)))))

(ert-deftest filter-sidebar-doc-display-action-sides ()
  "B2: above and below are the top and the bottom."
  (let ((side (lambda (position)
                (alist-get 'side (cdr (altodo-sidebar--make-display-action
                                       (list :position position :width 0.2)))))))
    (should (eq (funcall side 'left) 'left))
    (should (eq (funcall side 'right) 'right))
    (should (eq (funcall side 'above) 'top))
    (should (eq (funcall side 'below) 'bottom))))

(ert-deftest filter-sidebar-doc-sidebar-shown-with-size-and-position ()
  "B1, B2: the shown sidebar has the width or the height that is set."
  (save-window-excursion
    (delete-other-windows)
    (dolist (case '((left 30 window-total-width 30)
                    (above 5 window-total-height 5)))
      (let ((source (generate-new-buffer "*size-src*")))
        (unwind-protect
            (progn
              (set-window-buffer (selected-window) source)
              (with-current-buffer source
                (altodo-mode)
                (let ((altodo-sidebar-position (nth 0 case))
                      (altodo-sidebar-size (nth 1 case)))
                  (altodo-sidebar-show)))
              (let ((window (get-buffer-window
                             (altodo-sidebar--get-buffer source))))
                (should window)
                (should (= (funcall (nth 2 case) window) (nth 3 case)))
                (delete-window window)))
          (when-let ((sidebar (altodo-sidebar--get-buffer source)))
            (kill-buffer sidebar))
          (kill-buffer source))))))


;;; B3: :display-context

(ert-deftest filter-sidebar-doc-display-context-unknown-value ()
  "B3: an unknown value, such as (quote all), is heading-only, with a message."
  (let ((altodo--reported-messages nil))
    (filter-sidebar-doc-with-messages messages
      (should (eq (altodo--get-display-context-option
                   '(:display-context (quote all)))
                  'heading-only))
      (should (eq (altodo--get-display-context-option
                   '(:display-context (quote all)))
                  'heading-only))
      (should (= (length messages) 1))
      (should (string-match-p "display-context" (car messages))))
    (should (eq (altodo--get-display-context-option '(:display-context all))
                'all))
    (should (eq (altodo--get-display-context-option '(:display-context nil))
                'heading-only))
    (should (eq (altodo--get-display-context-option '(:title "x"))
                'heading-only))))

(ert-deftest filter-sidebar-doc-display-context-read-from-locals ()
  "B3: the value `all' of a file is kept; a quoted one is reported."
  (altodo-test-with-temp-dir dir
    (with-temp-file (expand-file-name ".altodo-locals.el" dir)
      (insert "((altodo-filter-patterns . (
 (:title \"A\" :type search-simple :pattern \"open\" :display-context all)
 (:title \"B\" :type search-simple :pattern \"open\" :display-context 'all))))"))
    (with-temp-buffer
      (setq buffer-file-name (expand-file-name "t.altodo" dir))
      (let ((altodo--reported-messages nil)
            (entries (altodo--get-filter-patterns)))
        (filter-sidebar-doc-with-messages messages
          (should (eq (altodo--get-display-context-option (nth 0 entries))
                      'all))
          (should (eq (altodo--get-display-context-option (nth 1 entries))
                      'heading-only))
          (should (= (length messages) 1)))))))


;;; B5, B6, B4: dynamic filters  (see also dynamic-collect-test.el)

(ert-deftest filter-sidebar-doc-default-exclusions-keep-similar-tags ()
  "B6: the default patterns list #idea and #deploy, and not #id and #dep."
  (altodo-test-with-buffer "[ ] A #id:1 #dep:1 #done:2026-01-01 #idea #deploy #java\n"
    (let* ((entry (seq-find (lambda (e) (equal (plist-get e :dynamic-type) "tag"))
                            altodo-default-filter-patterns))
           (titles (mapcar (lambda (e) (plist-get e :title))
                           (altodo--expand-dynamic-filter entry (current-buffer)))))
      (should (equal titles '("#deploy - %n" "#idea - %n" "#java - %n"))))))


;;; B7, B8: selection

(defmacro filter-sidebar-doc-with-sidebar (vars entries &rest body)
  "Run BODY with (SOURCE SIDEBAR) bound as in VARS for a sidebar of ENTRIES."
  (declare (indent 2))
  `(let ((,(nth 0 vars) (generate-new-buffer "*doc-src*")))
     (unwind-protect
         (progn
           (with-current-buffer ,(nth 0 vars)
             (insert "[ ] a #t1\n[x] b #t1\n[ ] c\n")
             (altodo-mode))
           (let* ((,(nth 1 vars) (altodo-sidebar--get-or-create-buffer
                                  ,(nth 0 vars)))
                  (config (list :name (buffer-name ,(nth 1 vars))
                                :source-buffer ,(nth 0 vars) :indent 2
                                :position 'left :width 0.2
                                :entries ,entries)))
             (with-current-buffer ,(nth 1 vars)
               (altodo-sidebar-mode)
               (setq altodo-sidebar--source-buffer ,(nth 0 vars)))
             (cl-letf (((symbol-function 'altodo-sidebar-make-config)
                        (lambda (&optional _) config)))
               ,@body)))
       (when-let ((sidebar (altodo-sidebar--get-buffer ,(nth 0 vars))))
         (kill-buffer sidebar))
       (kill-buffer ,(nth 0 vars)))))

(ert-deftest filter-sidebar-doc-mode-line-click-keeps-selection ()
  "B7: a click on [AND] switches to OR and keeps the multiple selection."
  (let ((e1 '(:title "Open" :type search-simple :pattern "open"))
        (e2 '(:title "T1" :type search-simple :pattern "tag:t1")))
    (filter-sidebar-doc-with-sidebar (source sidebar) (list e1 e2)
      (with-current-buffer source
        (altodo-sidebar--toggle-filter-selection e1)
        (altodo-sidebar--toggle-filter-selection e2)
        (should (equal (filter-sidebar-doc-visible-lines) '(1))))
      (with-current-buffer sidebar
        (altodo-sidebar--toggle-filter-mode nil)
        (should (eq altodo-sidebar--combine-mode 'or))
        (should (= (length altodo-sidebar--selected-filters) 2)))
      (with-current-buffer source
        (should (equal (filter-sidebar-doc-visible-lines) '(1 2 3)))))))

(ert-deftest filter-sidebar-doc-only-filters-can-be-selected ()
  "B8: a command entry is not selected and hides nothing."
  (let ((open '(:title "Open" :type search-simple :pattern "open"))
        (command '(:title "Clear" :type command :command altodo-filter-clear)))
    (filter-sidebar-doc-with-sidebar (source sidebar) (list open command)
      (filter-sidebar-doc-with-messages messages
        (with-current-buffer source
          (altodo-sidebar--toggle-filter-selection command)
          (should (equal (filter-sidebar-doc-visible-lines) '(1 2 3)))))
      (with-current-buffer sidebar
        (should-not altodo-sidebar--selected-filters)))))


;;; B9: entries that cannot be drawn

(defun filter-sidebar-doc-config (source sidebar entry)
  "Return a sidebar config for SOURCE and SIDEBAR with ENTRY between two headers."
  (list :name (buffer-name sidebar) :source-buffer source :indent 2
        :entries (list '(:title "before" :type group-header)
                       entry
                       '(:title "after" :type group-header))))


(ert-deftest filter-sidebar-doc-bad-entries-are-left-out ()
  "B9: an entry that cannot be drawn is left out, with one message."
  (let ((altodo--reported-messages nil)
        (bad (list (list :title "L %n" :type 'search-lambda
                         :pattern (lambda () (error "boom")))
                   '(:title "N" :type search-simple :pattern "open" :nest -1)
                   '(:title "%s" :type dynamic :dynamic-type "tag"
                     :exclude-tag "id")
                   '(:title "A" :type agenda :days "3"))))
    (dolist (entry bad)
      (filter-sidebar-doc-with-sidebar (source sidebar)
          (list '(:title "before" :type group-header)
                entry
                '(:title "after" :type group-header))
        (filter-sidebar-doc-with-messages messages
          (with-current-buffer sidebar
            (altodo-sidebar--render sidebar (filter-sidebar-doc-config source sidebar entry))
            (altodo-sidebar--render sidebar (filter-sidebar-doc-config source sidebar entry))
            (should (equal (split-string (buffer-string) "\n") '("before" "after")))
            (should (= (length messages) 1))
            (should (string-match-p "ignored the sidebar entry" (car messages)))))))))

;;; DSL

(ert-deftest filter-sidebar-doc-start-date-tomorrow ()
  "S1: start-date accepts tomorrow."
  (altodo-test-with-today 2026 3 10
    (let ((text "[ ] a 2026-03-11 ->\n[ ] b 2026-03-10 ->\n[ ] c 2026-03-12 ->\n"))
      (should (equal (filter-sidebar-doc-matches text "start-date:tomorrow")
                     '(1)))
      (should (equal (filter-sidebar-doc-matches text "start-date:not-yet")
                     '(1 3))))))

(ert-deftest filter-sidebar-doc-logic-without-operands ()
  "S8: a logic operator without operands has a clear message."
  (filter-sidebar-doc-with-messages messages
    (should-not (filter-sidebar-doc-matches "[ ] a\n" "and:"))
    (should (string-match-p "no operands" (car messages)))
    (should-not (string-match-p "args-out-of-range" (car messages)))))

(ert-deftest filter-sidebar-doc-heading-pattern-with-setext ()
  "S5: heading:REGEXP finds the tasks under a Setext heading."
  (let ((text "Title\n=====\n[ ] a\n\n# Other\n[ ] b\n\nSub\n---\n[ ] c\n"))
    (should (equal (filter-sidebar-doc-matches text "heading:Title") '(3)))
    (should (equal (filter-sidebar-doc-matches text "heading:Sub") '(10)))
    (should (equal (filter-sidebar-doc-matches text "heading:Other") '(6 10)))))

(ert-deftest filter-sidebar-doc-display-context-shows-setext-heading ()
  "S5: heading-only shows the title and the underline of a Setext heading."
  (altodo-test-with-buffer "Title\n=====\n[ ] a\n[x] b\n"
    (altodo--filter-lines (altodo--compile-simple-pattern "open") t
                          'heading-only)
    (should (equal (filter-sidebar-doc-visible-lines) '(1 2 3)))))

(defun filter-sidebar-doc-visible-after-filter (multiline context)
  "Return the visible lines after filtering `open' with MULTILINE and CONTEXT."
  (altodo-test-with-buffer "# H\n[ ] a\n    detail of a\n[x] b\n"
    (altodo--filter-lines (altodo--compile-simple-pattern "open") multiline
                          context)
    (filter-sidebar-doc-visible-lines)))

(ert-deftest filter-sidebar-doc-multiline-comment-follows-display-context ()
  "Without :multiline-comment, only `all' shows the multi-line comments."
  (should (equal (filter-sidebar-doc-visible-after-filter 'auto 'heading-only)
                 '(1 2)))
  (should (equal (filter-sidebar-doc-visible-after-filter 'auto nil) '(1 2)))
  (should (equal (filter-sidebar-doc-visible-after-filter 'auto 'none) '(2)))
  ;; The task after the comment (line 4) does not match.
  (should (equal (filter-sidebar-doc-visible-after-filter 'auto 'all)
                 '(1 2 3))))

(ert-deftest filter-sidebar-doc-multiline-comment-option-wins ()
  "An explicit :multiline-comment decides in every context."
  (should (equal (filter-sidebar-doc-visible-after-filter t 'heading-only)
                 '(1 2 3)))
  (should (equal (filter-sidebar-doc-visible-after-filter t 'none) '(2 3)))
  (should (equal (filter-sidebar-doc-visible-after-filter nil 'all) '(1 2))))

(ert-deftest filter-sidebar-doc-click-shows-comments-only-with-all ()
  "A click on an entry follows :display-context and :multiline-comment."
  (cl-flet ((visible (properties)
              (let ((entry (append '(:title "Open" :type search-simple
                                     :pattern "open")
                                   properties)))
                (filter-sidebar-doc-with-sidebar (source sidebar) (list entry)
                  (with-current-buffer source
                    (erase-buffer)
                    (insert "# H\n[ ] a\n    detail of a\n[x] b\n"))
                  (with-current-buffer sidebar
                    (altodo-sidebar--apply-filter
                     (with-temp-buffer (insert-button "x" 'sidebar-entry entry))))
                  (with-current-buffer source
                    (filter-sidebar-doc-visible-lines))))))
    (should (equal (visible nil) '(1 2)))
    (should (equal (visible '(:display-context all)) '(1 2 3)))
    (should (equal (visible '(:display-context none)) '(2)))
    (should (equal (visible '(:multiline-comment t)) '(1 2 3)))
    (should (equal (visible '(:display-context all :multiline-comment nil))
                   '(1 2)))))

(ert-deftest filter-sidebar-doc-show-overdue-leaves-out-finished-tasks ()
  "S12: altodo-filter-show-overdue does not show done and cancelled tasks."
  (altodo-test-with-today 2026 3 10
    (altodo-test-with-buffer
        "[ ] a -> 2026-03-01\n[x] b -> 2026-03-01\n[~] c -> 2026-03-01\n[ ] d -> 2026-03-20\n"
      (altodo-filter-show-overdue)
      (should (equal (filter-sidebar-doc-visible-lines) '(1))))))

(provide 'filter-sidebar-doc-impl-test)
;;; filter-sidebar-doc-impl-test.el ends here
