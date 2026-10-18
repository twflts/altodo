;; Test for normal text detection and heading range lines

(require 'ert)
(require 'altodo)

(ert-deftest normal-text-p-task-line ()
  "Test that task lines are not normal text"
  (with-temp-buffer
    (insert "[ ] Task 1\n")
    (goto-char (point-min))
    (should (not (altodo--normal-text-p 1)))))

(ert-deftest normal-text-p-comment-line ()
  "Test that comment lines are not normal text"
  (with-temp-buffer
    (insert "/// This is a comment\n")
    (goto-char (point-min))
    (should (not (altodo--normal-text-p 1)))))

(ert-deftest normal-text-p-heading-atx ()
  "Test that ATX headings are not normal text"
  (with-temp-buffer
    (insert "# Heading 1\n")
    (goto-char (point-min))
    (should (not (altodo--normal-text-p 1)))))

(ert-deftest normal-text-p-heading-setext ()
  "Test that Setext headings are not normal text"
  (with-temp-buffer
    (insert "Heading 1\n")
    (insert "=========\n")
    (goto-char (point-min))
    (should (not (altodo--normal-text-p 1)))))

(ert-deftest normal-text-p-blank-line ()
  "Test that blank lines are not normal text"
  (with-temp-buffer
    (insert "\n")
    (goto-char (point-min))
    (should (not (altodo--normal-text-p 1)))))

(ert-deftest normal-text-p-multiline-comment ()
  "Test that multiline comments are not normal text"
  (with-temp-buffer
    (insert "[ ] Task 1\n")
    (insert "    This is a multiline comment\n")
    (goto-char (point-min))
    (forward-line 1)
    (should (not (altodo--normal-text-p 2)))))

(ert-deftest normal-text-p-normal-text ()
  "Test that normal text is recognized"
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "\n")
    (insert "This is normal text\n")
    (insert "[ ] Task 1\n")
    
    (should (altodo--normal-text-p 3))))

(ert-deftest get-heading-range-lines-normal-text-only ()
  "Test that get-heading-range-lines returns only normal text"
  (with-temp-buffer
    (insert "# Heading 1\n")
    (insert "This is normal text\n")
    (insert "[ ] Task 1\n")
    (insert "    Multiline comment\n")
    (insert "More normal text\n")
    (insert "\n")
    (insert "[ ] Task 2\n")
    
    ;; Create heading ranges
    (let ((heading-ranges (altodo--compute-all-heading-ranges)))
      ;; Get range lines for line 3 (Task 1)
      (goto-char (point-min))
      (forward-line 2)
      (let ((current-pos (point)))
        (let ((range-lines (altodo--get-heading-range-lines heading-ranges current-pos)))
          (message "Range lines: %S" (sort range-lines #'<))
          ;; Should include line 2 (normal text) and line 5 (normal text)
          ;; Should NOT include line 3 (task), line 4 (multiline comment), line 6 (blank), line 7 (task)
          (should (member 2 range-lines))
          (should (member 5 range-lines))
          (should (not (member 3 range-lines)))
          (should (not (member 4 range-lines)))
          (should (not (member 6 range-lines)))
          (should (not (member 7 range-lines))))))))

(provide 'normal-text-test)
