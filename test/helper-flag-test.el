;;; helper-flag-test.el --- Tests for flag helper functions

(require 'ert)
(require 'altodo)

;; Test: altodo--has-star-flag-p
(ert-deftest helper-flag-test-has-star-flag-p ()
  "Test altodo--has-star-flag-p."
  ;; Test 1: with star flag
  (unless (altodo--has-star-flag-p "+ Task")
    (error "has-star-flag-p('+ Task') should return t"))
  
  ;; Test 2: "++" is not a star flag (a flag is a single "+" and one space)
  (when (altodo--has-star-flag-p "++ Task")
    (error "has-star-flag-p('++ Task') should return nil"))
  
  ;; Test 3: with leading spaces
  (unless (altodo--has-star-flag-p "  + Task")
    (error "has-star-flag-p('  + Task') should return t"))
  
  ;; Test 4: without star flag
  (when (altodo--has-star-flag-p "Task")
    (error "has-star-flag-p('Task') should return nil"))
  
  ;; Test 5: with priority flag instead
  (when (altodo--has-star-flag-p "! Task")
    (error "has-star-flag-p('! Task') should return nil"))
  
  (message "test-has-star-flag-p: PASS"))

;; Test: altodo--remove-priority-from-string

;; Test: altodo--remove-star-from-string

;; Test: altodo--get-flag-text-face

(provide 'helper-flag-test)
;;; helper-flag-test.el ends here
