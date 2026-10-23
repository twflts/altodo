;;; sidebar-help-test.el --- Tests for the help of the altodo sidebar  -*- lexical-binding: t; -*-

;;; Commentary:
;; T20261018-89: `?' and `h' in the sidebar show the key bindings.

;;; Code:

(require 'ert)
(require 'altodo)

(ert-deftest sidebar-help-keys-are-bound ()
  "`?' and `h' run `altodo-sidebar-help' in the sidebar map."
  (should (eq (lookup-key altodo-sidebar-mode-map (kbd "?")) 'altodo-sidebar-help))
  (should (eq (lookup-key altodo-sidebar-mode-map (kbd "h")) 'altodo-sidebar-help)))

(ert-deftest sidebar-help-lists-every-binding ()
  "The help text lists the command of every key of the sidebar map."
  (let ((buffer-name "*altodo-sidebar-help*"))
    (save-window-excursion
      (altodo-sidebar-help))
    (unwind-protect
        (with-current-buffer buffer-name
          (let ((text (buffer-string)))
            (dolist (command '(altodo-sidebar--apply-filter-at-point
                               altodo-filter-clear
                               altodo-sidebar-refresh
                               altodo-sidebar-hide
                               altodo-sidebar-toggle-selection
                               altodo-sidebar-set-and-mode
                               altodo-sidebar-set-or-mode
                               altodo-sidebar-toggle-combine-mode
                               altodo-sidebar-help))
              (should (string-match-p (regexp-quote (symbol-name command)) text)))
            (should (string-match-p "AND" text))))
      (kill-buffer buffer-name))))

(provide 'sidebar-help-test)
;;; sidebar-help-test.el ends here
