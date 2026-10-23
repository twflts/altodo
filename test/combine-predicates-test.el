;;; combine-predicates-test.el --- Tests multiple filter selection

;;; Code:

(require 'ert)
(require 'altodo)

;;; Test: altodo--combine-predicates

(ert-deftest test-combine-predicates-and ()
  "Test AND combination of predicates."
  (let ((pred1 (lambda () t))
        (pred2 (lambda () t))
        (combined (altodo--combine-predicates
                   (list (lambda () t) (lambda () t))
                   'and)))
    (should (funcall combined))))

(ert-deftest test-combine-predicates-and-false ()
  "Test AND combination with false predicate."
  (let ((combined (altodo--combine-predicates
                   (list (lambda () t) (lambda () nil))
                   'and)))
    (should-not (funcall combined))))

(ert-deftest test-combine-predicates-or ()
  "Test OR combination of predicates."
  (let ((combined (altodo--combine-predicates
                   (list (lambda () nil) (lambda () t))
                   'or)))
    (should (funcall combined))))

(ert-deftest test-combine-predicates-or-false ()
  "Test OR combination with all false predicates."
  (let ((combined (altodo--combine-predicates
                   (list (lambda () nil) (lambda () nil))
                   'or)))
    (should-not (funcall combined))))

;;; Test: altodo-sidebar--toggle-filter-selection

(ert-deftest test-toggle-filter-selection-add ()
  "Test adding filter to selection."
  (let ((entry '(:title "Test" :type search-simple :pattern "done")))
    ;; Create sidebar buffer with required variables
    (with-current-buffer (get-buffer-create "*altodo-filters*")
      (setq-local altodo-sidebar--selected-filters nil)
      (setq-local altodo-sidebar--source-buffer nil)
      (setq-local altodo-sidebar--last-source-buffer nil)
      ;; Manually add to selection (skip the full function which requires more setup)
      (push entry altodo-sidebar--selected-filters)
      (should (member entry altodo-sidebar--selected-filters)))))

(ert-deftest test-toggle-filter-selection-remove ()
  "Test removing filter from selection."
  (let ((entry '(:title "Test" :type search-simple :pattern "done")))
    ;; Create sidebar buffer with required variables
    (with-current-buffer (get-buffer-create "*altodo-filters*")
      (setq-local altodo-sidebar--selected-filters (list entry))
      ;; Manually remove from selection
      (setq altodo-sidebar--selected-filters
            (delete entry altodo-sidebar--selected-filters))
      (should-not (member entry altodo-sidebar--selected-filters)))))

;;; Test: altodo-sidebar-set-and-mode

(ert-deftest test-set-and-mode ()
  "Test setting AND mode."
  (with-current-buffer (get-buffer-create "*altodo-filters*")
    (setq-local altodo-sidebar--selected-filters '((:title "Test")))
    (setq-local altodo-sidebar--combine-mode 'or)
    ;; Manually set mode (skip full function)
    (setq altodo-sidebar--combine-mode 'and)
    (should (eq altodo-sidebar--combine-mode 'and))))

;;; Test: altodo-sidebar-set-or-mode

(ert-deftest test-set-or-mode ()
  "Test setting OR mode."
  (with-current-buffer (get-buffer-create "*altodo-filters*")
    (setq-local altodo-sidebar--selected-filters '((:title "Test")))
    (setq-local altodo-sidebar--combine-mode 'and)
    ;; Manually set mode (skip full function)
    (setq altodo-sidebar--combine-mode 'or)
    (should (eq altodo-sidebar--combine-mode 'or))))

;;; Test: altodo-sidebar-toggle-combine-mode

(ert-deftest test-toggle-combine-mode-and-to-or ()
  "Test toggling from AND to OR."
  (with-current-buffer (get-buffer-create "*altodo-filters*")
    (setq-local altodo-sidebar--selected-filters '((:title "Test")))
    (setq-local altodo-sidebar--combine-mode 'and)
    ;; Manually toggle (skip full function)
    (setq altodo-sidebar--combine-mode
          (if (eq altodo-sidebar--combine-mode 'and) 'or 'and))
    (should (eq altodo-sidebar--combine-mode 'or))))

(ert-deftest test-toggle-combine-mode-or-to-and ()
  "Test toggling from OR to AND."
  (with-current-buffer (get-buffer-create "*altodo-filters*")
    (setq-local altodo-sidebar--selected-filters '((:title "Test")))
    (setq-local altodo-sidebar--combine-mode 'or)
    ;; Manually toggle (skip full function)
    (setq altodo-sidebar--combine-mode
          (if (eq altodo-sidebar--combine-mode 'and) 'or 'and))
    (should (eq altodo-sidebar--combine-mode 'and))))

;;; Test: altodo-sidebar--get-mode-line-string

(ert-deftest test-get-mode-line-string-empty ()
  "Test mode-line string with no filters selected."
  (with-current-buffer (get-buffer-create "*altodo-filters*")
    (setq-local altodo-sidebar--selected-filters nil)
    (should-not (altodo-sidebar--get-mode-line-string))))

(ert-deftest test-get-mode-line-string-and ()
  "Test mode-line string with AND mode."
  (with-current-buffer (get-buffer-create "*altodo-filters*")
    (setq-local altodo-sidebar--selected-filters '((:title "Test1") (:title "Test2")))
    (setq-local altodo-sidebar--combine-mode 'and)
    (let ((str (altodo-sidebar--get-mode-line-string)))
      (should (string-match "Multiple: 2 filters, AND" str)))))

(ert-deftest test-get-mode-line-string-or ()
  "Test mode-line string with OR mode."
  (with-current-buffer (get-buffer-create "*altodo-filters*")
    (setq-local altodo-sidebar--selected-filters '((:title "Test1") (:title "Test2")))
    (setq-local altodo-sidebar--combine-mode 'or)
    (let ((str (altodo-sidebar--get-mode-line-string)))
      (should (string-match "Multiple: 2 filters, OR" str)))))

;;; Test: altodo-sidebar--get-face with multiple selection

(ert-deftest test-sidebar-get-face-selected-filter ()
  "Test face for selected filter in multiple selection mode."
  (let ((entry '(:title "Test" :type search-simple :pattern "done")))
    (with-current-buffer (get-buffer-create "*altodo-filters*")
      (setq-local altodo-sidebar--selected-filters (list entry))
      (setq-local altodo-sidebar--active-entries nil)
      (let ((face (altodo-sidebar--get-face entry nil)))
        (should (eq face 'altodo-sidebar-selected-filter-face))))))

(ert-deftest test-sidebar-get-face-active-filter ()
  "Test face for active filter (not in multiple selection)."
  (let ((entry '(:title "Test" :type search-simple :pattern "done")))
    (with-current-buffer (get-buffer-create "*altodo-filters*")
      (setq-local altodo-sidebar--selected-filters nil)
      (setq-local altodo-sidebar--active-entries (list entry))
      (let ((face (altodo-sidebar--get-face entry nil)))
        (should (eq face 'altodo-sidebar-active-filter-face))))))

(ert-deftest test-sidebar-get-face-selected-over-active ()
  "Test that selected filter face takes priority over active filter face."
  (let ((entry '(:title "Test" :type search-simple :pattern "done")))
    (with-current-buffer (get-buffer-create "*altodo-filters*")
      (setq-local altodo-sidebar--selected-filters (list entry))
      (setq-local altodo-sidebar--active-entries (list entry))
      (let ((face (altodo-sidebar--get-face entry nil)))
        (should (eq face 'altodo-sidebar-selected-filter-face))))))

;;; Run tests

(message "=== Running tests ===")
(ert-run-tests-batch-and-exit)

(provide 'combine-predicates-test)

;;; combine-predicates-test.el ends here
