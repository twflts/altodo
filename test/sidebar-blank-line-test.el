;;; sidebar-blank-line-test.el --- Test for sidebar blank line issue

;;; Commentary:

;; Test to verify that sidebar buffer doesn't have trailing blank lines.

;;; Code:

(require 'ert)
(require 'altodo)

(ert-deftest sidebar-blank-line-test-no-trailing-blank ()
  "Test that sidebar buffer has no trailing blank line."
  (let* ((config (list :name "*altodo-sidebar*"
                       :position 'left
                       :width 30
                       :dedicated t
                       :indent 2
                       :entries '((:title "Entry 1" :type search-simple :pattern "test" :nest 0)
                                  (:title "Entry 2" :type search-simple :pattern "test" :nest 0)
                                  (:title "Entry 3" :type search-simple :pattern "test" :nest 0))))
         (buf (get-buffer-create "*test-sidebar*")))
    (unwind-protect
        (progn
          ;; Render sidebar
          (sidebar--render buf config)
          
          ;; Check buffer content
          (with-current-buffer buf
            ;; Get last character
            (let ((last-char (when (> (point-max) 1)
                               (char-before (point-max)))))
              ;; Last character should NOT be newline (10)
              (should-not (eq last-char ?\n))
              
              ;; Buffer should contain "Entry 3"
              (should (string-match "Entry 3" (buffer-string))))))
      
      ;; Cleanup
      (kill-buffer buf))))

(ert-deftest sidebar-blank-line-test-single-entry ()
  "Test that sidebar with single entry has no trailing blank line."
  (let* ((config (list :name "*altodo-sidebar*"
                       :position 'left
                       :width 30
                       :dedicated t
                       :indent 2
                       :entries '((:title "Only Entry" :type search-simple :pattern "test" :nest 0))))
         (buf (get-buffer-create "*test-sidebar-single*")))
    (unwind-protect
        (progn
          ;; Render sidebar
          (sidebar--render buf config)
          
          ;; Check buffer content
          (with-current-buffer buf
            ;; Get last character
            (let ((last-char (when (> (point-max) 1)
                               (char-before (point-max)))))
              ;; Last character should NOT be newline (10)
              (should-not (eq last-char ?\n))
              
              ;; Buffer should contain "Only Entry"
              (should (string-match "Only Entry" (buffer-string))))))
      
      ;; Cleanup
      (kill-buffer buf))))

(ert-deftest sidebar-blank-line-test-empty-buffer ()
  "Test that empty sidebar buffer is handled correctly."
  (let* ((config (list :name "*altodo-sidebar*"
                       :position 'left
                       :width 30
                       :dedicated t
                       :indent 2
                       :entries '()))
         (buf (get-buffer-create "*test-sidebar-empty*")))
    (unwind-protect
        (progn
          ;; Render sidebar
          (sidebar--render buf config)
          
          ;; Check buffer content
          (with-current-buffer buf
            ;; Buffer should be empty
            (should (= (point-max) 1))))
      
      ;; Cleanup
      (kill-buffer buf))))

(provide 'sidebar-blank-line-test)
;;; sidebar-blank-line-test.el ends here
