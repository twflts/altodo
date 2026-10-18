;;; load-locals-file-test.el --- Tests for altodo--load-locals-file

(require 'ert)
(require 'altodo)

(ert-deftest test-load-locals-file-no-file ()
  "Test altodo--load-locals-file when file does not exist."
  (with-temp-buffer
    (setq buffer-file-name "/tmp/test-altodo-no-locals.altodo")
    (should (null (altodo--load-locals-file)))))

(ert-deftest test-load-locals-file-with-file ()
  "Test altodo--load-locals-file when file exists."
  (let ((temp-dir (make-temp-file "altodo-test-" t)))
    (unwind-protect
        (let ((altodo-file (expand-file-name "test.altodo" temp-dir))
              (locals-file (expand-file-name ".altodo-locals.el" temp-dir)))
          ;; Create test files
          (write-region "" nil altodo-file)
          (write-region "((:key . value))" nil locals-file)
          
          ;; Test
          (with-temp-buffer
            (setq buffer-file-name altodo-file)
            (should (equal (altodo--load-locals-file) '((:key . value))))))
      (delete-directory temp-dir t))))

(ert-deftest test-load-locals-file-parse-error ()
  "Test altodo--load-locals-file with invalid Lisp syntax."
  (let ((temp-dir (make-temp-file "altodo-test-" t)))
    (unwind-protect
        (let ((altodo-file (expand-file-name "test.altodo" temp-dir))
              (locals-file (expand-file-name ".altodo-locals.el" temp-dir)))
          ;; Create test files with invalid Lisp
          (write-region "" nil altodo-file)
          (write-region "((invalid lisp" nil locals-file)
          
          ;; Test - should return nil and print warning
          (with-temp-buffer
            (setq buffer-file-name altodo-file)
            (should (null (altodo--load-locals-file)))))
      (delete-directory temp-dir t))))

(ert-deftest test-load-locals-file-unsaved-buffer ()
  "Test altodo--load-locals-file with unsaved buffer."
  (with-temp-buffer
    ;; buffer-file-name is nil for unsaved buffer
    (should (null (altodo--load-locals-file)))))

(ert-deftest test-get-filter-patterns-no-file ()
  "Test altodo--get-filter-patterns when file does not exist."
  (with-temp-buffer
    (setq buffer-file-name "/tmp/test-altodo-no-patterns.altodo")
    (should (null (altodo--get-filter-patterns)))))

(ert-deftest test-get-filter-patterns-with-patterns ()
  "Test altodo--get-filter-patterns when patterns exist."
  (let ((temp-dir (make-temp-file "altodo-test-" t)))
    (unwind-protect
        (let ((altodo-file (expand-file-name "test.altodo" temp-dir))
              (locals-file (expand-file-name ".altodo-locals.el" temp-dir)))
          ;; Create test files
          (write-region "" nil altodo-file)
          (write-region "((altodo-filter-patterns . ((:title \"Done\" :type search-simple :pattern \"done\"))))" nil locals-file)
          
          ;; Test
          (with-temp-buffer
            (setq buffer-file-name altodo-file)
            (should (equal (altodo--get-filter-patterns)
                          '((:title "Done" :type search-simple :pattern "done"))))))
      (delete-directory temp-dir t))))

(ert-deftest test-get-filter-patterns-no-patterns-key ()
  "Test altodo--get-filter-patterns when altodo-filter-patterns key is missing."
  (let ((temp-dir (make-temp-file "altodo-test-" t)))
    (unwind-protect
        (let ((altodo-file (expand-file-name "test.altodo" temp-dir))
              (locals-file (expand-file-name ".altodo-locals.el" temp-dir)))
          ;; Create test files without altodo-filter-patterns key
          (write-region "" nil altodo-file)
          (write-region "((:other-key . value))" nil locals-file)
          
          ;; Test
          (with-temp-buffer
            (setq buffer-file-name altodo-file)
            (should (null (altodo--get-filter-patterns)))))
      (delete-directory temp-dir t))))

(provide 'load-locals-file-test)
;;; load-locals-file-test.el ends here
