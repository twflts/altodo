;;; sidebar-buffer-refresh-test.el --- Tests for refreshing from the sidebar and the source -*- lexical-binding: t; -*-

(require 'ert)
(require 'altodo)

;;; Test 1: altodo-sidebar--get-face with current-buffer in sidebar

(ert-deftest altodo-test-sidebar-buffer-mcp-sidebar-get-face-current-buffer ()
  "Test altodo-sidebar--get-face uses current-buffer correctly in sidebar."
  (let ((source-buffer (generate-new-buffer "test.altodo")))
    (unwind-protect
        (with-current-buffer source-buffer
          (altodo-mode)
          (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer)))
            (with-current-buffer sidebar-buffer
              (setq-local altodo-sidebar--selection-mode 'multiple)
              (setq-local altodo-sidebar--selected-filters 
                          '((:title "Open" :pattern "state:open")))
              (setq-local altodo-sidebar--active-entries nil)
              
              ;; Test that altodo-sidebar--get-face returns correct face
              (let ((entry '(:title "Open" :pattern "state:open")))
                (should (eq (altodo-sidebar--get-face entry nil) 
                           'altodo-sidebar-selected-filter-face))))
            
            (when (buffer-live-p sidebar-buffer)
              (kill-buffer sidebar-buffer))))
      (when (buffer-live-p source-buffer)
        (kill-buffer source-buffer)))))

;;; Test 2: altodo-sidebar-refresh from sidebar buffer

(ert-deftest altodo-test-sidebar-buffer-mcp-refresh-from-sidebar ()
  "Test altodo-sidebar-refresh works when called from sidebar buffer."
  (let ((source-buffer (generate-new-buffer "test.altodo")))
    (unwind-protect
        (with-current-buffer source-buffer
          (altodo-mode)
          (insert "[ ] Task 1\n")
          (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer)))
            (with-current-buffer sidebar-buffer
              (altodo-sidebar-refresh)
              (should (buffer-live-p sidebar-buffer)))
            
            (when (buffer-live-p sidebar-buffer)
              (kill-buffer sidebar-buffer))))
      (when (buffer-live-p source-buffer)
        (kill-buffer source-buffer)))))

;;; Test 3: altodo-sidebar-refresh from source buffer

(ert-deftest altodo-test-sidebar-buffer-mcp-refresh-from-source ()
  "Test altodo-sidebar-refresh works when called from source buffer."
  (let ((source-buffer (generate-new-buffer "test.altodo")))
    (unwind-protect
        (with-current-buffer source-buffer
          (altodo-mode)
          (insert "[ ] Task 1\n")
          (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer)))
            (altodo-sidebar-refresh)
            (should (buffer-live-p sidebar-buffer))
            
            (when (buffer-live-p sidebar-buffer)
              (kill-buffer sidebar-buffer))))
      (when (buffer-live-p source-buffer)
        (kill-buffer source-buffer)))))

;;; Test 4: Multiple buffers with independent face states

(ert-deftest altodo-test-sidebar-buffer-mcp-independent-face-states ()
  "Test multiple buffers have independent face states."
  (let ((buffer1 (generate-new-buffer "test1.altodo"))
        (buffer2 (generate-new-buffer "test2.altodo")))
    (unwind-protect
        (progn
          (with-current-buffer buffer1
            (altodo-mode)
            (insert "[ ] Task 1\n"))
          (let ((sidebar1 (altodo-sidebar--get-or-create-buffer buffer1)))
            (with-current-buffer sidebar1
              (setq-local altodo-sidebar--selection-mode 'multiple)
              (setq-local altodo-sidebar--selected-filters 
                          '((:title "Open" :pattern "state:open")))
              (setq-local altodo-sidebar--active-entries nil))
            
            (with-current-buffer buffer2
              (altodo-mode)
              (insert "[ ] Task 2\n"))
            (let ((sidebar2 (altodo-sidebar--get-or-create-buffer buffer2)))
              (with-current-buffer sidebar2
                (setq-local altodo-sidebar--selection-mode 'single)
                (setq-local altodo-sidebar--selected-filters nil)
                (setq-local altodo-sidebar--active-entries 
                            '((:title "Done" :pattern "state:done"))))
              
              (with-current-buffer sidebar1
                (should (eq altodo-sidebar--selection-mode 'multiple)))
              
              (with-current-buffer sidebar2
                (should (eq altodo-sidebar--selection-mode 'single)))
              
              (when (buffer-live-p sidebar1)
                (kill-buffer sidebar1))
              (when (buffer-live-p sidebar2)
                (kill-buffer sidebar2))))
      
      (when (buffer-live-p buffer1)
        (kill-buffer buffer1))
      (when (buffer-live-p buffer2)
        (kill-buffer buffer2)))))

;;; Test 5: altodo-sidebar--get-face with active-entries

(ert-deftest altodo-test-sidebar-buffer-mcp-sidebar-get-face-active ()
  "Test altodo-sidebar--get-face with active-entries."
  (let ((source-buffer (generate-new-buffer "test.altodo")))
    (unwind-protect
        (with-current-buffer source-buffer
          (altodo-mode)
          (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer)))
            (with-current-buffer sidebar-buffer
              (setq-local altodo-sidebar--selection-mode 'single)
              (setq-local altodo-sidebar--selected-filters nil)
              (setq-local altodo-sidebar--active-entries 
                          '((:title "Done" :pattern "state:done")))
              
              (let ((entry '(:title "Done" :pattern "state:done")))
                (should (eq (altodo-sidebar--get-face entry nil) 
                           'altodo-sidebar-active-filter-face))))
            
            (when (buffer-live-p sidebar-buffer)
              (kill-buffer sidebar-buffer))))
      (when (buffer-live-p source-buffer)
        (kill-buffer source-buffer)))))

;;; Test 6: altodo-sidebar--get-face with no selection

(ert-deftest altodo-test-sidebar-buffer-mcp-sidebar-get-face-default ()
  "Test altodo-sidebar--get-face returns default face when no selection."
  (let ((source-buffer (generate-new-buffer "test.altodo")))
    (unwind-protect
        (with-current-buffer source-buffer
          (altodo-mode)
          (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer)))
            (with-current-buffer sidebar-buffer
              (setq-local altodo-sidebar--selection-mode nil)
              (setq-local altodo-sidebar--selected-filters nil)
              (setq-local altodo-sidebar--active-entries nil)
              
              (let ((entry '(:title "Open" :pattern "state:open" :type search-simple)))
                (let ((face (altodo-sidebar--get-face entry nil)))
                  (should (or (eq face 'altodo-sidebar-search-simple-face)
                             (facep face)))))))
            
            (when (buffer-live-p sidebar-buffer)
              (kill-buffer sidebar-buffer))))
      (when (buffer-live-p source-buffer)
        (kill-buffer source-buffer)))))

(provide 'sidebar-buffer-refresh-test)
;;; sidebar-buffer-refresh-test.el ends here
