;;; sidebar-apply-filter-at-point-test.el --- Tests for sidebar--apply-filter-at-point

(require 'ert)
(require 'altodo)

(ert-deftest test-apply-filter-at-point-with-button ()
  "Test sidebar--apply-filter-at-point when button exists at point."
  (with-temp-buffer
    ;; Create a button with filter entry
    (let ((entry '(:title "Done" :type search-simple :pattern "done" :nest 0)))
      (insert-button "Done"
                     'action #'altodo-sidebar--apply-filter
                     'sidebar-entry entry)
      (goto-char (point-min))
      
      ;; Test - should not error
      (should (progn
                (sidebar--apply-filter-at-point)
                t)))))

(ert-deftest test-apply-filter-at-point-no-button ()
  "Test sidebar--apply-filter-at-point when no button at point."
  (with-temp-buffer
    (insert "No button here")
    (goto-char (point-min))
    
    ;; Test - should display message
    (should (progn
              (sidebar--apply-filter-at-point)
              t))))

(ert-deftest test-apply-filter-at-point-interactive ()
  "Test sidebar--apply-filter-at-point is interactive."
  (should (commandp 'sidebar--apply-filter-at-point)))

(provide 'sidebar-apply-filter-at-point-test)
;;; sidebar-apply-filter-at-point-test.el ends here
