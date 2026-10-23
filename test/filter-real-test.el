;;; filter-real-test.el --- Real-world test with filter-test.altodo

(require 'ert)
(require 'altodo)

(ert-deftest filter-real-test-filter-with-real-file ()
  "Test filtering with real altodo file."
  (with-temp-buffer
    (insert-file-contents "test/fixtures/filter-test.altodo")
    (altodo-mode)
    
    (message "=== Test 1: Show only done tasks ===")
    (altodo--filter-lines #'altodo--line-done-p)
    (message "Overlays created: %d" (length altodo--filter-overlays))
    (unless (> (length altodo--filter-overlays) 0)
      (error "Expected overlays for non-done tasks"))
    
    (message "=== Test 2: Clear filter ===")
    (altodo-filter-clear)
    (unless (= (length altodo--filter-overlays) 0)
      (error "Expected no overlays after clear"))
    
    (message "=== Test 3: Show only progress tasks ===")
    (altodo--filter-lines #'altodo--line-progress-p)
    (message "Overlays created: %d" (length altodo--filter-overlays))
    (unless (> (length altodo--filter-overlays) 0)
      (error "Expected overlays for non-progress tasks"))
    
    (message "=== Test 4: Clear filter ===")
    (altodo-filter-clear)
    
    (message "=== Test 5: Show tasks with @person tag ===")
    (altodo--filter-lines (lambda () (altodo--line-has-tag-p "person")))
    (message "Overlays created: %d" (length altodo--filter-overlays))
    (unless (> (length altodo--filter-overlays) 0)
      (error "Expected overlays for tasks without @person tag"))
    
    (message "=== Test 6: Clear filter ===")
    (altodo-filter-clear)
    
    (message "=== Test 7: Show priority tasks ===")
    (altodo--filter-lines #'altodo--line-has-priority-p)
    (message "Overlays created: %d" (length altodo--filter-overlays))
    (unless (> (length altodo--filter-overlays) 0)
      (error "Expected overlays for non-priority tasks"))
    
    (message "=== Test 8: Clear filter ===")
    (altodo-filter-clear)
    
    (message "=== All real-world tests passed ===")
    ))

(provide 'filter-real-test)
;;; filter-real-test.el ends here
