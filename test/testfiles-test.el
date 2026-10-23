;;; testfiles-test.el --- Tests for the sample files in testfiles/  -*- lexical-binding: t; -*-

;;; Commentary:
;; The files in testfiles/ are opened by hand to check altodo.el.  These
;; tests keep them valid: they must be processed without errors, they must
;; cover the features they are meant to show, and the sample
;; `.altodo-locals.el_' must only hold patterns that work.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defun testfiles-test--files ()
  "Return the absolute paths of the sample .altodo files."
  (directory-files (altodo-test-file "testfiles") t "\\.altodo\\'"))

(defun testfiles-test--read (file)
  "Return the contents of FILE as a string."
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

(defmacro testfiles-test--with-file (file &rest body)
  "Run BODY in an `altodo-mode' buffer holding the contents of FILE."
  (declare (indent 1))
  `(with-temp-buffer
     (insert (testfiles-test--read ,file))
     (altodo-mode)
     (goto-char (point-min))
     ,@body))

;;; Every file is processed without errors

(ert-deftest testfiles-test-files-exist ()
  (should (>= (length (testfiles-test--files)) 15)))

(ert-deftest testfiles-test-fontify-and-classify-every-line ()
  "Fontifying and classifying each line raises no error."
  (dolist (file (testfiles-test--files))
    (ert-info ((file-name-nondirectory file))
      (testfiles-test--with-file file
        (font-lock-ensure)
        (while (not (eobp))
          (altodo--task-p)
          (altodo--comment-p)
          (altodo--multiline-comment-p)
          (forward-line 1))))))

(ert-deftest testfiles-test-default-filters-run-on-every-file ()
  "Each default filter pattern can be evaluated on every line of every file."
  (dolist (file (testfiles-test--files))
    (ert-info ((file-name-nondirectory file))
      (testfiles-test--with-file file
        (dolist (entry altodo-default-filter-patterns)
          (when (memq (plist-get entry :type) '(search-simple search-lambda))
            (let ((predicate (altodo--compile-filter-predicate entry)))
              (goto-char (point-min))
              (while (not (eobp))
                (funcall predicate)
                (forward-line 1)))))))))

(ert-deftest testfiles-test-sidebar-renders-for-every-file ()
  "The sidebar with the sample locals renders for every file."
  (dolist (file (testfiles-test--files))
    (ert-info ((file-name-nondirectory file))
      (altodo-test-with-locals
        (insert (testfiles-test--read file))
        (altodo-mode)
        (let ((config (altodo-sidebar-make-config (current-buffer)))
              (sidebar (generate-new-buffer " *altodo-test-sidebar*")))
          (unwind-protect
              (progn
                (altodo-sidebar--render sidebar config)
                (should (> (buffer-size sidebar) 0)))
            (kill-buffer sidebar)))))))

;;; Each file shows what it is meant to show

(ert-deftest testfiles-test-feature-coverage ()
  "Each feature file contains the syntax it is named after."
  (dolist (case '(("test-task-states.altodo" "^\\[ \\]" "^\\[x\\]" "^\\[@\\]" "^\\[w\\]" "^\\[~\\]")
                  ("test-flags.altodo" "^\\[ \\] \\+ " "^\\[ \\] ! " "^\\[ \\] !! "
                   "^\\[ \\] !!! " "^/// ! ")
                  ("test-tags.altodo" "#[a-z-]+ " "#[a-z-]+:[a-z]+")
                  ("test-dates.altodo" "[0-9]\\{4\\}-[0-9][0-9]-[0-9][0-9] ->"
                   "-> [0-9]\\{4\\}-[0-9][0-9]-[0-9][0-9]")
                  ("test-special-tags.altodo" "#id:" "#dep:" "#done:" "#group-start:"
                   "#group-due:" "#seq-tasks" "@[a-z]+")
                  ("test-comments.altodo" "^/// " "^    /// " "^    OK:" "NG:")
                  ("test-markdown-integration.altodo" "^```" "`#not-a-tag`")
                  ("test-date-format-slash.altodo" "[0-9]\\{4\\}/[0-9][0-9]/[0-9][0-9] ->")))
    (let ((text (testfiles-test--read
                 (altodo-test-file (concat "testfiles/" (car case))))))
      (dolist (regexp (cdr case))
        (ert-info ((format "%s: %s" (car case) regexp))
          (should (string-match-p regexp text)))))))

(ert-deftest testfiles-test-unicode-file-has-non-ascii ()
  (should (string-match-p "[^[:ascii:]]"
                          (testfiles-test--read
                           (altodo-test-file "testfiles/test-unicode.altodo")))))

(ert-deftest testfiles-test-comments-file-follows-the-specification ()
  "Lines marked OK are multi-line comments, lines marked NG are not."
  (testfiles-test--with-file (altodo-test-file "testfiles/test-comments.altodo")
    (font-lock-ensure)
    (let ((checked 0))
      (while (not (eobp))
        (cond
         ((looking-at " +OK: ")
          (should (altodo--multiline-comment-p))
          (setq checked (1+ checked)))
         ((looking-at " *NG: ")
          (should-not (altodo--multiline-comment-p))
          (setq checked (1+ checked))))
        (forward-line 1))
      (should (>= checked 8)))))

;;; The sample locals file

(defun testfiles-test--locals ()
  "Return the alist read from the sample locals file."
  (with-temp-buffer
    (insert-file-contents (altodo-test-file "testfiles/.altodo-locals.el_"))
    (read (current-buffer))))

(defun testfiles-test--patterns ()
  "Return the filter patterns of the sample locals file."
  (cdr (assq 'altodo-filter-patterns (testfiles-test--locals))))

(ert-deftest testfiles-test-locals-types-are-known ()
  (dolist (entry (testfiles-test--patterns))
    (ert-info ((plist-get entry :title))
      (should (memq (plist-get entry :type)
                    '(search-simple search-lambda group-header separator
                      command dynamic comment calendar agenda)))
      (should (plist-member entry :title)))))

(ert-deftest testfiles-test-locals-patterns-compile ()
  "Every DSL pattern compiles without a message."
  (dolist (entry (testfiles-test--patterns))
    (when (eq (plist-get entry :type) 'search-simple)
      (ert-info ((plist-get entry :pattern))
        (let (messages)
          (cl-letf (((symbol-function 'message)
                     (lambda (format-string &rest args)
                       (push (apply #'format format-string args) messages))))
            (altodo--compile-simple-pattern (plist-get entry :pattern)))
          (should-not messages))))))

(ert-deftest testfiles-test-locals-lambdas-and-commands ()
  (dolist (entry (testfiles-test--patterns))
    (pcase (plist-get entry :type)
      ('search-lambda (should (functionp (plist-get entry :pattern))))
      ('command (should (commandp (plist-get entry :command)))))))

(ert-deftest testfiles-test-locals-dynamic-types ()
  (dolist (entry (testfiles-test--patterns))
    (when (eq (plist-get entry :type) 'dynamic)
      (should (member (plist-get entry :dynamic-type)
                      '("person" "tag" "due" "start" "heading"))))))

(ert-deftest testfiles-test-locals-faces-exist ()
  "A face given by name in :face-rules or :count-face-rules is defined."
  (dolist (entry (testfiles-test--patterns))
    (dolist (key '(:face-rules :count-face-rules))
      (dolist (rule (plist-get entry key))
        (let ((face (nth 2 rule)))
          (when (symbolp face)
            (ert-info ((format "%s %S" (plist-get entry :title) face))
              (should (or (facep face) (assq face (cdr (assq 'altodo-sidebar-face-alist
                                                             (testfiles-test--locals)))))))))))))

(provide 'testfiles-test)
;;; testfiles-test.el ends here
