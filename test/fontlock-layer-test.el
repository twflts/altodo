;;; fontlock-layer-test.el --- Tests for font-lock layer-based face application

(require 'package)
(package-initialize)
(load-file "altodo.el")

;; Test: Layer 1 - Task brackets
(defun test-layer1-brackets ()
  "Test Layer 1: Task brackets."
  ;; Test 1: bracket face exists
  (unless (facep 'altodo-task-bracket-face)
    (error "altodo-task-bracket-face should exist"))
  
  ;; Test 2: state faces exist
  (unless (facep 'altodo-task-done-face)
    (error "altodo-task-done-face should exist"))
  
  (message "test-layer1-brackets: PASS"))

;; Test: Layer 2 - Base text
(defun test-layer2-base-text ()
  "Test Layer 2: Base text."
  ;; Test 1: base text faces exist
  (unless (facep 'altodo-task-open-text-face)
    (error "altodo-task-open-text-face should exist"))
  
  ;; Test 2: state-specific text faces exist
  (unless (facep 'altodo-task-done-text-face)
    (error "altodo-task-done-text-face should exist"))
  
  (message "test-layer2-base-text: PASS"))

;; Test: Layer 4 - Emphasis (flags, tags)
(defun test-layer4-emphasis ()
  "Test Layer 4: Emphasis elements."
  ;; Test 1: flag faces exist
  (unless (facep 'altodo-flag-star-face)
    (error "altodo-flag-star-face should exist"))
  
  ;; Test 2: tag faces exist
  (unless (facep 'altodo-tag-face)
    (error "altodo-tag-face should exist"))
  
  (message "test-layer4-emphasis: PASS"))

;; Test: Layer 5 - Highest priority (comments, strikethrough)
(defun test-layer5-highest ()
  "Test Layer 5: Highest priority."
  ;; Test 1: comment face exists
  (unless (facep 'altodo-comment-face)
    (error "altodo-comment-face should exist"))
  
  ;; Test 2: multiline comment face exists
  (unless (facep 'altodo-multiline-comment-face)
    (error "altodo-multiline-comment-face should exist"))
  
  (message "test-layer5-highest: PASS"))

(defun run-all-tests ()
  "Run all layer-based face application tests."
  (message "=== Running font-lock layer tests ===")
  (test-layer1-brackets)
  (test-layer2-base-text)
  (test-layer4-emphasis)
  (test-layer5-highest)
  (message "=== All tests passed ==="))

(run-all-tests)
