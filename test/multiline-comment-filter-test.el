;;; multiline-comment-filter-test.el --- Tests for multiline comment filter functionality

(require 'ert)
(require 'altodo)

;;; Tests for helper functions

(ert-deftest multiline-comment-test-get-range ()
  "Test altodo--get-multiline-comment-range function."
  (with-temp-buffer
    (insert "[ ] Task\n")
    (insert "    Multiline comment 1\n")
    (insert "    Multiline comment 2\n")
    (insert "[ ] Next task\n")
    
    (goto-char (point-min))
    (let ((range (altodo--get-multiline-comment-range)))
      (should range)
      (should (= (car range) 10))  ; After "[ ] Task\n"
      (should (> (cdr range) (car range))))))

(ert-deftest multiline-comment-test-get-range-no-comment ()
  "Test altodo--get-multiline-comment-range when no multiline comment."
  (with-temp-buffer
    (insert "[ ] Task\n")
    (insert "[ ] Next task\n")
    
    (goto-char (point-min))
    (let ((range (altodo--get-multiline-comment-range)))
      (should (null range)))))

(ert-deftest multiline-comment-test-has-multiline-comment-p ()
  "Test altodo--line-has-multiline-comment-p function."
  (with-temp-buffer
    (insert "[ ] Task with comment\n")
    (insert "    Multiline comment\n")
    (insert "[ ] Task without comment\n")
    
    ;; Task with multiline comment
    (goto-char (point-min))
    (should (altodo--line-has-multiline-comment-p))
    
    ;; Task without multiline comment
    (forward-line 2)
    (should (null (altodo--line-has-multiline-comment-p)))))

(ert-deftest multiline-comment-test-contains-regexp-p ()
  "Test altodo--multiline-comment-contains-regexp-p function."
  (with-temp-buffer
    (insert "[ ] Task\n")
    (insert "    TODO: Fix this\n")
    (insert "    FIXME: Another issue\n")
    (insert "[ ] Next task\n")
    
    (goto-char (point-min))
    ;; Contains TODO
    (should (altodo--multiline-comment-contains-regexp-p "TODO"))
    
    ;; Contains FIXME
    (should (altodo--multiline-comment-contains-regexp-p "FIXME"))
    
    ;; Does not contain DONE
    (should (null (altodo--multiline-comment-contains-regexp-p "DONE")))))

(ert-deftest multiline-comment-test-contains-regexp-p-no-comment ()
  "Test altodo--multiline-comment-contains-regexp-p when no multiline comment."
  (with-temp-buffer
    (insert "[ ] Task\n")
    (insert "[ ] Next task\n")
    
    (goto-char (point-min))
    (should (null (altodo--multiline-comment-contains-regexp-p "TODO")))))

;;; Tests for DSL compilation

(ert-deftest multiline-comment-test-dsl-has-multiline-comment ()
  "Test DSL compilation for has-multiline-comment pattern."
  (with-temp-buffer
    (insert "[ ] Task with comment\n")
    (insert "    Multiline comment\n")
    (insert "[ ] Task without comment\n")
    
    (let ((pred (altodo--compile-simple-pattern "has-multiline-comment")))
      (should (functionp pred))
      
      ;; Task with multiline comment
      (goto-char (point-min))
      (should (funcall pred))
      
      ;; Task without multiline comment
      (forward-line 2)
      (should (null (funcall pred))))))

(ert-deftest multiline-comment-test-dsl-multiline-comment-contains ()
  "Test DSL compilation for multiline-comment-contains pattern."
  (with-temp-buffer
    (insert "[ ] Task 1\n")
    (insert "    TODO: Fix this\n")
    (insert "[ ] Task 2\n")
    (insert "    FIXME: Another issue\n")
    (insert "[ ] Task 3\n")
    
    (let ((pred-todo (altodo--compile-simple-pattern "multiline-comment-contains:TODO"))
          (pred-fixme (altodo--compile-simple-pattern "multiline-comment-contains:FIXME")))
      (should (functionp pred-todo))
      (should (functionp pred-fixme))
      
      ;; Task 1 contains TODO
      (goto-char (point-min))
      (should (funcall pred-todo))
      (should (null (funcall pred-fixme)))
      
      ;; Task 2 contains FIXME
      (forward-line 2)
      (should (null (funcall pred-todo)))
      (should (funcall pred-fixme))
      
      ;; Task 3 has no multiline comment
      (forward-line 2)
      (should (null (funcall pred-todo)))
      (should (null (funcall pred-fixme))))))

;;; Tests for complex scenarios

(ert-deftest multiline-comment-test-nested-tasks ()
  "Test multiline comment detection with nested tasks."
  (with-temp-buffer
    (insert "[ ] Parent task\n")
    (insert "    Parent multiline comment\n")
    (insert "    [ ] Child task\n")
    (insert "        Child multiline comment\n")
    
    ;; Parent task has multiline comment
    (goto-char (point-min))
    (should (altodo--line-has-multiline-comment-p))
    
    ;; Child task has multiline comment
    (forward-line 2)
    (should (altodo--line-has-multiline-comment-p))))

(ert-deftest multiline-comment-test-empty-lines-in-comment ()
  "Test multiline comment with empty lines."
  (with-temp-buffer
    (insert "[ ] Task\n")
    (insert "    Comment line 1\n")
    (insert "    \n")
    (insert "    Comment line 3\n")
    (insert "[ ] Next task\n")
    
    (goto-char (point-min))
    (should (altodo--line-has-multiline-comment-p))
    
    (let ((range (altodo--get-multiline-comment-range)))
      (should range)
      ;; Range should include all comment lines including empty line
      (should (> (- (cdr range) (car range)) 30)))))

(ert-deftest multiline-comment-test-single-line-comment ()
  "Test single-line comment (///) is not multiline comment."
  (with-temp-buffer
    (insert "/// Single line comment\n")
    (insert "[ ] Task\n")
    
    (goto-char (point-min))
    (should (null (altodo--line-has-multiline-comment-p)))))

(ert-deftest multiline-comment-test-markdown-list-is-comment ()
  "A markdown list indented by 4 spaces under a task is a multiline comment."
  (with-temp-buffer
    (insert "[ ] Task\n")
    (insert "    - List item\n")
    (insert "    - Another item\n")
    (altodo-mode)
    (goto-char (point-min))
    (should (altodo--line-has-multiline-comment-p))))

(provide 'multiline-comment-filter-test)
;;; multiline-comment-filter-test.el ends here
