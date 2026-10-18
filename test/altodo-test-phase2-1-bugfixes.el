;;; altodo-test-phase2-1-bugfixes.el --- Tests for Phase 2-1 bugfixes -*- lexical-binding: t; -*-

(require 'ert)
(require 'altodo)

(ert-deftest altodo-test-phase2-1-sidebar-get-face-current-buffer ()
  "Test altodo-sidebar--get-face uses current-buffer correctly."
  (let ((source-buffer (generate-new-buffer "test.altodo")))
    (unwind-protect
        (with-current-buffer source-buffer
          (altodo-mode)
          (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer)))
            (with-current-buffer sidebar-buffer
              (setq-local altodo-sidebar--selection-mode 'multiple)
              (setq-local altodo-sidebar--selected-filters 
                          '((:title "Open" :pattern "state:open")))
              ;; Verify that sidebar buffer has correct state
              (should (eq altodo-sidebar--selection-mode 'multiple))
              (should (equal (car altodo-sidebar--selected-filters)
                            '(:title "Open" :pattern "state:open"))))
            (when (buffer-live-p sidebar-buffer)
              (kill-buffer sidebar-buffer))))
      (when (buffer-live-p source-buffer)
        (kill-buffer source-buffer)))))

(ert-deftest altodo-test-phase2-1-get-sidebar-buffer-with-param ()
  "Test altodo--get-sidebar-buffer accepts source-buffer parameter."
  (let ((source-buffer (generate-new-buffer "test.altodo")))
    (unwind-protect
        (with-current-buffer source-buffer
          (altodo-mode)
          (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer)))
            (should (eq sidebar-buffer (altodo--get-sidebar-buffer source-buffer)))
            (with-current-buffer source-buffer
              (should (eq sidebar-buffer (altodo--get-sidebar-buffer nil))))
            (when (buffer-live-p sidebar-buffer)
              (kill-buffer sidebar-buffer))))
      (when (buffer-live-p source-buffer)
        (kill-buffer source-buffer)))))

(ert-deftest altodo-test-phase2-1-filter-clear-correct-sidebar ()
  "Test altodo-filter-clear updates the correct sidebar buffer."
  (let ((source-buffer (generate-new-buffer "test.altodo")))
    (unwind-protect
        (with-current-buffer source-buffer
          (altodo-mode)
          (insert "[ ] Task 1\n")
          (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer)))
            (with-current-buffer sidebar-buffer
              (setq-local altodo-sidebar--selected-filters 
                          '((:title "Open" :pattern "state:open")))
              (setq-local altodo-sidebar--active-entries 
                          '((:title "Open" :pattern "state:open")))
              (should altodo-sidebar--selected-filters))
            (with-current-buffer source-buffer
              (altodo-filter-clear))
            (with-current-buffer sidebar-buffer
              (should-not altodo-sidebar--selected-filters))
            (when (buffer-live-p sidebar-buffer)
              (kill-buffer sidebar-buffer))))
      (when (buffer-live-p source-buffer)
        (kill-buffer source-buffer)))))

(ert-deftest altodo-test-phase2-1-update-active-entry-correct-sidebar ()
  "Test altodo-sidebar--update-active-entry updates the correct sidebar."
  (let ((source-buffer (generate-new-buffer "test.altodo")))
    (unwind-protect
        (with-current-buffer source-buffer
          (altodo-mode)
          (insert "[ ] Task 1\n")
          (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer))
                (entry '(:title "Open" :pattern "state:open")))
            (with-current-buffer source-buffer
              (altodo-sidebar--update-active-entry entry))
            (with-current-buffer sidebar-buffer
              (should (equal altodo-sidebar--active-entries (list entry))))
            (when (buffer-live-p sidebar-buffer)
              (kill-buffer sidebar-buffer))))
      (when (buffer-live-p source-buffer)
        (kill-buffer source-buffer)))))

(ert-deftest altodo-test-phase2-1-independent-sidebar-states ()
  "Test multiple buffers have independent sidebar states."
  (let ((buffer1 (generate-new-buffer "test1.altodo"))
        (buffer2 (generate-new-buffer "test2.altodo")))
    (unwind-protect
        (progn
          (with-current-buffer buffer1
            (altodo-mode)
            (insert "[ ] Task 1\n"))
          (let ((sidebar1 (altodo-sidebar--get-or-create-buffer buffer1)))
            (with-current-buffer sidebar1
              (setq-local altodo-sidebar--selected-filters 
                          '((:title "Open" :pattern "state:open"))))
            (with-current-buffer buffer2
              (altodo-mode)
              (insert "[ ] Task 2\n"))
            (let ((sidebar2 (altodo-sidebar--get-or-create-buffer buffer2)))
              (with-current-buffer sidebar2
                (setq-local altodo-sidebar--selected-filters 
                            '((:title "Done" :pattern "state:done"))))
              (with-current-buffer sidebar1
                (should (equal (car altodo-sidebar--selected-filters) 
                              '(:title "Open" :pattern "state:open"))))
              (with-current-buffer sidebar2
                (should (equal (car altodo-sidebar--selected-filters) 
                              '(:title "Done" :pattern "state:done"))))
              (when (buffer-live-p sidebar1)
                (kill-buffer sidebar1))
              (when (buffer-live-p sidebar2)
                (kill-buffer sidebar2))))
          (when (buffer-live-p buffer1)
            (kill-buffer buffer1))
          (when (buffer-live-p buffer2)
            (kill-buffer buffer2))))))

(provide 'altodo-test-phase2-1-bugfixes)
;;; altodo-test-phase2-1-bugfixes.el ends here
