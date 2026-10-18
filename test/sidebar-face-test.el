;;; sidebar-face-test.el --- Tests for sidebar face functions

(require 'ert)
(require 'altodo)

(ert-deftest test-sidebar-default-face-group-header ()
  "Test altodo-sidebar--default-face for group-header type."
  (should (eq (altodo-sidebar--default-face 'group-header 0)
              'altodo-sidebar-group-header-face)))

(ert-deftest test-sidebar-default-face-search-simple ()
  "Test altodo-sidebar--default-face for search-simple type."
  (should (eq (altodo-sidebar--default-face 'search-simple 1)
              'altodo-sidebar-search-simple-face)))

(ert-deftest test-sidebar-default-face-search-lambda ()
  "Test altodo-sidebar--default-face for search-lambda type."
  (should (eq (altodo-sidebar--default-face 'search-lambda 1)
              'altodo-sidebar-search-lambda-face)))

(ert-deftest test-sidebar-default-face-command ()
  "Test altodo-sidebar--default-face for command type."
  (should (eq (altodo-sidebar--default-face 'command 1)
              'altodo-sidebar-command-face)))

(ert-deftest test-sidebar-default-face-separator ()
  "Test altodo-sidebar--default-face for separator type."
  (should (eq (altodo-sidebar--default-face 'separator 0)
              'altodo-sidebar-separator-face)))

(ert-deftest test-sidebar-default-face-unknown ()
  "Test altodo-sidebar--default-face for unknown type."
  (should (eq (altodo-sidebar--default-face 'unknown 0)
              'default)))

(ert-deftest test-sidebar-resolve-face-nil ()
  "Test altodo-sidebar--resolve-face with nil."
  (should (null (altodo-sidebar--resolve-face nil))))

(ert-deftest test-sidebar-resolve-face-symbol ()
  "Test altodo-sidebar--resolve-face with face symbol."
  (should (eq (altodo-sidebar--resolve-face 'bold)
              'bold)))

(ert-deftest test-sidebar-resolve-face-spec ()
  "Test altodo-sidebar--resolve-face with face spec.
Face spec ((t (:foreground \"green\"))) should be converted to
attribute list (:foreground \"green\")."
  (let ((spec '((t (:foreground "green")))))
    (should (equal (altodo-sidebar--resolve-face spec)
                   '(:foreground "green")))))

(ert-deftest test-sidebar-get-face-with-face ()
  "Test altodo-sidebar--get-face when :face is specified."
  (let ((entry '(:title "Done" :type search-simple :face bold)))
    (should (eq (altodo-sidebar--get-face entry nil)
                'bold))))

(ert-deftest test-sidebar-get-face-without-face ()
  "Test altodo-sidebar--get-face when :face is not specified."
  (let ((entry '(:title "Done" :type search-simple)))
    (should (eq (altodo-sidebar--get-face entry nil)
                'altodo-sidebar-search-simple-face))))

(ert-deftest test-sidebar-get-face-with-spec ()
  "Test altodo-sidebar--get-face with face spec.
Face spec should be converted to attribute list."
  (let ((entry '(:title "Done" :type search-simple :face ((t (:foreground "green"))))))
    (should (equal (altodo-sidebar--get-face entry nil)
                   '(:foreground "green")))))

(ert-deftest test-sidebar-resolve-face-spec-multiple-attrs ()
  "Test altodo-sidebar--resolve-face with face spec with multiple attributes."
  (let ((spec '((t (:foreground "red" :weight bold)))))
    (should (equal (altodo-sidebar--resolve-face spec)
                   '(:foreground "red" :weight bold)))))

(ert-deftest test-sidebar-resolve-face-spec-complex ()
  "Test altodo-sidebar--resolve-face with complex face spec."
  (let ((spec '((t (:foreground "orange" :weight bold :underline t)))))
    (should (equal (altodo-sidebar--resolve-face spec)
                   '(:foreground "orange" :weight bold :underline t)))))

(ert-deftest test-altodo-get-sidebar-face-alist-no-file ()
  "Test altodo--get-sidebar-face-alist when file does not exist."
  (with-temp-buffer
    (setq buffer-file-name "/tmp/test-altodo-no-faces.altodo")
    (should (null (altodo--get-sidebar-face-alist)))))

(ert-deftest test-altodo-get-sidebar-face-alist-with-file ()
  "Test altodo--get-sidebar-face-alist when file exists."
  (let ((temp-dir (make-temp-file "altodo-test-" t)))
    (unwind-protect
        (let ((altodo-file (expand-file-name "test.altodo" temp-dir))
              (locals-file (expand-file-name ".altodo-locals.el" temp-dir)))
          ;; Create test files
          (write-region "" nil altodo-file)
          (write-region "((altodo-sidebar-face-alist . ((done-face . ((t (:foreground \"green\")))))))" nil locals-file)
          
          ;; Test
          (with-temp-buffer
            (setq buffer-file-name altodo-file)
            (should (equal (altodo--get-sidebar-face-alist)
                          '((done-face . ((t (:foreground "green")))))))))
      (delete-directory temp-dir t))))

(ert-deftest test-altodo-register-sidebar-faces ()
  "Test altodo--register-sidebar-faces registers faces."
  (let ((temp-dir (make-temp-file "altodo-test-" t)))
    (unwind-protect
        (let ((altodo-file (expand-file-name "test.altodo" temp-dir))
              (locals-file (expand-file-name ".altodo-locals.el" temp-dir)))
          ;; Create test files
          (write-region "" nil altodo-file)
          (write-region "((altodo-sidebar-face-alist . ((my-test-face . ((t (:foreground \"blue\")))))))" nil locals-file)
          
          ;; Test
          (with-temp-buffer
            (setq buffer-file-name altodo-file)
            (altodo--register-sidebar-faces)
            ;; Check if face was registered
            (should (facep 'my-test-face))))
      (delete-directory temp-dir t))))

(ert-deftest test-sidebar-face-defface-exists ()
  "Test that sidebar face deffaces are defined."
  (should (facep 'altodo-sidebar-group-header-face))
  (should (facep 'altodo-sidebar-search-simple-face))
  (should (facep 'altodo-sidebar-search-lambda-face))
  (should (facep 'altodo-sidebar-command-face))
  (should (facep 'altodo-sidebar-separator-face)))

(provide 'sidebar-face-test)
;;; sidebar-face-test.el ends here
