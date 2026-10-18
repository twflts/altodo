;;; phase2-5-debug-comprehensive.el --- Comprehensive debug test

(require 'ert)
(require 'altodo)

(ert-deftest test-face-rules-comprehensive-debug ()
  "Comprehensive debug test for face-rules."
  (with-temp-buffer
    (setq buffer-file-name "testfiles/test-flags.altodo")
    (insert-file-contents "testfiles/test-flags.altodo")
    (altodo-mode)
    
    (let ((config (altodo-sidebar-make-config (current-buffer))))
      (let ((entries (plist-get config :entries)))
        ;; Find "Done (Color by Count)" entry
        (let ((target-entry nil))
          (dolist (entry entries)
            (when (string= (plist-get entry :title) "Done (Color by Count) %n")
              (setq target-entry entry)))
          
          (should (not (null target-entry)))
          (message "=== TEST: Done (Color by Count) ===")
          (message "Entry: %s" (plist-get target-entry :title))
          (message "Type: %s" (plist-get target-entry :type))
          (message "Pattern: %s" (plist-get target-entry :pattern))
          (message "Count-format: %s" (plist-get target-entry :count-format))
          (message "Face-rules: %s" (plist-get target-entry :face-rules))
          
          ;; Test count
          (let ((count (altodo--get-entry-count target-entry (current-buffer))))
            (message "Count result: %d" count)
            (should (> count 0)))
          
          ;; Test face-rules evaluation
          (let ((count (altodo--get-entry-count target-entry (current-buffer)))
                (face-rules (plist-get target-entry :face-rules)))
            (message "Evaluating face-rules with count=%d" count)
            (let ((face (altodo--evaluate-face-rules face-rules count)))
              (message "Face result: %s" face)
              (should (not (null face)))))
          
          ;; Test sidebar--get-face
          (let ((face (sidebar--get-face target-entry config (current-buffer))))
            (message "sidebar--get-face result: %s" face)
            (should (not (null face))))
          
          ;; Test format-sidebar-title
          (let ((title (altodo--format-sidebar-title target-entry (current-buffer))))
            (message "format-sidebar-title result: %s" title)
            (should (string-match "[0-9]+" title))))))))

(provide 'phase2-5-debug-comprehensive)
;;; phase2-5-debug-comprehensive.el ends here
