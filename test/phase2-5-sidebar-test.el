;;; phase2-5-sidebar-test.el --- Sidebar rendering test for Phase 2-5

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(ert-deftest test-sidebar-render-face-rules ()
  "Test sidebar rendering with face-rules."
  (altodo-test-with-locals
    (insert-file-contents (altodo-test-file "testfiles/test-flags.altodo"))
    (altodo-mode)
    
    ;; Enable debug mode
    (setq altodo-debug-mode t)
    
    ;; Create config
    (let ((config (altodo-sidebar-make-config (current-buffer))))
      ;; Create sidebar buffer
      (let ((sidebar-buf (get-buffer-create (plist-get config :name))))
        (with-current-buffer sidebar-buf
          ;; Render sidebar
          (altodo-sidebar--render sidebar-buf config)
          
          ;; Check if face-rules entry has face applied
          (goto-char (point-min))
          (let ((found nil))
            (while (not (eobp))
              (let ((line-text (buffer-substring (line-beginning-position) (line-end-position))))
                (when (string-match "Done (Color by Count)" line-text)
                  (setq found t)
                  ;; Check if face is applied
                  (let ((face (get-text-property (line-beginning-position) 'face)))
                    (message "Found 'Done (Color by Count)' with face: %s" face)
                    (should (not (null face))))))
              (forward-line 1))
            (should found)))))))

(provide 'phase2-5-sidebar-test)
;;; phase2-5-sidebar-test.el ends here
