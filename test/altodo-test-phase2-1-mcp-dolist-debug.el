;;; altodo-test-phase2-1-mcp-dolist-debug.el --- Debug dolist execution -*- lexical-binding: t; -*-

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

;;; Test: Verify dolist is executed in altodo-sidebar--render

(ert-deftest altodo-test-phase2-1-mcp-dolist-execution ()
  "Test that dolist is executed in altodo-sidebar--render."
  (let ((test-file (altodo-test-file "testfiles/test-sample-project.altodo")))
    (should (file-exists-p test-file))
    
    (let ((buffer (find-file-noselect test-file)))
      (unwind-protect
          (with-current-buffer buffer
            (altodo-mode)
            
            ;; Enable debug mode to see all messages
            (let ((altodo-debug-mode t))
              (altodo-sidebar-show)
              
              (let ((sidebar-buffer (altodo-sidebar--get-buffer buffer)))
                (should (buffer-live-p sidebar-buffer))
                
                ;; Check sidebar buffer content
                (with-current-buffer sidebar-buffer
                  ;; Verify buffer has content (entries were inserted)
                  (should (> (buffer-size) 0))
                  
                  ;; Count buttons in sidebar
                  (let ((button-count 0)
                        (button (next-button (point-min))))
                    ;; The first entry is a group header (not a button), so
                    ;; walk from button to button.
                    (while button
                      (setq button-count (1+ button-count))
                      (setq button (next-button (button-end button))))
                    
                    ;; Should have at least some buttons
                    (should (> button-count 0))
                    (message "DEBUG test: found %d buttons in sidebar" button-count))))))
        
        ;; Cleanup
        (when (buffer-live-p buffer)
          (kill-buffer buffer))))))

(provide 'altodo-test-phase2-1-mcp-dolist-debug)
;;; altodo-test-phase2-1-mcp-dolist-debug.el ends here
