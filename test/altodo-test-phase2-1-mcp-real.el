;;; altodo-test-phase2-1-mcp-real.el --- MCP real file tests for Phase 2-1 -*- lexical-binding: t; -*-

(require 'ert)
(require 'altodo)

;;; Test 1: Load test-sample-project.altodo and show sidebar

(ert-deftest altodo-test-phase2-1-mcp-real-load-and-show ()
  "Test loading test-sample-project.altodo and showing sidebar."
  (let ((test-file "/work/emacs/altodo/testfiles/test-sample-project.altodo"))
    (should (file-exists-p test-file))
    
    (let ((buffer (find-file-noselect test-file)))
      (unwind-protect
          (with-current-buffer buffer
            (altodo-mode)
            ;; Show sidebar
            (altodo-sidebar-show)
            ;; Verify sidebar buffer exists
            (let ((sidebar-buffer (altodo-sidebar--get-buffer buffer)))
              (should (buffer-live-p sidebar-buffer))
              ;; Verify sidebar has content
              (with-current-buffer sidebar-buffer
                (should (> (buffer-size) 0)))))
        
        ;; Cleanup
        (when (buffer-live-p buffer)
          (kill-buffer buffer))))))

;;; Test 2: Sidebar buffer has correct structure

(ert-deftest altodo-test-phase2-1-mcp-real-sidebar-structure ()
  "Test sidebar buffer has correct structure."
  (let ((test-file "/work/emacs/altodo/testfiles/test-sample-project.altodo"))
    (should (file-exists-p test-file))
    
    (let ((buffer (find-file-noselect test-file)))
      (unwind-protect
          (with-current-buffer buffer
            (altodo-mode)
            (altodo-sidebar-show)
            (let ((sidebar-buffer (altodo-sidebar--get-buffer buffer)))
              (with-current-buffer sidebar-buffer
                ;; Verify sidebar has buffer-local variables
                (should (boundp 'altodo-sidebar--source-buffer))
                (should (boundp 'altodo-sidebar--selected-filters))
                (should (boundp 'altodo-sidebar--active-entries))
                (should (eq altodo-sidebar--source-buffer buffer)))))
        
        ;; Cleanup
        (when (buffer-live-p buffer)
          (kill-buffer buffer))))))

;;; Test 3: Multiple buffers with independent sidebars

(ert-deftest altodo-test-phase2-1-mcp-real-multiple-buffers ()
  "Test multiple buffers with independent sidebars."
  (let ((test-file "/work/emacs/altodo/testfiles/test-sample-project.altodo"))
    (should (file-exists-p test-file))
    
    ;; Create two different buffers
    (let ((buffer1 (generate-new-buffer "test1.altodo"))
          (buffer2 (generate-new-buffer "test2.altodo")))
      (unwind-protect
          (progn
            (with-current-buffer buffer1
              (altodo-mode)
              (altodo-sidebar-show))
            (let ((sidebar1 (altodo-sidebar--get-buffer buffer1)))
              (should (buffer-live-p sidebar1))
              
              (with-current-buffer buffer2
                (altodo-mode)
                (altodo-sidebar-show))
              (let ((sidebar2 (altodo-sidebar--get-buffer buffer2)))
                (should (buffer-live-p sidebar2))
                ;; Verify sidebars are different
                (should-not (eq sidebar1 sidebar2))
                ;; Verify each sidebar has correct source buffer
                (with-current-buffer sidebar1
                  (should (eq altodo-sidebar--source-buffer buffer1)))
                (with-current-buffer sidebar2
                  (should (eq altodo-sidebar--source-buffer buffer2))))))
        
        ;; Cleanup
        (when (buffer-live-p buffer1)
          (kill-buffer buffer1))
        (when (buffer-live-p buffer2)
          (kill-buffer buffer2))))))

(provide 'altodo-test-phase2-1-mcp-real)
;;; altodo-test-phase2-1-mcp-real.el ends here
