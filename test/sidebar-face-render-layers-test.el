;;; sidebar-face-render-layers-test.el --- Faces of the drawn sidebar  -*- lexical-binding: t; -*-

;;; Commentary:

;; `sidebar-face-layer-test.el' checks the return value of
;; `altodo-sidebar--get-face'.  These tests draw the sidebar and read the
;; faces that the user sees (`get-char-property'; a button keeps its face in
;; the button category, so `get-text-property' returns nil).
;; Each test names the finding it covers (F1 to F9, O1 of the review in
;; `.claude/memo/examine/sidebar-face-layer-20261023/review.md').

;;; Code:

(add-to-list 'load-path (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defconst sidebar-face-render-text
  "# H\n[ ] a ! #t1 @p1 -> 2020-01-01\n[ ] b + #t1\n[x] c #t2\n[ ] d ! + @p2\n[ ] e\n[@] f\n"
  "Source text of the drawing tests: 4 open tasks, 2 of them tagged #t1.")

(defmacro sidebar-face-render-with-sidebar (vars &rest body)
  "Run BODY with (SOURCE SIDEBAR) bound to the buffers named in VARS."
  (declare (indent 1))
  `(let ((,(nth 0 vars) (generate-new-buffer "*face-src*")))
     (unwind-protect
         (progn
           (with-current-buffer ,(nth 0 vars)
             (insert sidebar-face-render-text)
             (altodo-mode))
           (let ((,(nth 1 vars)
                  (altodo-sidebar--get-or-create-buffer ,(nth 0 vars))))
             (with-current-buffer ,(nth 1 vars)
               (altodo-sidebar-mode)
               (setq altodo-sidebar--source-buffer ,(nth 0 vars)))
             ,@body))
       (when-let ((sidebar (altodo-sidebar--get-buffer ,(nth 0 vars))))
         (kill-buffer sidebar))
       (kill-buffer ,(nth 0 vars)))))

(defun sidebar-face-render-config (source sidebar entries)
  "Return a sidebar config of ENTRIES for SOURCE and SIDEBAR."
  (list :name (buffer-name sidebar) :source-buffer source :indent 2
        :position 'left :width 0.2 :entries entries))

(defun sidebar-face-render-rows (sidebar)
  "Return (TEXT TITLE-FACE COUNT-FACE) for each line of SIDEBAR.
TITLE-FACE is the face of the first character.  COUNT-FACE is the face
of the number at the end of the line, or nil."
  (with-current-buffer sidebar
    (let (rows)
      (goto-char (point-min))
      (while (not (eobp))
        (let* ((bol (line-beginning-position))
               (text (buffer-substring-no-properties bol (line-end-position)))
               (first (string-match "[^ ]" text))
               (digit (string-match "[0-9]+\\'" text)))
          (push (list text
                      (and first (get-char-property (+ bol first) 'face))
                      (and digit (get-char-property (+ bol digit) 'face)))
                rows))
        (forward-line 1))
      (nreverse rows))))

(defun sidebar-face-render-draw (entries &optional setup from-source)
  "Draw ENTRIES and return `sidebar-face-render-rows'.
SETUP is called with the source and sidebar buffers, the sidebar being
current, before the drawing.  With FROM-SOURCE, the drawing is called with
the source buffer current, as `altodo-sidebar-show' does."
  (sidebar-face-render-with-sidebar (source sidebar)
    (let ((config (sidebar-face-render-config source sidebar entries)))
      (when setup
        (with-current-buffer sidebar (funcall setup source sidebar)))
      (with-current-buffer (if from-source source sidebar)
        (altodo-sidebar--render sidebar config))
      (sidebar-face-render-rows sidebar))))

(defun sidebar-face-render-select (entries mode predicate-pattern)
  "Return a setup function that selects ENTRIES in MODE.
The combined predicate is compiled from PREDICATE-PATTERN in the source
buffer.  This sets the state through the variables, so it does not depend
on the function that changes the selection."
  (lambda (source _sidebar)
    (setq altodo-sidebar--selected-filters entries
          altodo-sidebar--selection-mode mode
          altodo-sidebar--combine-mode 'and
          altodo-sidebar--current-combined-predicate
          (and predicate-pattern
               (with-current-buffer source
                 (altodo--compile-simple-pattern predicate-pattern))))))


;;; Row face and count face

(ert-deftest sidebar-face-render-default-type-face ()
  "An entry without face settings has the face of its type."
  (let ((row (car (sidebar-face-render-draw
                   '((:title "Open" :type search-simple :pattern "open"))))))
    (should (eq (nth 1 row) 'altodo-sidebar-search-simple-face))))

(ert-deftest sidebar-face-render-face-rules-colour-row-and-count ()
  "`:face-rules' gives the row and the number the same face."
  (let ((row (car (sidebar-face-render-draw
                   '((:title "T1 - %n" :type search-simple :pattern "tag:t1"
                      :count-format t :face-rules ((>= 1 error))))))))
    (should (equal (car row) "T1 - 2"))
    (should (eq (nth 1 row) 'error))
    (should (eq (nth 2 row) 'error))))

(ert-deftest sidebar-face-render-face-rules-and-count-face-rules ()
  "`:count-face-rules' wins on the number, `:face-rules' on the rest."
  (let ((row (car (sidebar-face-render-draw
                   '((:title "T1 - %n" :type search-simple :pattern "tag:t1"
                      :count-format t
                      :face-rules ((>= 1 warning))
                      :count-face-rules ((>= 1 error))))))))
    (should (eq (nth 1 row) 'warning))
    (should (eq (nth 2 row) 'error))))

(ert-deftest sidebar-face-render-count-face-rules-only-colour-the-count ()
  "F1: `:count-face-rules' alone does not colour the whole title."
  (let ((row (car (sidebar-face-render-draw
                   '((:title "T1 - %n" :type search-simple :pattern "tag:t1"
                      :count-format t :count-face-rules ((>= 1 error))))))))
    (should (eq (nth 1 row) 'altodo-sidebar-search-simple-face))
    (should (eq (nth 2 row) 'error))))

(ert-deftest sidebar-face-render-face-count-only-colours-the-count ()
  "`:face-count' applies to the number only."
  (let ((row (car (sidebar-face-render-draw
                   '((:title "T1 - %n" :type search-simple :pattern "tag:t1"
                      :count-format t :face-count warning))))))
    (should (eq (nth 1 row) 'altodo-sidebar-search-simple-face))
    (should (eq (nth 2 row) 'warning))))

(ert-deftest sidebar-face-render-static-face ()
  "`:face' with a face name colours the row."
  (let ((row (car (sidebar-face-render-draw
                   '((:title "Open" :type search-simple :pattern "open"
                      :face bold))))))
    (should (eq (nth 1 row) 'bold))))

(defun sidebar-face-render-set-active (entry)
  "Mark ENTRY as the active entry of the current sidebar buffer."
  (setq-local altodo-sidebar--selected-filters (list entry)
              altodo-sidebar--selection-mode 'single))

(defconst sidebar-face-render-ruled-entry
  '(:title "T1 - %n" :type search-simple :pattern "tag:t1"
    :count-format t :face-rules ((>= 1 error))
    :count-face-rules ((>= 1 warning)))
  "An entry with both kinds of rules.")

(ert-deftest sidebar-face-render-selected-overrides-rules ()
  "A selected entry has a single face for the row and the number."
  (let ((row (car (sidebar-face-render-draw
                   (list sidebar-face-render-ruled-entry)
                   (sidebar-face-render-select
                    (list sidebar-face-render-ruled-entry) 'multiple nil)))))
    (should (eq (nth 1 row) 'altodo-sidebar-selected-filter-face))
    (should (eq (nth 2 row) 'altodo-sidebar-selected-filter-face))))

(ert-deftest sidebar-face-render-active-overrides-rules ()
  "An active entry has a single face for the row and the number."
  (let ((row (car (sidebar-face-render-draw
                   (list sidebar-face-render-ruled-entry)
                   (lambda (_source _sidebar)
                     (sidebar-face-render-set-active
                      sidebar-face-render-ruled-entry))))))
    (should (eq (nth 1 row) 'altodo-sidebar-active-filter-face))
    (should (eq (nth 2 row) 'altodo-sidebar-active-filter-face))))


;;; Count format

(ert-deftest sidebar-face-render-count-format-default-is-t ()
  "F9: `%n' is replaced when `:count-format' is not given."
  (let ((row (car (sidebar-face-render-draw
                   '((:title "T1 - %n" :type search-simple
                      :pattern "tag:t1"))))))
    (should (equal (car row) "T1 - 2"))))

(ert-deftest sidebar-face-render-count-format-nil-keeps-placeholder ()
  "`:count-format nil' leaves `%n' as it is."
  (let ((row (car (sidebar-face-render-draw
                   '((:title "T1 - %n" :type search-simple :pattern "tag:t1"
                      :count-format nil))))))
    (should (equal (car row) "T1 - %n"))))

(ert-deftest sidebar-face-render-face-rules-without-n-in-title ()
  "`:face-rules' is evaluated although the title has no `%n'."
  (let ((row (car (sidebar-face-render-draw
                   '((:title "T1" :type search-simple :pattern "tag:t1"
                      :face-rules ((>= 1 error))))))))
    (should (eq (nth 1 row) 'error))))


;;; Dynamic and heading entries

(ert-deftest sidebar-face-render-dynamic-keeps-rules ()
  "F2: a dynamic entry passes its rules to the expanded entries."
  (let ((rows (sidebar-face-render-draw
               '((:title "#%s - %n" :type dynamic :dynamic-type "tag"
                  :count-format t
                  :face-rules ((>= 2 error))
                  :count-face-rules ((>= 1 warning)))))))
    (should (equal (mapcar #'car rows) '("#t1 - 2" "#t2 - 1")))
    (should (eq (nth 1 (nth 0 rows)) 'error))
    (should (eq (nth 2 (nth 0 rows)) 'warning))
    (should (eq (nth 2 (nth 1 rows)) 'warning))))

(ert-deftest sidebar-face-render-dynamic-keeps-other-properties ()
  "F2: a dynamic entry passes its other properties to the expanded entries."
  (sidebar-face-render-with-sidebar (source _sidebar)
    (let ((expanded (altodo--expand-dynamic-filter
                     '(:title "#%s" :type dynamic :dynamic-type "tag"
                       :count-exclude-others nil :display-context all
                       :multiline-comment nil)
                     source)))
      (should (eq (plist-get (car expanded) :display-context) 'all))
      (should (plist-member (car expanded) :multiline-comment))
      (should (plist-member (car expanded) :count-exclude-others)))))

(ert-deftest sidebar-face-render-heading-keeps-rules ()
  "F2: a heading entry passes its rules to the expanded entries."
  (sidebar-face-render-with-sidebar (source _sidebar)
    (let ((expanded (altodo--expand-dynamic-filter
                     '(:title "%s" :type dynamic :dynamic-type "heading"
                       :face-rules ((>= 1 error)) :face bold)
                     source)))
      (unwind-protect
          (progn
            (should (equal (plist-get (car expanded) :face-rules)
                           '((>= 1 error))))
            (should (eq (plist-get (car expanded) :face) 'bold)))
        (altodo--release-heading-markers)))))


;;; Combined count

(ert-deftest sidebar-face-render-multiple-selection-count-in-title ()
  "The title counts the lines that match the combined predicate."
  (let ((rows (sidebar-face-render-draw
               '((:title "Open - %n" :type search-simple :pattern "open"
                  :count-format t))
               (sidebar-face-render-select nil 'multiple "tag:t1"))))
    (should (equal (car (car rows)) "Open - 2"))))

(ert-deftest sidebar-face-render-multiple-selection-count-for-rules ()
  "F5: the rules see the combined count, with or without `%n' in the title."
  (let ((rows (sidebar-face-render-draw
               '((:title "A - %n" :type search-simple :pattern "open"
                  :count-format t :face-rules ((>= 4 error)))
                 (:title "B" :type search-simple :pattern "open"
                  :count-format t :face-rules ((>= 4 error))))
               (sidebar-face-render-select nil 'multiple "tag:t1"))))
    (should (equal (car (nth 0 rows)) "A - 2"))
    (should-not (eq (nth 1 (nth 0 rows)) 'error))
    (should-not (eq (nth 1 (nth 1 rows)) 'error))))

(ert-deftest sidebar-face-render-combined-count-from-source-buffer ()
  "F6: the combined count is kept when the source buffer is current."
  (let ((rows (sidebar-face-render-draw
               '((:title "Open - %n" :type search-simple :pattern "open"
                  :count-format t))
               (sidebar-face-render-select nil 'multiple "tag:t1")
               t)))
    (should (equal (car (car rows)) "Open - 2"))))


;;; Face specs

(ert-deftest sidebar-face-render-face-spec-forms ()
  "F7: `:face' takes a face name, a list of names, a plist and a defface spec."
  (let ((rows (sidebar-face-render-draw
               '((:title "symbol" :type search-simple :pattern "open"
                  :face bold)
                 (:title "list" :type search-simple :pattern "open"
                  :face (bold error))
                 (:title "plist" :type search-simple :pattern "open"
                  :face (:foreground "red"))
                 (:title "defface" :type search-simple :pattern "open"
                  :face ((t (:foreground "red"))))))))
    (should (eq (nth 1 (nth 0 rows)) 'bold))
    (should (equal (nth 1 (nth 1 rows)) '(bold error)))
    (should (equal (nth 1 (nth 2 rows)) '(:foreground "red")))
    (should (equal (nth 1 (nth 3 rows)) '(:foreground "red")))))

(ert-deftest sidebar-face-render-face-rules-value-forms ()
  "F7: a rule value takes the same forms as `:face'."
  (let ((rows (sidebar-face-render-draw
               '((:title "plist %n" :type search-simple :pattern "open"
                  :count-format t :face-rules ((>= 0 (:foreground "red"))))
                 (:title "defface %n" :type search-simple :pattern "open"
                  :count-format t
                  :face-rules ((>= 0 ((t (:foreground "red"))))))))))
    (should (equal (nth 1 (nth 0 rows)) '(:foreground "red")))
    (should (equal (nth 1 (nth 1 rows)) '(:foreground "red")))))


;;; Invalid rules

(ert-deftest sidebar-face-rules-invalid-rule-is-skipped ()
  "F8: an invalid rule is skipped; the other entries are still drawn."
  (let ((rows (sidebar-face-render-draw
               '((:title "bad %n" :type search-simple :pattern "open"
                  :count-format t :face-rules ((>= "a" error)))
                 (:title "worse %n" :type search-simple :pattern "open"
                  :count-format t :face-rules foo)
                 (:title "good %n" :type search-simple :pattern "open"
                  :count-format t :face-rules ((>= 1 warning)))))))
    (should (= (length rows) 3))
    (should (eq (nth 1 (nth 2 rows)) 'warning))))

(ert-deftest sidebar-face-rules-invalid-rule-continues-with-next-rule ()
  "F8: the rules after an invalid rule are still evaluated."
  (should (eq (altodo--evaluate-face-rules
               '((>= "a" error) (foo 1 error) bar (>= 1 warning)) 3)
              'warning)))


;;; State changes

(ert-deftest sidebar-face-render-lambda-click-clears-multiple-selection ()
  "F3: clicking a `search-lambda' entry ends the multiple selection."
  (sidebar-face-render-with-sidebar (source sidebar)
    (let* ((e1 '(:title "Open - %n" :type search-simple :pattern "open"
                 :count-format t))
           (e2 '(:title "Done - %n" :type search-simple :pattern "done"
                 :count-format t))
           (el (list :title "Lam - %n" :type 'search-lambda
                     :pattern (lambda () (altodo--task-p)) :count-format t))
           (config (sidebar-face-render-config source sidebar (list e1 e2 el))))
      (cl-letf (((symbol-function 'altodo-sidebar-make-config)
                 (lambda (&optional _) config)))
        (with-current-buffer source
          (altodo-sidebar--toggle-filter-selection e1)
          (altodo-sidebar--toggle-filter-selection e2))
        (with-current-buffer sidebar
          (altodo-sidebar--apply-filter
           (with-temp-buffer (insert-button "x" 'sidebar-entry el)))))
      (let ((rows (sidebar-face-render-rows sidebar)))
        (should (eq (nth 1 (nth 0 rows))
                    (altodo-sidebar--default-face 'search-simple 0)))
        (should (eq (nth 1 (nth 2 rows))
                    'altodo-sidebar-active-filter-face))))))

(ert-deftest sidebar-face-render-filter-command-clears-selection ()
  "F4: a filter command ends the selection of the sidebar."
  (sidebar-face-render-with-sidebar (source sidebar)
    (let* ((e1 '(:title "Open - %n" :type search-simple :pattern "open"
                 :count-format t))
           (config (sidebar-face-render-config source sidebar (list e1))))
      (cl-letf (((symbol-function 'altodo-sidebar-make-config)
                 (lambda (&optional _) config)))
        (with-current-buffer source
          (altodo-sidebar--toggle-filter-selection e1)
          (altodo-filter-show-done-only)))
      (let ((rows (sidebar-face-render-rows sidebar)))
        (should (eq (nth 1 (nth 0 rows))
                    (altodo-sidebar--default-face 'search-simple 0)))))))

(ert-deftest sidebar-face-render-click-draws-once ()
  "O1: one click on a `search-simple' entry draws the sidebar once."
  (sidebar-face-render-with-sidebar (source sidebar)
    (let* ((entry '(:title "Open - %n" :type search-simple :pattern "open"
                    :count-format t))
           (config (sidebar-face-render-config source sidebar (list entry)))
           (draws 0))
      (cl-letf (((symbol-function 'altodo-sidebar-make-config)
                 (lambda (&optional _) config)))
        (advice-add 'altodo-sidebar--render :before
                    (lambda (&rest _) (setq draws (1+ draws)))
                    '((name . sidebar-face-render-count)))
        (unwind-protect
            (with-current-buffer sidebar
              (altodo-sidebar--apply-filter
               (with-temp-buffer (insert-button "x" 'sidebar-entry entry))))
          (advice-remove 'altodo-sidebar--render 'sidebar-face-render-count)))
      (should (= draws 1)))))


;;; Rows without a filter

(ert-deftest sidebar-face-render-non-clickable-rows ()
  "A group header, a comment and a separator have their type faces."
  (let ((rows (sidebar-face-render-draw
               '((:title "Group" :type group-header)
                 (:title "Note" :type comment :nest 1)
                 (:title "" :type separator)))))
    (should (eq (nth 1 (nth 0 rows)) 'altodo-sidebar-group-header-face))
    (should (eq (nth 1 (nth 1 rows)) 'altodo-sidebar-comment-face))
    (should (eq (nth 1 (nth 2 rows)) 'altodo-sidebar-separator-face))))

(ert-deftest sidebar-face-render-non-clickable-row-is-not-a-button ()
  "The row of a group header has no button; the row of a filter has one."
  (sidebar-face-render-with-sidebar (source sidebar)
    (with-current-buffer sidebar
      (altodo-sidebar--render
       sidebar (sidebar-face-render-config
                source sidebar
                '((:title "Group" :type group-header)
                  (:title "Open" :type search-simple :pattern "open"))))
      (goto-char (point-min))
      (should-not (button-at (point)))
      (should (get-text-property (point) 'read-only))
      (forward-line 1)
      (should (button-at (point))))))


;;; Selection state

(ert-deftest sidebar-face-render-entry-state ()
  "`altodo-sidebar--entry-state' tells a click from a multiple selection."
  (let ((entry '(:title "A" :type search-simple :pattern "open")))
    (with-temp-buffer
      (should-not (altodo-sidebar--entry-state entry))
      (setq altodo-sidebar--selected-filters (list entry)
            altodo-sidebar--selection-mode 'single)
      (should (eq (altodo-sidebar--entry-state entry) 'active))
      (setq altodo-sidebar--selection-mode 'multiple)
      (should (eq (altodo-sidebar--entry-state entry) 'selected))
      (should-not (altodo-sidebar--entry-state '(:title "B"))))))

(ert-deftest sidebar-face-render-toggle-after-click-starts-new-selection ()
  "The first entry chosen after a click does not join the clicked entry."
  (sidebar-face-render-with-sidebar (source sidebar)
    (let* ((e1 '(:title "Open" :type search-simple :pattern "open"))
           (e2 '(:title "Done" :type search-simple :pattern "done"))
           (config (sidebar-face-render-config source sidebar (list e1 e2))))
      (cl-letf (((symbol-function 'altodo-sidebar-make-config)
                 (lambda (&optional _) config)))
        (with-current-buffer sidebar
          (altodo-sidebar--apply-filter
           (with-temp-buffer (insert-button "x" 'sidebar-entry e1))))
        (with-current-buffer source
          (altodo-sidebar--toggle-filter-selection e2)))
      (with-current-buffer sidebar
        (should (equal altodo-sidebar--selected-filters (list e2)))
        (should (eq altodo-sidebar--selection-mode 'multiple))))))

(ert-deftest sidebar-face-render-clear-in-sidebar-removes-filter ()
  "`altodo-filter-clear' in the sidebar clears the filter of the source."
  (sidebar-face-render-with-sidebar (source sidebar)
    (let* ((entry '(:title "Open" :type search-simple :pattern "open"))
           (config (sidebar-face-render-config source sidebar (list entry))))
      (cl-letf (((symbol-function 'altodo-sidebar-make-config)
                 (lambda (&optional _) config)))
        (with-current-buffer sidebar
          (altodo-sidebar--apply-filter
           (with-temp-buffer (insert-button "x" 'sidebar-entry entry)))
          (should (buffer-local-value 'altodo--filter-overlays source))
          (altodo-filter-clear)))
      (should-not (buffer-local-value 'altodo--filter-overlays source))
      (should-not (buffer-local-value 'altodo-sidebar--selected-filters
                                      sidebar)))))

(ert-deftest sidebar-face-render-combine-mode-ignored-for-a-click ()
  "A click is not a multiple selection: AND/OR does not change the filter."
  (sidebar-face-render-with-sidebar (source sidebar)
    (let* ((entry '(:title "Open" :type search-simple :pattern "open"))
           (config (sidebar-face-render-config source sidebar (list entry))))
      (cl-letf (((symbol-function 'altodo-sidebar-make-config)
                 (lambda (&optional _) config)))
        (with-current-buffer sidebar
          (altodo-sidebar--apply-filter
           (with-temp-buffer (insert-button "x" 'sidebar-entry entry)))
          (should-not (altodo-sidebar--multiple-p))
          (altodo-sidebar-toggle-combine-mode)
          (should (eq altodo-sidebar--combine-mode 'and))
          (should (eq altodo-sidebar--selection-mode 'single)))))))


;;; Report of an invalid rule

(ert-deftest sidebar-face-rules-invalid-rule-is-reported-once ()
  "An invalid rule gives one message, however often it is evaluated."
  (let ((altodo--reported-face-rules nil)
        (messages nil))
    (cl-letf (((symbol-function 'message)
               (lambda (format &rest args)
                 (push (apply #'format format args) messages))))
      (dotimes (_ 3)
        (altodo--evaluate-face-rules '((>= "a" error)) 1)))
    (should (= (length messages) 1))
    (should (string-match-p "invalid face rule" (car messages)))))


;;; Kept counts

(defun sidebar-face-render-count-passes (body)
  "Return the number of passes over the buffer that BODY makes."
  (let ((passes 0))
    (advice-add 'altodo--count-matching-lines :before
                (lambda (&rest _) (setq passes (1+ passes)))
                '((name . sidebar-face-render-passes)))
    (unwind-protect (funcall body)
      (advice-remove 'altodo--count-matching-lines
                     'sidebar-face-render-passes))
    passes))

(ert-deftest sidebar-face-render-count-kept-while-buffer-is-the-same ()
  "O3: the second drawing of the same buffer does not count again."
  (sidebar-face-render-with-sidebar (source sidebar)
    (let ((config (sidebar-face-render-config
                   source sidebar
                   '((:title "Open - %n" :type search-simple :pattern "open")
                     (:title "T1 - %n" :type search-simple :pattern "tag:t1")))))
      (with-current-buffer sidebar
        (should (= (sidebar-face-render-count-passes
                    (lambda () (altodo-sidebar--render sidebar config)))
                   2))
        (should (= (sidebar-face-render-count-passes
                    (lambda () (altodo-sidebar--render sidebar config)))
                   0))
        (should (equal (mapcar #'car (sidebar-face-render-rows sidebar))
                       '("Open - 4" "T1 - 2")))))))

(ert-deftest sidebar-face-render-count-recomputed-after-edit ()
  "O3: an edit of the buffer makes the next drawing count again."
  (sidebar-face-render-with-sidebar (source sidebar)
    (let ((config (sidebar-face-render-config
                   source sidebar
                   '((:title "Open - %n" :type search-simple :pattern "open")))))
      (with-current-buffer sidebar (altodo-sidebar--render sidebar config))
      (with-current-buffer source
        (goto-char (point-max))
        (insert "[ ] g\n"))
      (with-current-buffer sidebar
        (altodo-sidebar--render sidebar config)
        (should (equal (car (car (sidebar-face-render-rows sidebar)))
                       "Open - 5"))))))

(ert-deftest sidebar-face-render-count-recomputed-on-another-day ()
  "O3: a count of dates is not kept over a change of the day."
  (sidebar-face-render-with-sidebar (source sidebar)
    (let ((config (sidebar-face-render-config
                   source sidebar
                   '((:title "Overdue - %n" :type search-simple
                      :pattern "due-date:overdue")))))
      (with-current-buffer sidebar
        (altodo-test-with-today 2020 1 1
          (altodo-sidebar--render sidebar config)
          (should (equal (car (car (sidebar-face-render-rows sidebar)))
                         "Overdue - 0")))
        (altodo-test-with-today 2020 1 2
          (altodo-sidebar--render sidebar config)
          (should (equal (car (car (sidebar-face-render-rows sidebar)))
                         "Overdue - 1")))))))

(ert-deftest sidebar-face-render-count-of-lambda-not-kept ()
  "O3: the count of a function is computed at each drawing."
  (sidebar-face-render-with-sidebar (source sidebar)
    (let* ((flag nil)
           (config (sidebar-face-render-config
                    source sidebar
                    (list (list :title "Lam - %n" :type 'search-lambda
                                :pattern (lambda () (and flag (altodo--task-p))))))))
      (with-current-buffer sidebar
        (altodo-sidebar--render sidebar config)
        (should (equal (car (car (sidebar-face-render-rows sidebar)))
                       "Lam - 0"))
        (setq flag t)
        (altodo-sidebar--render sidebar config)
        (should (equal (car (car (sidebar-face-render-rows sidebar)))
                       "Lam - 6"))))))

(provide 'sidebar-face-render-layers-test)
;;; sidebar-face-render-layers-test.el ends here
