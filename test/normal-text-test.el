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

(provide 'normal-text-test)
