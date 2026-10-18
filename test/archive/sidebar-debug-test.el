;;; sidebar-debug-test.el --- Debug test for sidebar

(require 'altodo)

;; Test 1: Load patterns
(message "=== Test 1: Load patterns ===")
(with-temp-buffer
  (setq buffer-file-name (expand-file-name "testfiles/test.altodo"))
  (let ((patterns (altodo--get-filter-patterns)))
    (message "Patterns count: %d" (length patterns))
    (dolist (p patterns)
      (message "  Pattern: title=%s type=%s pattern=%s nest=%s action=%s"
               (plist-get p :title)
               (plist-get p :type)
               (plist-get p :pattern)
               (plist-get p :nest)
               (plist-get p :action)))))

;; Test 2: Make config
(message "\n=== Test 2: Make config ===")
(with-temp-buffer
  (setq buffer-file-name (expand-file-name "testfiles/test.altodo"))
  (let ((config (altodo-sidebar-make-config)))
    (message "Config name: %s" (plist-get config :name))
    (message "Config position: %s" (plist-get config :position))
    (message "Config entries count: %d" (length (plist-get config :entries)))))

;; Test 3: Simulate button click
(message "\n=== Test 3: Simulate button click ===")
(with-temp-buffer
  (setq buffer-file-name (expand-file-name "testfiles/test.altodo"))
  (altodo-mode)
  (insert "[ ] Test task\n")
  (let* ((patterns (altodo--get-filter-patterns))
         (done-pattern (cl-find-if (lambda (p) (string= (plist-get p :title) "Done"))
                                   patterns)))
    (message "Done pattern: %S" done-pattern)
    (when done-pattern
      ;; Create a mock button
      (let ((button (make-button 1 2)))
        (button-put button 'sidebar-entry done-pattern)
        (message "Calling altodo-sidebar--apply-filter...")
        (altodo-sidebar--apply-filter button)))))

(message "\n=== Tests complete ===")

;;; sidebar-debug-test.el ends here
