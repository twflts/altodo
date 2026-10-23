;;; sidebar-face-rules-basic-test.el --- Tests for face-rules

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(ert-deftest test-face-rules-debug-basic ()
  "Debug test for face-rules basic functionality."
  (altodo-test-with-locals
    (insert-file-contents (altodo-test-file "testfiles/test-flags.altodo"))
    (altodo-mode)
    (let ((config (altodo-sidebar-make-config (current-buffer))))
      (let ((entries (plist-get config :entries)))
        ;; Find "Done (Color by Count)" entry
        (let ((target-entry nil))
          (dolist (entry entries)
            (when (string= (plist-get entry :title) "Done (Color by Count) %n")
              (setq target-entry entry)))
          
          (should (not (null target-entry)))
          (should (plist-get target-entry :face-rules))
          (should (plist-get target-entry :count-format))
          
          ;; Test format-sidebar-title
          (let ((title (altodo--format-sidebar-title target-entry (current-buffer))))
            (should (string-match "[0-9]+" title)))
          
          ;; Test altodo-sidebar--get-face
          (let ((face (altodo-sidebar--get-face target-entry config (current-buffer))))
            (should (not (null face)))))))))

(ert-deftest test-face-rules-debug-count-face-rules ()
  "Debug test for count-face-rules."
  (altodo-test-with-locals
    (insert-file-contents (altodo-test-file "testfiles/test-flags.altodo"))
    (altodo-mode)
    (let ((config (altodo-sidebar-make-config (current-buffer))))
      (let ((entries (plist-get config :entries)))
        ;; Find "Priority (Count Color)" entry
        (let ((target-entry nil))
          (dolist (entry entries)
            (when (string= (plist-get entry :title) "Priority (Count Color) %n")
              (setq target-entry entry)))
          
          (should (not (null target-entry)))
          (should (plist-get target-entry :count-face-rules))
          (should (plist-get target-entry :count-format))
          
          ;; Test format-sidebar-title
          (let ((title (altodo--format-sidebar-title target-entry (current-buffer))))
            (should (string-match "[0-9]+" title))
            ;; Check if count has face property
            (let ((pos (string-match "[0-9]" title)))
              (should (get-text-property pos 'face title)))))))))

(ert-deftest test-face-rules-debug-both ()
  "Debug test for both face-rules and count-face-rules."
  (altodo-test-with-locals
    (insert-file-contents (altodo-test-file "testfiles/test-flags.altodo"))
    (altodo-mode)
    (let ((config (altodo-sidebar-make-config (current-buffer))))
      (let ((entries (plist-get config :entries)))
        ;; Find "Star (Both Colors)" entry
        (let ((target-entry nil))
          (dolist (entry entries)
            (when (string= (plist-get entry :title) "Star (Both Colors) %n")
              (setq target-entry entry)))
          
          (should (not (null target-entry)))
          (should (plist-get target-entry :face-rules))
          (should (plist-get target-entry :count-face-rules))
          (should (plist-get target-entry :count-format))
          
          ;; Test format-sidebar-title
          (let ((title (altodo--format-sidebar-title target-entry (current-buffer))))
            (should (string-match "[0-9]+" title)))
          
          ;; Test altodo-sidebar--get-face
          (let ((face (altodo-sidebar--get-face target-entry config (current-buffer))))
            (should (not (null face)))))))))

(provide 'sidebar-face-rules-basic-test)
;;; sidebar-face-rules-basic-test.el ends here
