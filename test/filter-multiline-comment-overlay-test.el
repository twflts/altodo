;;; filter-multiline-comment-overlay-test.el --- Test multiline comment overlay handling

(require 'ert)
(require 'altodo)

(defvar test-buffer nil)

(defun setup-test-buffer ()
  "Setup test buffer with tasks and multiline comments."
  (setq test-buffer (get-buffer-create "*altodo-filter-multiline-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (altodo-mode)
    (insert "[ ] Task 1 without comment\n")
    (insert "[ ] Task 2 with multiline comment\n")
    (insert "    This is multiline comment line 1\n")
    (insert "    This is multiline comment line 2\n")
    (insert "[ ] Task 3 without comment\n")
    (insert "[ ] Task 4 with multiline comment\n")
    (insert "    Comment for task 4 line 1\n")
    (insert "    Comment for task 4 line 2\n")
    (insert "    Comment for task 4 line 3\n")))

(defun cleanup-test-buffer ()
  "Cleanup test buffer."
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))

(ert-deftest filter-multiline-comment-overlay-test-show-all ()
  "Test that multiline comments are shown when filtering with show-multiline-comment=t."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    ;; Filter to show only tasks with "Task" in them
    (let ((pred (lambda () (looking-at "^[ \t]*\\[.\\].*Task"))))
      (altodo--filter-lines pred t)
      
      ;; With show-multiline=t, multiline comment overlays should be deleted
      ;; Line 3 (multiline comment) should NOT have overlay after deletion
      (goto-char (point-min))
      (forward-line 2)  ; Go to line 3
      (let ((ov (altodo--filter-find-overlay (line-beginning-position) (1+ (line-end-position)))))
        ;; overlay should be deleted by altodo--filter-show-multiline-comments
        (should-not ov))))
  (cleanup-test-buffer))

(ert-deftest filter-multiline-comment-overlay-test-hide-all ()
  "Test that multiline comments are hidden when filtering with show-multiline-comment=nil."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    ;; Filter to show only tasks with "Task" in them
    (let ((pred (lambda () (looking-at "^[ \t]*\\[.\\].*Task"))))
      (altodo--filter-lines pred nil)
      
      ;; Check that overlays are created for multiline comments
      ;; Line 3 (multiline comment) should have overlay (show-multiline=nil)
      (goto-char (point-min))
      (forward-line 2)  ; Go to line 3 (first multiline comment)
      (let ((ov (altodo--filter-find-overlay (line-beginning-position) (1+ (line-end-position)))))
        (should ov))))
  (cleanup-test-buffer))

(ert-deftest filter-multiline-comment-overlay-test-count ()
  "Test that correct number of lines are shown/hidden."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    ;; Filter to show only tasks with "Task 2" or "Task 4"
    (let ((pred (lambda () (looking-at "^[ \t]*\\[.\\].*Task [24]"))))
      (altodo--filter-lines pred t)
      
      ;; Count visible lines (lines without overlay)
      (let ((visible-count 0))
        (goto-char (point-min))
        (while (not (eobp))
          (let ((ov (altodo--filter-find-overlay (line-beginning-position) (1+ (line-end-position)))))
            (unless ov
              (setq visible-count (1+ visible-count))))
          (forward-line 1))
        
        ;; Should have: Task 2 + 2 comments + Task 4 + 3 comments = 8 visible lines
        ;; But with show-multiline=t, multiline comments are not hidden, so count should be 7
        ;; (Task 2 line + 2 comment lines + Task 4 line + 2 comment lines = 7, one comment line is missing)
        (should (= visible-count 7)))))
  (cleanup-test-buffer))

(provide 'filter-multiline-comment-overlay-test)
;;; filter-multiline-comment-overlay-test.el ends here
