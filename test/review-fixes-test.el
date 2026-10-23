;;; review-fixes-test.el --- Tests for the fixes of the code review  -*- lexical-binding: t; -*-

;;; Commentary:
;; T20261023-1: fixes found by the review of altodo.el.  B1 is the time of the
;; fontification, B2 the #done tag with a format, B3 the heading of the done
;; file, B8 `:count-exclude-others', B12 `read-eval', B13 the markers of the
;; heading entries, P1 the redraw of the sidebar after a save.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

;;; B1 Fontification

(ert-deftest review-fixes-fontify-many-root-tasks-is-fast ()
  "Fontifying root tasks does not search the parent up to the buffer start.
Before the fix, 3000 root tasks took about 19 seconds."
  (with-temp-buffer
    (dotimes (i 3000) (insert (format "[ ] task %d\n" i)))
    (altodo-mode)
    (font-lock-mode 1)
    (let ((start (float-time)))
      (font-lock-ensure)
      (should (< (- (float-time) start) 5)))))

(ert-deftest review-fixes-root-task-is-not-a-blocked-child ()
  "A task without indentation is never a blocked child of a seq-tasks task."
  (altodo-test-with-buffer "[ ] parent #seq-tasks\n    [ ] one\n    [ ] two\n[ ] root\n"
    (forward-line 2)
    (should (altodo--is-seq-tasks-child-blocked-p))
    (forward-line 1)
    (should-not (altodo--is-seq-tasks-child-blocked-p))))

;;; B2 The #done tag

(defun review-fixes--done-line (&optional format)
  "Return the line after `altodo--add-done-tag' with the #done FORMAT."
  (let ((altodo-done-tag-datetime-format format))
    (with-temp-buffer
      (insert "[x] a")
      (altodo--add-done-tag)
      (buffer-string))))

(ert-deftest review-fixes-done-tag-default-is-iso-8601-with-offset ()
  "Without a format the tag is ISO 8601 with the time zone offset."
  (should (string-match-p
           "\\`\\[x\\] a #done:[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}T[0-9:]\\{8\\}[+-][0-9]\\{2\\}:[0-9]\\{2\\}\\'"
           (review-fixes--done-line))))

(ert-deftest review-fixes-done-tag-with-format-has-no-offset ()
  "With a format the tag is the result of the format alone."
  (should (string-match-p "\\`\\[x\\] a #done:[0-9]\\{4\\}/[0-9]\\{2\\}/[0-9]\\{2\\}\\'"
                          (review-fixes--done-line "%Y/%m/%d"))))

(ert-deftest review-fixes-done-tag-utc-offset ()
  "In UTC the offset is +00:00."
  (let ((altodo-use-local-timezone nil))
    (should (string-suffix-p "+00:00" (review-fixes--done-line)))))

(ert-deftest review-fixes-done-tag-negative-half-hour-offset ()
  "The offset -00:30 keeps its sign."
  (let ((altodo-use-local-timezone t)
        (original (getenv "TZ")))
    (unwind-protect
        (progn
          (set-time-zone-rule "<-0030>0:30")
          (should (string-suffix-p "-00:30" (review-fixes--done-line))))
      (set-time-zone-rule original))))

(ert-deftest review-fixes-done-tag-with-space-is-quoted ()
  "A format whose result has a space gives a quoted value, a valid tag."
  (let ((line (review-fixes--done-line "%Y-%m-%d %H:%M:%S")))
    (should (string-match-p
             "\\`\\[x\\] a #done:\"[0-9-]+ [0-9:]+\"\\'" line))
    (with-temp-buffer
      (insert line)
      (should (string-match-p "\\`[0-9]\\{4\\}-[0-9-]+ [0-9:]+\\'"
                              (altodo--line-done-tag-value)))
      (altodo--remove-done-tag)
      (should (equal (buffer-string) "[x] a")))))

(ert-deftest review-fixes-done-tag-is-not-added-twice ()
  "A line that ends with a quoted #done tag gets no second tag."
  (let ((altodo-done-tag-datetime-format "%Y-%m-%d %H:%M"))
    (with-temp-buffer
      (insert "[x] a")
      (altodo--add-done-tag)
      (let ((once (buffer-string)))
        (altodo--add-done-tag)
        (should (equal (buffer-string) once))))))

;;; B3 The heading of the done file

(ert-deftest review-fixes-done-file-heading-is-not-a-prefix-match ()
  "A task of `# Work' is not put under `# Workshop' of the done file."
  (altodo-test-with-temp-dir dir
    (let ((file (expand-file-name "todo.altodo" dir))
          (done (expand-file-name "todo_done.altodo" dir)))
      (with-temp-file file (insert "# Work\n[x] job\n"))
      (with-temp-file done (insert "# Workshop\n[x] old\n"))
      (let ((buffer (find-file-noselect file)))
        (unwind-protect
            (with-current-buffer buffer
              (altodo-mode)
              (goto-char (point-min))
              (search-forward "job")
              (let ((inhibit-message t))
                (altodo-move-done-tasks-at-point))
              (with-temp-buffer
                (insert-file-contents done)
                (should (equal (buffer-string)
                               "# Workshop\n[x] old\n\n# Work\n\n[x] job\n"))))
          (with-current-buffer buffer (set-buffer-modified-p nil))
          (kill-buffer buffer))))))

(ert-deftest review-fixes-done-file-heading-with-trailing-space-matches ()
  "A trailing space of the heading does not make a second section."
  (altodo-test-with-temp-dir dir
    (let ((file (expand-file-name "todo.altodo" dir))
          (done (expand-file-name "todo_done.altodo" dir)))
      (with-temp-file file (insert "# Work \n[x] job\n"))
      (with-temp-file done (insert "# Work\n[x] old\n"))
      (let ((buffer (find-file-noselect file)))
        (unwind-protect
            (with-current-buffer buffer
              (altodo-mode)
              (goto-char (point-min))
              (search-forward "job")
              (let ((inhibit-message t))
                (altodo-move-done-tasks-at-point))
              (with-temp-buffer
                (insert-file-contents done)
                (should (equal (buffer-string) "# Work\n[x] old\n[x] job\n"))))
          (with-current-buffer buffer (set-buffer-modified-p nil))
          (kill-buffer buffer))))))

;;; B8 :count-exclude-others

(ert-deftest review-fixes-count-exclude-others-nil-counts-comments ()
  "`:count-exclude-others nil' counts the other lines too."
  (altodo-test-with-buffer "[ ] a #t\n/// note #t\n"
    (let ((entry '(:title "x" :type search-simple :pattern "tag:t")))
      (should (= (altodo--get-entry-count entry (current-buffer)) 1))
      (should (= (altodo--get-entry-count
                  (append entry '(:count-exclude-others t)) (current-buffer))
                 1))
      (should (= (altodo--get-entry-count
                  (append entry '(:count-exclude-others nil)) (current-buffer))
                 2)))))

;;; B12 read-eval

(ert-deftest review-fixes-locals-file-does-not-evaluate-read-syntax ()
  "`#.(...)' in .altodo-locals.el is not evaluated, even if `read-eval' is t."
  (defvar review-fixes--pwned)
  (setq review-fixes--pwned nil)
  (altodo-test-with-temp-dir dir
    (with-temp-file (expand-file-name ".altodo-locals.el" dir)
      (insert "((altodo-sidebar-indent . #.(setq review-fixes--pwned t)))\n"))
    (with-temp-buffer
      (setq buffer-file-name (expand-file-name "todo.altodo" dir))
      (let ((read-eval t)
            (altodo--locals-cache nil)
            (warning-minimum-level :emergency))
        (should-not (altodo--load-locals-file))))
    (should-not review-fixes--pwned)))

;;; P1 The locals file is read once

(ert-deftest review-fixes-locals-file-is-cached-until-it-changes ()
  "The file is read again only when it changes."
  (altodo-test-with-temp-dir dir
    (let ((file (expand-file-name ".altodo-locals.el" dir))
          (reads 0)
          (altodo--locals-cache nil))
      (with-temp-file file (insert "((altodo-sidebar-indent . 3))\n"))
      (with-temp-buffer
        (setq buffer-file-name (expand-file-name "todo.altodo" dir))
        (cl-letf* ((original (symbol-function 'altodo--read-locals-file))
                   ((symbol-function 'altodo--read-locals-file)
                    (lambda (f) (setq reads (1+ reads)) (funcall original f))))
          (should (equal (altodo--get-locals-value 'altodo-sidebar-indent) 3))
          (should (equal (altodo--get-locals-value 'altodo-sidebar-indent) 3))
          (should (= reads 1))
          (with-temp-file file (insert "((altodo-sidebar-indent . 4))\n"))
          (should (equal (altodo--get-locals-value 'altodo-sidebar-indent) 4))
          (should (= reads 2))
          (delete-file file)
          (should-not (altodo--load-locals-file)))))))

;;; P1 The count is computed once for each entry in a drawing

(ert-deftest review-fixes-entry-count-is-shared-by-title-and-face ()
  "An entry with `:face-rules' is counted once in a drawing."
  (let ((source (generate-new-buffer " review-source"))
        (sidebar (generate-new-buffer " review-sidebar"))
        (scans 0))
    (unwind-protect
        (progn
          (with-current-buffer source (insert "[ ] a\n[ ] b\n") (altodo-mode))
          (cl-letf* ((original (symbol-function 'altodo--count-matching-lines))
                     ((symbol-function 'altodo--count-matching-lines)
                      (lambda (&rest args)
                        (setq scans (1+ scans))
                        (apply original args))))
            (altodo-sidebar--render
             sidebar
             (list :entries '((:title "Open - %n" :type search-simple
                                      :pattern "open" :count-format t
                                      :face-rules ((>= 1 error))))
                   :indent 2 :source-buffer source)))
          (should (= scans 1))
          (with-current-buffer sidebar
            (should (string-match-p "Open - 2" (buffer-string)))))
      (kill-buffer source)
      (kill-buffer sidebar))))

;;; P1 The redraw after a save

(ert-deftest review-fixes-save-redraws-only-a-shown-sidebar ()
  "A hidden sidebar is not drawn at a save; a shown one is."
  (let ((source (generate-new-buffer " review-source"))
        (sidebar (generate-new-buffer " review-sidebar"))
        (refreshed 0))
    (unwind-protect
        (with-current-buffer source
          (altodo-mode)
          (cl-letf (((symbol-function 'altodo--get-sidebar-buffer)
                     (lambda (&rest _) sidebar))
                    ((symbol-function 'altodo-sidebar-refresh)
                     (lambda () (setq refreshed (1+ refreshed)))))
            (cl-letf (((symbol-function 'get-buffer-window) (lambda (&rest _) nil)))
              (altodo--sidebar-refresh-after-save))
            (should (= refreshed 0))
            (cl-letf (((symbol-function 'get-buffer-window) (lambda (&rest _) 'window)))
              (altodo--sidebar-refresh-after-save))
            (should (= refreshed 1))
            (should (memq #'altodo--sidebar-refresh-after-save after-save-hook))))
      (kill-buffer source)
      (kill-buffer sidebar))))

;;; B10 The mode line string of the sidebar

(ert-deftest review-fixes-modeline-string-belongs-to-each-sidebar ()
  "Two sidebars show their own AND/OR mode, whichever buffer updates them."
  (let* ((first (generate-new-buffer " review-first"))
         (second (generate-new-buffer " review-second"))
         (sidebar-first (altodo-sidebar--get-or-create-buffer first))
         (sidebar-second (altodo-sidebar--get-or-create-buffer second)))
    (unwind-protect
        (progn
          (with-current-buffer sidebar-second
            (setq altodo-sidebar--combine-mode 'or))
          (with-current-buffer first (altodo--update-sidebar-modeline))
          (with-current-buffer second (altodo--update-sidebar-modeline))
          (should (string-match-p "\\[AND\\]"
                                  (buffer-local-value
                                   'altodo-sidebar-modeline-string
                                   sidebar-first)))
          (should (string-match-p "\\[OR\\]"
                                  (buffer-local-value
                                   'altodo-sidebar-modeline-string
                                   sidebar-second))))
      (altodo-sidebar--cleanup-buffer first)
      (altodo-sidebar--cleanup-buffer second)
      (kill-buffer first)
      (kill-buffer second))))

;;; B13 The markers of the heading entries

(ert-deftest review-fixes-heading-markers-are-released-at-redraw ()
  "The markers of the previous drawing are released when the sidebar is drawn."
  (let ((source (generate-new-buffer " review-source"))
        (sidebar (generate-new-buffer " review-sidebar")))
    (unwind-protect
        (progn
          (with-current-buffer source (insert "# A\n## B\n") (altodo-mode))
          (let ((config (list :entries '((:title "%s" :type dynamic
                                                 :dynamic-type "heading"))
                              :indent 2 :source-buffer source))
                old)
            (altodo-sidebar--render sidebar config)
            (setq old (with-current-buffer sidebar altodo--heading-markers))
            (should (= (length old) 2))
            (should (cl-every #'marker-buffer old))
            (altodo-sidebar--render sidebar config)
            (should-not (cl-some #'marker-buffer old))
            (should (= (length (with-current-buffer sidebar
                                 altodo--heading-markers))
                       2))))
      (kill-buffer source)
      (kill-buffer sidebar))))

(ert-deftest review-fixes-jump-after-clearing-the-filter-uses-the-position ()
  "The jump works when clearing the filter releases the marker of the entry."
  (let ((source (generate-new-buffer " review-source"))
        (sidebar (generate-new-buffer " review-sidebar")))
    (unwind-protect
        (save-window-excursion
          (switch-to-buffer source)
          (insert "# A\n[ ] t\n## B\n[ ] u\n")
          (altodo-mode)
          (setq-local altodo-sidebar--source-buffer nil)
          (let ((config (list :entries '((:title "%s" :type dynamic
                                                 :dynamic-type "heading"))
                              :indent 2 :source-buffer source)))
            (altodo-sidebar--render sidebar config)
            (let ((entry (with-current-buffer sidebar
                           (button-get (button-at 5)
                                       'sidebar-entry))))
              (altodo--filter-lines (lambda () (looking-at "\\[ \\] t")) t 'none)
              (cl-letf (((symbol-function 'altodo-sidebar-refresh)
                         (lambda ()
                           (with-current-buffer sidebar
                             (altodo--release-heading-markers)))))
                (goto-char (point-min))
                (altodo-sidebar--jump-to-heading entry source))
              (should (looking-at "## B")))))
      (kill-buffer source)
      (kill-buffer sidebar))))

(provide 'review-fixes-test)
;;; review-fixes-test.el ends here
