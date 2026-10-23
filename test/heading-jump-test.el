;;; heading-jump-test.el --- Tests for the heading jump of the sidebar  -*- lexical-binding: t; -*-

;;; Commentary:
;; T20261019-1: the dynamic filter with `:dynamic-type "heading"' expands to
;; `heading-jump' entries.  Selecting one moves point to the heading.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defconst heading-jump-test--text
  (concat "# A\n"
          "[ ] a1\n"
          "[@] a2\n"
          "[x] a3\n"
          "## B\n"
          "[w] b1\n"
          "[~] b2\n"
          "### C\n"
          "[ ] c1\n"
          "    [ ] c1child\n")
  "Sample with three headings of levels 1, 2 and 3.")

(defun heading-jump-test--entry (&rest properties)
  "Return a heading dynamic filter entry with PROPERTIES added."
  (append properties (list :title "%s" :type 'dynamic :dynamic-type "heading")))

(defmacro heading-jump-test--with-source (text &rest body)
  "Run BODY in an `altodo-mode' buffer holding TEXT, as `source'."
  (declare (indent 1))
  `(let ((source (generate-new-buffer " heading-source")))
     (unwind-protect
         (progn (with-current-buffer source (insert ,text) (altodo-mode))
                ,@body)
       (kill-buffer source))))

(defun heading-jump-test--expand (source &rest properties)
  "Expand a heading entry with PROPERTIES for the buffer SOURCE."
  (altodo--expand-dynamic-filter (apply #'heading-jump-test--entry properties)
                                 source))

;;; Collecting headings

(ert-deftest heading-jump-collect-counts-open-tasks ()
  "A heading counts the tasks neither done nor cancelled up to the next heading."
  (altodo-test-with-buffer heading-jump-test--text
    (should (equal (altodo--collect-headings t)
                   '(("A" 1 1 2) ("B" 2 26 1) ("C" 3 45 2))))
    (should (equal (mapcar #'cadddr (altodo--collect-headings nil))
                   '(0 0 0)))))

(ert-deftest heading-jump-collect-skips-fenced-code ()
  "A line like a heading in a fenced code block is not a heading."
  (altodo-test-with-buffer "# Real\n```\n# not a heading\n```\n## Next\n"
    (should (equal (mapcar #'car (altodo--collect-headings nil))
                   '("Real" "Next")))))

(ert-deftest heading-jump-collect-setext ()
  "Setext headings are collected with their level."
  (altodo-test-with-buffer "One\n===\n[ ] t\nTwo\n---\n[ ] u\n[ ] v\n"
    (should (equal (mapcar (lambda (h) (list (car h) (cadr h) (nth 3 h)))
                           (altodo--collect-headings t))
                   '(("One" 1 1) ("Two" 2 2))))))

(ert-deftest heading-jump-collect-ignores-task-before-first-heading ()
  "Tasks before the first heading are not counted for any heading."
  (altodo-test-with-buffer "[ ] orphan\n# H\n[ ] t\n"
    (should (equal (altodo--collect-headings t) '(("H" 1 12 1))))))

;;; Expansion

(ert-deftest heading-jump-expand-entries ()
  "Each heading becomes a `heading-jump' entry with a marker."
  (heading-jump-test--with-source heading-jump-test--text
    (let ((entries (heading-jump-test--expand source)))
      (should (equal (mapcar (lambda (e) (plist-get e :title)) entries)
                     '("A" "B" "C")))
      (should (cl-every (lambda (e) (eq (plist-get e :type) 'heading-jump))
                        entries))
      (should (equal (mapcar (lambda (e) (marker-position (plist-get e :marker)))
                             entries)
                     '(1 26 45)))
      (should (eq (marker-buffer (plist-get (car entries) :marker)) source)))))

(ert-deftest heading-jump-expand-level ()
  "`:level' takes an integer or a list of integers."
  (heading-jump-test--with-source heading-jump-test--text
    (should (equal (mapcar (lambda (e) (plist-get e :title))
                           (heading-jump-test--expand source :level 2))
                   '("B")))
    (should (equal (mapcar (lambda (e) (plist-get e :title))
                           (heading-jump-test--expand source :level '(1 3)))
                   '("A" "C")))))

(ert-deftest heading-jump-expand-limit ()
  "`:limit' keeps the first headings; nil and 0 mean no limit."
  (heading-jump-test--with-source heading-jump-test--text
    (should (= (length (heading-jump-test--expand source :limit 2)) 2))
    (should (= (length (heading-jump-test--expand source :limit 0)) 3))
    (should (= (length (heading-jump-test--expand source :limit nil)) 3))
    (should (= (length (heading-jump-test--expand source)) 3))
    (should (= (length (heading-jump-test--expand source :limit 10)) 3))))

(ert-deftest heading-jump-expand-placeholders ()
  "`%s', `%l' and `%n' are replaced; `%n' only when :count-format is enabled."
  (heading-jump-test--with-source heading-jump-test--text
    (should (equal (mapcar (lambda (e) (plist-get e :title))
                           (heading-jump-test--expand
                            source :title "L%l %s (%n)"))
                   '("L1 A (2)" "L2 B (1)" "L3 C (2)")))
    (should (equal (plist-get (car (heading-jump-test--expand
                                    source :title "%s (%n)"
                                    :count-format nil))
                              :title)
                   "A (%n)"))))

(ert-deftest heading-jump-expand-heading-text-with-placeholder ()
  "A placeholder inside the heading text is kept as it is."
  (heading-jump-test--with-source "# 100%n %s\n[ ] t\n"
    (should (equal (plist-get (car (heading-jump-test--expand
                                    source :title "%s [%n]"))
                              :title)
                   "100%n %s [1]"))))

(ert-deftest heading-jump-expand-count-face ()
  "`:face-count' is applied to the count."
  (heading-jump-test--with-source heading-jump-test--text
    (let ((title (plist-get (car (heading-jump-test--expand
                                  source :title "%s %n" :face-count 'bold))
                            :title)))
      (should (equal title "A 2"))
      (should (eq (get-text-property 2 'face title) 'bold)))))

(ert-deftest heading-jump-expand-indent-by-level ()
  "`:indent-by-level' decides the nest of each heading."
  (heading-jump-test--with-source heading-jump-test--text
    (cl-flet ((nests (&rest properties)
                (mapcar (lambda (e) (plist-get e :nest))
                        (apply #'heading-jump-test--expand source properties))))
      (should (equal (nests) '(0 1 2)))
      (should (equal (nests :indent-by-level t) '(0 1 2)))
      (should (equal (nests :indent-by-level nil) '(0 0 0)))
      (should (equal (nests :indent-by-level 2) '(0 0 1)))
      (should (equal (nests :indent-by-level 3) '(0 0 0)))
      (should (equal (nests :indent-by-level 0) '(0 1 2)))
      (should (equal (nests :nest 1) '(1 2 3)))
      (should (equal (nests :nest 1 :indent-by-level 2) '(1 1 2))))))

(ert-deftest heading-jump-expand-dead-source ()
  "A killed source buffer gives no entries."
  (let ((source (generate-new-buffer " heading-dead")))
    (kill-buffer source)
    (should-not (heading-jump-test--expand source))))

(ert-deftest heading-jump-marker-follows-edits ()
  "The marker of an entry moves with the text inserted before the heading."
  (heading-jump-test--with-source heading-jump-test--text
    (let ((entry (nth 1 (heading-jump-test--expand source))))
      (with-current-buffer source
        (goto-char (point-min))
        (insert "new line\n"))
      (should (= (marker-position (plist-get entry :marker)) 35)))))

;;; Sidebar

(defun heading-jump-test--render (entries text)
  "Render ENTRIES for TEXT and return (SIDEBAR . SOURCE).  The caller kills both."
  (let ((source (generate-new-buffer " heading-source"))
        (sidebar (generate-new-buffer " heading-sidebar")))
    (with-current-buffer source (insert text) (altodo-mode))
    (altodo-sidebar--render
     sidebar (list :entries entries :indent 2 :source-buffer source))
    (cons sidebar source)))

(ert-deftest heading-jump-render-lines ()
  "The sidebar lists the headings with the indent of their level."
  (let* ((pair (heading-jump-test--render
                (list (heading-jump-test--entry :title "%s - %n"))
                heading-jump-test--text)))
    (unwind-protect
        (with-current-buffer (car pair)
          (should (equal (buffer-string)
                         "A - 2\n  B - 1\n    C - 2")))
      (kill-buffer (car pair))
      (kill-buffer (cdr pair)))))

(ert-deftest heading-jump-render-button ()
  "The entry is a button that has the `heading-jump' entry."
  (let ((pair (heading-jump-test--render (list (heading-jump-test--entry))
                                         heading-jump-test--text)))
    (unwind-protect
        (with-current-buffer (car pair)
          (let ((entry (button-get (button-at 1) 'sidebar-entry)))
            (should (eq (plist-get entry :type) 'heading-jump))
            (should (eq (button-get (button-at 1) 'face)
                        'altodo-sidebar-search-simple-face))))
      (kill-buffer (car pair))
      (kill-buffer (cdr pair)))))

(ert-deftest heading-jump-toggle-selection-is-refused ()
  "A heading entry cannot be added to the multiple selection."
  (let ((pair (heading-jump-test--render (list (heading-jump-test--entry))
                                         heading-jump-test--text)))
    (unwind-protect
        (with-current-buffer (car pair)
          (let ((entry (button-get (button-at 1) 'sidebar-entry)))
            (altodo-sidebar--toggle-filter-selection entry)
            (should-not altodo-sidebar--selected-filters)))
      (kill-buffer (car pair))
      (kill-buffer (cdr pair)))))

;;; Default patterns

(ert-deftest heading-jump-default-patterns-have-headings-after-people ()
  "The default patterns list the headings in a group after the people."
  (let* ((titles (mapcar (lambda (e) (plist-get e :title))
                         altodo-default-filter-patterns))
         (people (cl-position "People" titles :test #'equal))
         (headings (cl-position "Headings" titles :test #'equal))
         (entry (nth (+ headings 1) altodo-default-filter-patterns)))
    (should (and people headings (> headings people)))
    (should (equal (plist-get entry :dynamic-type) "heading"))
    (should (eq (plist-get (nth (+ headings 2) altodo-default-filter-patterns)
                           :type)
                'separator))))

(ert-deftest heading-jump-default-patterns-render ()
  "The default patterns show the headings of the source in the sidebar."
  (let ((pair (heading-jump-test--render altodo-default-filter-patterns
                                         heading-jump-test--text)))
    (unwind-protect
        (with-current-buffer (car pair)
          (should (string-match-p "^Headings$" (buffer-string)))
          (should (string-match-p "^    B - 1$" (buffer-string))))
      (kill-buffer (car pair))
      (kill-buffer (cdr pair)))))

;;; Jump

(defmacro heading-jump-test--with-jump (var text &rest body)
  "Bind VAR to the entries for TEXT, show the source in a window, run BODY.
`source' is bound to the source buffer."
  (declare (indent 2))
  `(heading-jump-test--with-source ,text
     (save-window-excursion
       (let ((,var (heading-jump-test--expand source)))
         ,@body))))

(ert-deftest heading-jump-moves-point-to-heading ()
  "The jump selects the source window and puts point on the heading."
  (heading-jump-test--with-jump entries heading-jump-test--text
    (switch-to-buffer source)
    (goto-char (point-min))
    (altodo-sidebar--jump-to-heading (nth 2 entries) source)
    (should (eq (current-buffer) source))
    (should (= (point) 45))
    (should (looking-at "### C"))))

(ert-deftest heading-jump-scrolls-heading-to-top ()
  "The heading is placed at the top of the window."
  (let ((text (concat (mapconcat (lambda (n) (format "[ ] t%d" n))
                                 (number-sequence 1 200) "\n")
                      "\n# Far\n[ ] last\n")))
    (heading-jump-test--with-jump entries text
      (switch-to-buffer source)
      (goto-char (point-min))
      (altodo-sidebar--jump-to-heading (car entries) source)
      (should (looking-at "# Far"))
      (should (= (window-start) (point))))))

(ert-deftest heading-jump-clears-filter-hiding-the-heading ()
  "When a filter hides the heading line, the filter is cleared first."
  (heading-jump-test--with-jump entries heading-jump-test--text
    (switch-to-buffer source)
    (with-current-buffer source
      (altodo--filter-lines
       (lambda () (looking-at "^\\[ \\] a1")) t 'none)
      (should (seq-some (lambda (o) (overlay-get o 'invisible))
                        (overlays-at (marker-position
                                      (plist-get (nth 1 entries) :marker))))))
    (altodo-sidebar--jump-to-heading (nth 1 entries) source)
    (should (= (point) 26))
    (should-not (seq-some (lambda (o) (overlay-get o 'invisible))
                          (overlays-at 26)))))

(ert-deftest heading-jump-keeps-filter-when-heading-is-visible ()
  "A filter that shows the heading line stays."
  (heading-jump-test--with-jump entries heading-jump-test--text
    (switch-to-buffer source)
    (with-current-buffer source
      (altodo--filter-lines (lambda () (looking-at "^#+ ")) t 'none))
    (altodo-sidebar--jump-to-heading (nth 1 entries) source)
    (should (= (point) 26))
    (should (with-current-buffer source
              (seq-some (lambda (o) (overlay-get o 'invisible))
                        (overlays-in (point-min) (point-max)))))))

(ert-deftest heading-jump-reports-removed-heading ()
  "When the heading was deleted, point stays and a message is shown."
  (heading-jump-test--with-jump entries heading-jump-test--text
    (switch-to-buffer source)
    (with-current-buffer source
      (goto-char 26)
      (delete-region (line-beginning-position) (line-beginning-position 2)))
    (goto-char (point-min))
    (let (shown)
      (cl-letf (((symbol-function 'message)
                 (lambda (format-string &rest args)
                   (setq shown (apply #'format format-string args)))))
        (altodo-sidebar--jump-to-heading (nth 1 entries) source))
      (should (string-match-p "no longer exists" shown))
      (should (= (point) 1)))))

(ert-deftest heading-jump-button-action ()
  "Activating the button of the sidebar jumps to the heading."
  (heading-jump-test--with-source heading-jump-test--text
    (save-window-excursion
      (switch-to-buffer source)
      (let ((sidebar (generate-new-buffer " heading-sidebar")))
        (unwind-protect
            (progn
              (altodo-sidebar--render
               sidebar (list :entries (list (heading-jump-test--entry
                                             :level 2))
                             :indent 2 :source-buffer source))
              (with-current-buffer sidebar
                (setq-local altodo-sidebar--source-buffer source)
                (altodo-sidebar--apply-filter (button-at 3)))
              (should (eq (current-buffer) source))
              (should (= (point) 26)))
          (kill-buffer sidebar))))))

(provide 'heading-jump-test)
;;; heading-jump-test.el ends here
