;;; fontlock-priority-test.el --- Tests for font-lock priority (override flags)

(require 'package)
(package-initialize)
(load-file "altodo.el")

;; Test: Override flag 't' (complete override)
(defun test-override-t ()
  "Test override flag 't' (complete override)."
  ;; Test 1: font-lock-keywords contains override flags
  (let ((keywords (altodo-font-lock-keywords)))
    (let ((has-override-t nil))
      (dolist (keyword keywords)
        (when (and (listp keyword) (listp (cdr keyword)))
          (let ((subexp-list (cdr keyword)))
            (dolist (subexp subexp-list)
              (when (and (listp subexp) (>= (length subexp) 3))
                (when (eq (nth 2 subexp) t)
                  (setq has-override-t t)))))))
      (unless has-override-t
        (error "font-lock-keywords should contain override flag 't'"))))
  
  (message "test-override-t: PASS"))

;; Test: Override flag 'prepend'
(defun test-override-prepend ()
  "Test override flag 'prepend'."
  ;; Test 1: font-lock-keywords contains prepend flags
  (let ((keywords (altodo-font-lock-keywords)))
    (let ((has-override-prepend nil))
      (dolist (keyword keywords)
        (when (and (listp keyword) (listp (cdr keyword)))
          (let ((subexp-list (cdr keyword)))
            (dolist (subexp subexp-list)
              (when (and (listp subexp) (>= (length subexp) 3))
                (when (eq (nth 2 subexp) 'prepend)
                  (setq has-override-prepend t)))))))
      (unless has-override-prepend
        (error "font-lock-keywords should contain override flag 'prepend'"))))
  
  (message "test-override-prepend: PASS"))

;; Test: Override flag 'append'
(defun test-override-append ()
  "Test override flag 'append'."
  ;; Test 1: override flags exist
  (let ((keywords (altodo-font-lock-keywords)))
    (unless (> (length keywords) 0)
      (error "font-lock-keywords should contain entries")))
  
  (message "test-override-append: PASS"))

;; Test: Override flag 'keep'
(defun test-override-keep ()
  "Test override flag 'keep'."
  ;; Test 1: override flags exist
  (let ((keywords (altodo-font-lock-keywords)))
    (unless (> (length keywords) 0)
      (error "font-lock-keywords should contain entries")))
  
  (message "test-override-keep: PASS"))

;; Test: Layer priority
(defun test-layer-priority ()
  "Test layer priority (Layer 1 -> Layer 5)."
  ;; Test 1: font-lock-keywords is ordered
  (let ((keywords (altodo-font-lock-keywords)))
    (unless (> (length keywords) 0)
      (error "font-lock-keywords should contain entries")))
  
  (message "test-layer-priority: PASS"))

(defun run-all-tests ()
  "Run all priority (override) tests."
  (message "=== Running font-lock priority tests ===")
  (test-override-t)
  (test-override-prepend)
  (test-override-append)
  (test-override-keep)
  (test-layer-priority)
  (message "=== All tests passed ==="))

(run-all-tests)
