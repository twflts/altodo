;;; sidebar-face-layer-test.el --- Complex Layer interaction tests

(require 'ert)
(require 'altodo)

;;; Test 1: Selection mode overrides face-rules
(ert-deftest test-layer-selection-overrides-face-rules ()
  "Selection mode (Layer 1) overrides face-rules (Layer 2)."
  (with-temp-buffer
    (dotimes (_ 15) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done %n" :type search-simple :pattern "done"
                   :count-format t
                   :face-rules ((>= 10 face-high) (>= 1 face-mid)))))
      ;; Simulate selection mode
      (setq-local altodo-sidebar--selected-filters (list entry))
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer))
                  'altodo-sidebar-selected-filter-face)))))

(ert-deftest test-layer-active-overrides-face-rules ()
  "Active mode (Layer 1) overrides face-rules (Layer 2)."
  (with-temp-buffer
    (dotimes (_ 15) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done %n" :type search-simple :pattern "done"
                   :count-format t
                   :face-rules ((>= 10 face-high) (>= 1 face-mid)))))
      ;; Simulate active mode
      (setq-local altodo-sidebar--selected-filters (list entry)
                  altodo-sidebar--selection-mode 'single)
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer))
                  'altodo-sidebar-active-filter-face)))))

;;; Test 2: Face-rules overrides static face
(ert-deftest test-layer-face-rules-overrides-static-face ()
  "Face-rules (Layer 2) overrides static face (Layer 4)."
  (with-temp-buffer
    (dotimes (_ 15) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done %n" :type search-simple :pattern "done"
                   :count-format t
                   :face bold
                   :face-rules ((>= 10 face-high) (>= 1 face-mid)))))
      ;; face-rules should match (count=15 >= 10)
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer)) 'face-high)))))

;;; Test 3: Static face used when face-rules doesn't match
(ert-deftest test-layer-static-face-fallback ()
  "Static face (Layer 4) used when face-rules doesn't match."
  (with-temp-buffer
    (dotimes (_ 3) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done %n" :type search-simple :pattern "done"
                   :count-format t
                   :face bold
                   :face-rules ((>= 10 face-high)))))
      ;; face-rules doesn't match (count=3 < 10), should use :face
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer)) 'bold)))))

;;; Test 4: Default face used when no rules match and no static face
(ert-deftest test-layer-default-face-fallback ()
  "Default face (Layer 5) used when no rules match and no static face."
  (with-temp-buffer
    (dotimes (_ 3) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done %n" :type search-simple :pattern "done"
                   :count-format t
                   :face-rules ((>= 10 face-high)))))
      ;; face-rules doesn't match, no :face, should use default
      (let ((result (altodo-sidebar--get-face entry nil (current-buffer))))
        (should result)
        (should (not (eq result 'face-high)))))))

;;; Test 5: Complex scenario - all layers present
(ert-deftest test-layer-complex-all-layers ()
  "Complex scenario with all layers present."
  (with-temp-buffer
    (dotimes (_ 15) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done %n" :type search-simple :pattern "done"
                   :count-format t
                   :face bold
                   :face-rules ((>= 10 face-high) (>= 1 face-mid)))))
      ;; Without selection: face-rules should apply
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer)) 'face-high))
      
      ;; With selection: selection mode should override
      (setq-local altodo-sidebar--selected-filters (list entry))
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer))
                  'altodo-sidebar-selected-filter-face)))))

;;; Test 6: Face-rules with multiple conditions
(ert-deftest test-layer-face-rules-multiple-conditions ()
  "Face-rules with multiple conditions - first match wins."
  (with-temp-buffer
    (dotimes (_ 5) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done %n" :type search-simple :pattern "done"
                   :count-format t
                   :face-rules ((>= 10 face-very-high)
                                (>= 5 face-high)
                                (>= 1 face-mid)
                                (= 0 face-zero)))))
      ;; count=5, should match (>= 5 face-high)
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer)) 'face-high)))))

;;; Test 7: Face-rules with zero count
(ert-deftest test-layer-face-rules-zero-count ()
  "Face-rules with zero count - exact match."
  (with-temp-buffer
    (insert "[ ] open task\n")
    (altodo-mode)
    (let ((entry '(:title "Done %n" :type search-simple :pattern "done"
                   :count-format t
                   :face-rules ((>= 10 face-high)
                                (>= 1 face-mid)
                                (= 0 face-zero)))))
      ;; count=0 (no done tasks), should match (= 0 face-zero)
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer)) 'face-zero)))))

;;; Test 8: Count-face-rules doesn't affect title face
(ert-deftest test-layer-count-face-rules-independent ()
  "Count-face-rules doesn't affect title face (Layer 3 is independent)."
  (with-temp-buffer
    (dotimes (_ 15) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done - %n" :type search-simple :pattern "done"
                   :count-format t
                   :face-rules ((>= 10 face-high))
                   :count-face-rules ((>= 10 face-count-high)))))
      ;; Title should get face-high from :face-rules
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer)) 'face-high))
      
      ;; Count portion should be formatted with count value
      (let ((formatted (altodo--format-sidebar-title entry (current-buffer))))
        ;; Check that the formatted string contains the count
        (should (string-match "15" formatted))))))

;;; Test 9: Selection mode with count-face-rules
(ert-deftest test-layer-selection-with-count-face-rules ()
  "Selection mode overrides both face-rules and count-face-rules."
  (with-temp-buffer
    (dotimes (_ 15) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done - %n" :type search-simple :pattern "done"
                   :count-format t
                   :face-rules ((>= 10 face-high))
                   :count-face-rules ((>= 10 face-count-high)))))
      ;; With selection: selection mode should override
      (setq-local altodo-sidebar--selected-filters (list entry))
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer))
                  'altodo-sidebar-selected-filter-face)))))

;;; Test 10: Face spec (not just symbol) in face-rules
(ert-deftest test-layer-face-rules-with-spec ()
  "Face-rules with face spec (not just symbol)."
  (with-temp-buffer
    (dotimes (_ 15) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done %n" :type search-simple :pattern "done"
                   :count-format t
                   :face-rules ((>= 10 (:foreground "red" :weight bold))))))
      ;; Should return the face spec
      (let ((result (altodo-sidebar--get-face entry nil (current-buffer))))
        (should result)
        (should (listp result))))))

;;; Test 11: Multiple entries with different face-rules
(ert-deftest test-layer-multiple-entries-different-rules ()
  "Multiple entries with different face-rules."
  (with-temp-buffer
    (dotimes (_ 15) (insert "[x] done task\n"))
    (dotimes (_ 3) (insert "[ ] open task\n"))
    (altodo-mode)
    (let ((done-entry '(:title "Done %n" :type search-simple :pattern "done"
                        :count-format t
                        :face-rules ((>= 10 face-high))))
          (open-entry '(:title "Open %n" :type search-simple :pattern "open"
                        :count-format t
                        :face-rules ((>= 5 face-high)))))
      ;; Done: count=15, should match (>= 10 face-high)
      (should (eq (altodo-sidebar--get-face done-entry nil (current-buffer)) 'face-high))
      
      ;; Open: count=3, should not match (>= 5)
      (should (not (eq (altodo-sidebar--get-face open-entry nil (current-buffer)) 'face-high))))))

;;; Test 12: Fallback chain - face-rules -> static face -> default
(ert-deftest test-layer-fallback-chain ()
  "Fallback chain: face-rules -> static face -> default."
  (with-temp-buffer
    (dotimes (_ 3) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done %n" :type search-simple :pattern "done"
                   :count-format t
                   :face bold
                   :face-rules ((>= 10 face-high)))))
      ;; face-rules doesn't match (count=3 < 10)
      ;; should fall back to :face (bold)
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer)) 'bold)))))

;;; Test 13: No face-rules, only static face
(ert-deftest test-layer-no-face-rules-only-static ()
  "No face-rules, only static face (Layer 4)."
  (with-temp-buffer
    (dotimes (_ 15) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done %n" :type search-simple :pattern "done"
                   :count-format t
                   :face bold)))
      ;; No face-rules, should use :face
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer)) 'bold)))))

;;; Test 14: No face-rules, no static face, only default
(ert-deftest test-layer-no-face-rules-no-static ()
  "No face-rules, no static face, only default (Layer 5)."
  (with-temp-buffer
    (dotimes (_ 15) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done %n" :type search-simple :pattern "done"
                   :count-format t)))
      ;; No face-rules, no :face, should use default
      (let ((result (altodo-sidebar--get-face entry nil (current-buffer))))
        (should result)))))

;;; Test 15: Active mode with static face
(ert-deftest test-layer-active-mode-with-static-face ()
  "Active mode (Layer 1) overrides static face (Layer 4)."
  (with-temp-buffer
    (dotimes (_ 15) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done %n" :type search-simple :pattern "done"
                   :count-format t
                   :face bold)))
      ;; With active mode: should use active-filter-face, not :face
      (setq-local altodo-sidebar--selected-filters (list entry)
                  altodo-sidebar--selection-mode 'single)
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer))
                  'altodo-sidebar-active-filter-face)))))

(provide 'sidebar-face-layer-test)
;;; sidebar-face-layer-test.el ends here
