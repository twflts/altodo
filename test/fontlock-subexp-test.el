;;; fontlock-subexp-test.el --- Tests for font-lock subexp-highlighter

(require 'ert)
(require 'altodo)

;; Test: Single subexp
(ert-deftest fontlock-subexp-test-single-subexp ()
  "Test single subexp highlighting."
  ;; Test 1: font-lock-keywords is a list
  (let ((keywords (altodo-font-lock-keywords)))
    (unless (listp keywords)
      (error "font-lock-keywords should return list, got %s" (type-of keywords))))
  
  ;; Test 2: keywords contain entries
  (let ((keywords (altodo-font-lock-keywords)))
    (unless (> (length keywords) 0)
      (error "font-lock-keywords should contain entries, got %d" (length keywords))))
  
  (message "test-single-subexp: PASS"))

;; Test: Multiple subexp
(ert-deftest fontlock-subexp-test-multiple-subexp ()
  "Test multiple subexp highlighting."
  ;; Test 1: some keywords have multiple subexp
  (let ((keywords (altodo-font-lock-keywords)))
    (let ((has-multiple-subexp nil))
      (dolist (keyword keywords)
        (when (and (listp keyword) (listp (cdr keyword)))
          (let ((subexp-list (cdr keyword)))
            (when (and (listp (car subexp-list)) (listp (cdr subexp-list)))
              (setq has-multiple-subexp t)))))
      (unless has-multiple-subexp
        (error "font-lock-keywords should contain multiple subexp entries"))))
  
  (message "test-multiple-subexp: PASS"))

;; Test: Subexp with override flag
(ert-deftest fontlock-subexp-test-subexp-override ()
  "Test subexp with override flag."
  ;; Test 1: some keywords have override flags
  (let ((keywords (altodo-font-lock-keywords)))
    (let ((has-override nil))
      (dolist (keyword keywords)
        (when (and (listp keyword) (listp (cdr keyword)))
          (let ((subexp-list (cdr keyword)))
            (dolist (subexp subexp-list)
              (when (and (listp subexp) (>= (length subexp) 3))
                (let ((override (nth 2 subexp)))
                  (when (or (eq override t) (eq override 'prepend) (eq override 'append))
                    (setq has-override t))))))))
      (unless has-override
        (error "font-lock-keywords should contain override flags"))))
  
  (message "test-subexp-override: PASS"))

(provide 'fontlock-subexp-test)
;;; fontlock-subexp-test.el ends here
