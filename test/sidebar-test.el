;;; sidebar-test.el --- Test for altodo sidebar

(require 'ert)
(require 'altodo)

(ert-deftest altodo-sidebar-test-load-locals ()
  "Test loading .altodo-locals.el file."
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "testfiles/test.altodo"))
    (let ((locals (altodo--load-locals-file)))
      (should locals)
      (should (assq 'altodo-filter-patterns locals)))))

(ert-deftest altodo-sidebar-test-get-filter-patterns ()
  "Test getting filter patterns from .altodo-locals.el."
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "testfiles/test.altodo"))
    (let ((patterns (altodo--get-filter-patterns)))
      (should patterns)
      (should (listp patterns))
      (should (> (length patterns) 0))
      (should (plist-get (car patterns) :title)))))

(ert-deftest altodo-sidebar-test-make-config ()
  "Test creating sidebar config."
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "testfiles/test.altodo"))
    (let ((config (altodo-sidebar-make-config)))
      (should config)
      (should (plist-get config :name))
      (should (plist-get config :position))
      (should (plist-get config :width))
      (should (plist-get config :entries)))))

(ert-deftest altodo-sidebar-test-default-patterns ()
  "Test default patterns when .altodo-locals.el not found."
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "nonexistent/test.altodo"))
    (let ((patterns (altodo--get-filter-patterns)))
      (should-not patterns))
    (let ((config (altodo-sidebar-make-config)))
      (should config)
      (should (equal (plist-get config :entries) altodo-default-filter-patterns)))))

(ert-deftest altodo-sidebar-test-pattern-types ()
  "Test all pattern types are loaded correctly."
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "testfiles/test.altodo"))
    (let* ((patterns (altodo--get-filter-patterns))
           (types (delete-dups (mapcar (lambda (p) (plist-get p :type)) patterns))))
      (should (member 'search-simple types))
      (should (member 'search-lambda types))
      (should (member 'group-header types))
      (should (member 'separator types))
      (should (member 'command types)))))

(ert-deftest altodo-sidebar-test-search-simple-patterns ()
  "Test search-simple patterns."
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "testfiles/test.altodo"))
    (let* ((patterns (altodo--get-filter-patterns))
           (simple-patterns (cl-remove-if-not
                             (lambda (p) (eq (plist-get p :type) 'search-simple))
                             patterns)))
      (should (> (length simple-patterns) 0))
      (dolist (p simple-patterns)
        (should (plist-get p :title))
        (should (plist-get p :pattern))))))

(ert-deftest altodo-sidebar-test-search-lambda-patterns ()
  "Test search-lambda patterns."
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "testfiles/test.altodo"))
    (let* ((patterns (altodo--get-filter-patterns))
           (lambda-patterns (cl-remove-if-not
                             (lambda (p) (eq (plist-get p :type) 'search-lambda))
                             patterns)))
      (should (> (length lambda-patterns) 0))
      (dolist (p lambda-patterns)
        (should (plist-get p :title))
        (should (functionp (plist-get p :pattern)))))))

(ert-deftest altodo-sidebar-test-group-header-patterns ()
  "Test group-header patterns."
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "testfiles/test.altodo"))
    (let* ((patterns (altodo--get-filter-patterns))
           (group-patterns (cl-remove-if-not
                            (lambda (p) (eq (plist-get p :type) 'group-header))
                            patterns)))
      (should (> (length group-patterns) 0))
      (dolist (p group-patterns)
        (should (plist-get p :title))
        (should (= (plist-get p :nest) 0))))))

(ert-deftest altodo-sidebar-test-command-patterns ()
  "Test command patterns."
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "testfiles/test.altodo"))
    (let* ((patterns (altodo--get-filter-patterns))
           (command-patterns (cl-remove-if-not
                              (lambda (p) (eq (plist-get p :type) 'command))
                              patterns)))
      (should (> (length command-patterns) 0))
      (dolist (p command-patterns)
        (should (plist-get p :title))
        (should (plist-get p :command))))))

(ert-deftest altodo-sidebar-test-nesting ()
  "Test nesting levels."
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name "testfiles/test.altodo"))
    (let* ((patterns (altodo--get-filter-patterns))
           (nest-0 (cl-remove-if-not (lambda (p) (= (or (plist-get p :nest) 0) 0)) patterns))
           (nest-1 (cl-remove-if-not (lambda (p) (= (or (plist-get p :nest) 0) 1)) patterns)))
      (should (> (length nest-0) 0))
      (should (> (length nest-1) 0)))))

;;; sidebar-test.el ends here
