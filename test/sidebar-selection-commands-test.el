;;; sidebar-selection-commands-test.el --- Tests for the sidebar selection commands  -*- lexical-binding: t; -*-

;;; Commentary:
;; The commands that select filters and switch AND/OR must stop with a
;; message, instead of failing, when there is nothing to act on.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defmacro sidebar-selection-commands-test--recording (&rest body)
  "Run BODY with the toggle function and `message' recorded.
Bind `toggled' to the entries passed to the toggle function and `messages'
to the messages."
  (declare (indent 0))
  `(let (toggled messages)
     (cl-letf (((symbol-function 'altodo-sidebar--toggle-filter-selection)
                (lambda (entry) (push entry toggled)))
               ((symbol-function 'message)
                (lambda (format-string &rest args)
                  (push (apply #'format format-string args) messages))))
       ,@body)
     (list toggled messages)))

(ert-deftest sidebar-selection-commands-test-toggle-without-button ()
  (with-temp-buffer
    (insert "no filter here")
    (goto-char (point-min))
    (should (equal (sidebar-selection-commands-test--recording
                     (altodo-sidebar-toggle-selection))
                   '(nil ("No filter on this line"))))))

(ert-deftest sidebar-selection-commands-test-toggle-button-without-entry ()
  (with-temp-buffer
    (insert-button "Filter" 'action #'ignore)
    (goto-char (point-min))
    (should (equal (sidebar-selection-commands-test--recording
                     (altodo-sidebar-toggle-selection))
                   '(nil ("No filter entry at point"))))))

(ert-deftest sidebar-selection-commands-test-toggle-with-entry ()
  (let ((entry '(:title "Done" :type search-simple :pattern "done")))
    (with-temp-buffer
      (insert-button "Done" 'action #'ignore 'sidebar-entry entry)
      (goto-char (point-min))
      (should (equal (sidebar-selection-commands-test--recording
                       (altodo-sidebar-toggle-selection))
                     (list (list entry) nil))))))

(ert-deftest sidebar-selection-commands-test-mouse-toggle ()
  "A mouse click on a filter toggles it; elsewhere it only shows a message."
  (let ((entry '(:title "Done" :type search-simple :pattern "done"))
        (event (list 'mouse-1 (list (selected-window) 1 '(0 . 0) 0))))
    (with-temp-buffer
      (insert-button "Done" 'action #'ignore 'sidebar-entry entry)
      (should (equal (sidebar-selection-commands-test--recording
                       (altodo-sidebar-mouse-toggle-selection event))
                     (list (list entry) nil))))
    (with-temp-buffer
      (insert "no filter here")
      (should (equal (sidebar-selection-commands-test--recording
                       (altodo-sidebar-mouse-toggle-selection event))
                     '(nil ("No filter at point")))))
    (with-temp-buffer
      (insert-button "Filter" 'action #'ignore)
      (should (equal (sidebar-selection-commands-test--recording
                       (altodo-sidebar-mouse-toggle-selection event))
                     '(nil ("No filter entry at point")))))))

(ert-deftest sidebar-selection-commands-test-combine-mode-without-selection ()
  "Toggling AND/OR with no selected filter keeps the mode."
  (with-temp-buffer
    (setq-local altodo-sidebar--source-buffer (current-buffer)
                altodo-sidebar--selected-filters nil
                altodo-sidebar--combine-mode 'and)
    (let (messages applied)
      (cl-letf (((symbol-function 'message)
                 (lambda (format-string &rest args)
                   (push (apply #'format format-string args) messages)))
                ((symbol-function 'altodo-sidebar--apply-combined-filter)
                 (lambda () (setq applied t))))
        (altodo-sidebar-toggle-combine-mode))
      (should (eq altodo-sidebar--combine-mode 'and))
      (should-not applied)
      (should (equal messages '("No filters selected"))))))

(ert-deftest sidebar-selection-commands-test-combine-mode-with-selection ()
  (with-temp-buffer
    (setq-local altodo-sidebar--source-buffer (current-buffer)
                altodo-sidebar--selected-filters '((:title "Done"))
                altodo-sidebar--combine-mode 'and)
    (let (applied refreshed)
      (cl-letf (((symbol-function 'altodo-sidebar--apply-combined-filter)
                 (lambda () (setq applied t)))
                ((symbol-function 'altodo-sidebar-refresh)
                 (lambda () (setq refreshed t))))
        (altodo-sidebar-toggle-combine-mode)
        (should (eq altodo-sidebar--combine-mode 'or))
        (altodo-sidebar-toggle-combine-mode)
        (should (eq altodo-sidebar--combine-mode 'and)))
      (should applied)
      (should refreshed))))

(provide 'sidebar-selection-commands-test)
;;; sidebar-selection-commands-test.el ends here
