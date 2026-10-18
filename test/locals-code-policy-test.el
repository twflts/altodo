;;; locals-code-policy-test.el --- Tests for the code policy of .altodo-locals.el  -*- lexical-binding: t; -*-

;;; Commentary:
;; B01: the code in .altodo-locals.el (search-lambda, :count-pattern-lambda,
;; :command) runs only as `altodo-locals-code-policy' allows.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defconst locals-code-policy-test--locals
  "((altodo-filter-patterns .
   ((:title \"Simple %n\" :type search-simple :pattern \"open\" :count-format t)
    (:title \"Lambda %n\" :type search-lambda :count-format t
     :pattern (lambda () (looking-at \"\\\\[ \\\\]\")))
    (:title \"Own\" :type command :command altodo-filter-clear)
    (:title \"User\" :type command :command my-user-command))))"
  "Sample .altodo-locals.el with code and without code.")

(defmacro locals-code-policy-test--with-locals (&rest body)
  "Run BODY in an altodo buffer whose directory has the sample locals file.
The buffer holds two open tasks and one done task."
  (declare (indent 0))
  `(altodo-test-with-temp-dir locals-code-policy-test--dir
     (with-temp-file (expand-file-name ".altodo-locals.el"
                                       locals-code-policy-test--dir)
       (insert locals-code-policy-test--locals))
     (with-temp-buffer
       (setq buffer-file-name
             (expand-file-name "test.altodo" locals-code-policy-test--dir))
       (insert "[ ] a\n[ ] b\n[x] c\n")
       (altodo-mode)
       (let ((altodo-trusted-locals nil))
         ,@body))))

(defun locals-code-policy-test--entry (title)
  "Return the pattern entry titled TITLE from the sample locals."
  (cl-find title (altodo--get-filter-patterns)
           :key (lambda (entry) (plist-get entry :title)) :test #'equal))

(defun locals-code-policy-test--select (title)
  "Apply the sidebar entry titled TITLE as if its button were pressed."
  (let ((entry (locals-code-policy-test--entry title))
        (source (current-buffer)))
    (with-temp-buffer
      (let ((altodo-sidebar--source-buffer source))
        (insert-button "x" 'sidebar-entry entry)
        (altodo-sidebar--apply-filter (button-at (point-min)))))))

(ert-deftest locals-code-policy-marks-only-user-code ()
  "Only entries with user code get `:locals-code'."
  (locals-code-policy-test--with-locals
    (should-not (plist-get (locals-code-policy-test--entry "Simple %n")
                           :locals-code))
    (should (plist-get (locals-code-policy-test--entry "Lambda %n")
                       :locals-code))
    (should-not (plist-get (locals-code-policy-test--entry "Own")
                           :locals-code))
    (should (plist-get (locals-code-policy-test--entry "User")
                       :locals-code))))

(ert-deftest locals-code-policy-deny-is-default ()
  "The default policy is `deny'."
  (should (eq (default-value 'altodo-locals-code-policy) 'deny)))

(ert-deftest locals-code-policy-deny-blocks-count ()
  "Under `deny', the count of a lambda entry is nil; simple entries count."
  (locals-code-policy-test--with-locals
    (let ((altodo-locals-code-policy 'deny))
      (should (null (altodo--get-entry-count
                     (locals-code-policy-test--entry "Lambda %n")
                     (current-buffer))))
      (should (= (altodo--get-entry-count
                  (locals-code-policy-test--entry "Simple %n")
                  (current-buffer))
                 2)))))

(ert-deftest locals-code-policy-deny-shows-question-mark ()
  "Under `deny', the title of a lambda entry shows `?' for the count."
  (locals-code-policy-test--with-locals
    (let ((altodo-locals-code-policy 'deny))
      (should (equal (altodo--format-sidebar-title
                      (locals-code-policy-test--entry "Lambda %n")
                      (current-buffer))
                     "Lambda ?")))))

(ert-deftest locals-code-policy-allow-runs-lambda ()
  "Under `allow', the lambda runs and counts the open tasks."
  (locals-code-policy-test--with-locals
    (let ((altodo-locals-code-policy 'allow))
      (should (= (altodo--get-entry-count
                  (locals-code-policy-test--entry "Lambda %n")
                  (current-buffer))
                 2)))))

(ert-deftest locals-code-policy-deny-never-runs-lambda ()
  "Under `deny', the lambda is not called by the predicate or the filter."
  (locals-code-policy-test--with-locals
    (let* ((altodo-locals-code-policy 'deny)
           (called nil)
           (entry (append (list :type 'search-lambda
                                :pattern (lambda () (setq called t)))
                          (list :locals-code "/x/.altodo-locals.el"))))
      (should-not (funcall (altodo--compile-filter-predicate entry)))
      (should-not called))))

(ert-deftest locals-code-policy-deny-blocks-command ()
  "Under `deny', selecting a command entry from the file does not run it."
  (locals-code-policy-test--with-locals
    (let ((altodo-locals-code-policy 'deny)
          (called nil))
      (cl-letf (((symbol-function 'my-user-command)
                 (lambda () (interactive) (setq called t))))
        (locals-code-policy-test--select "User"))
      (should-not called))))

(ert-deftest locals-code-policy-own-command-runs-under-deny ()
  "A command of this package runs even under `deny'."
  (locals-code-policy-test--with-locals
    (let ((altodo-locals-code-policy 'deny)
          (called nil))
      (cl-letf (((symbol-function 'altodo-filter-clear)
                 (lambda () (interactive) (setq called t))))
        (locals-code-policy-test--select "Own"))
      (should called))))

(ert-deftest locals-code-policy-confirm-asks-and-saves-hash ()
  "Under `confirm', trusting the file saves its SHA-256 and runs the code."
  (locals-code-policy-test--with-locals
    (let* ((altodo-locals-code-policy 'confirm)
           (entry (locals-code-policy-test--entry "Lambda %n"))
           (file (plist-get entry :locals-code))
           (saved nil)
           (asked 0))
      (cl-letf (((symbol-function 'y-or-n-p)
                 (lambda (_prompt) (setq asked (1+ asked)) t))
                ((symbol-function 'customize-save-variable)
                 (lambda (variable value)
                   (setq saved (cons variable value))
                   (set variable value))))
        ;; Without ASK, an untrusted file does not run and nothing is asked.
        (should-not (altodo--entry-code-permitted-p entry))
        (should (= asked 0))
        (should (altodo--entry-code-permitted-p entry t))
        (should (= asked 1))
        (should (equal (cdr saved)
                       (list (cons file (altodo--locals-file-hash file)))))
        ;; Once trusted, it runs without asking.
        (should (altodo--entry-code-permitted-p entry))
        (should (= (altodo--get-entry-count entry (current-buffer)) 2))
        (should (= asked 1))))))

(ert-deftest locals-code-policy-confirm-declined ()
  "Under `confirm', declining keeps the code from running."
  (locals-code-policy-test--with-locals
    (let ((altodo-locals-code-policy 'confirm)
          (entry (locals-code-policy-test--entry "Lambda %n")))
      (cl-letf (((symbol-function 'y-or-n-p) (lambda (_prompt) nil)))
        (should-not (altodo--entry-code-permitted-p entry t))
        (should-not altodo-trusted-locals)))))

(ert-deftest locals-code-policy-confirm-trust-ends-on-change ()
  "Under `confirm', changing the file ends the trust."
  (locals-code-policy-test--with-locals
    (let* ((altodo-locals-code-policy 'confirm)
           (entry (locals-code-policy-test--entry "Lambda %n"))
           (file (plist-get entry :locals-code)))
      (setq altodo-trusted-locals
            (list (cons file (altodo--locals-file-hash file))))
      (should (altodo--entry-code-permitted-p entry))
      (with-temp-file file
        (insert locals-code-policy-test--locals "\n;; changed\n"))
      (should-not (altodo--entry-code-permitted-p entry)))))

(ert-deftest locals-code-policy-face-rules-allow-comparisons-only ()
  "A face rule with an operator other than a comparison is ignored."
  (let ((called nil))
    (cl-letf (((symbol-function 'locals-code-policy-test--danger)
               (lambda (&rest _) (setq called t))))
      (should-not (altodo--evaluate-face-rules
                   '((locals-code-policy-test--danger 1 error)) 5))
      (should-not called))
    (should (eq (altodo--evaluate-face-rules '((/= 3 warning)) 5) 'warning))
    (should-not (altodo--evaluate-face-rules '((>= 1 error)) nil))))

(provide 'locals-code-policy-test)
;;; locals-code-policy-test.el ends here
