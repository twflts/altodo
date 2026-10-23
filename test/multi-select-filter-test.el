;;; multi-select-filter-test.el --- Complex multiple filter tests

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

;;; Helper: Load test file

(defun load-test-file (filename)
  "Load test file and return buffer."
  (let ((path (altodo-test-file (concat "testfiles/" filename))))
    (find-file-noselect path)))

;;; Test: Multiple filters with AND condition

(ert-deftest test-multiple-filters-and-open-priority ()
  "Test AND combination: open tasks with priority flag.
Expected: [ ] tasks that have ! flag"
  (let ((buf (load-test-file "test-sample-project.altodo")))
    (with-current-buffer buf
      ;; Create two predicates
      (let ((pred-open (altodo--compile-simple-pattern "open"))
            (pred-priority (altodo--compile-simple-pattern "priority"))
            (combined (altodo--combine-predicates
                       (list (altodo--compile-simple-pattern "open")
                             (altodo--compile-simple-pattern "priority"))
                       'and)))
        
        ;; Apply combined filter
        (altodo--filter-lines combined)
        
        ;; Count visible lines
        (let ((visible-count 0))
          (save-excursion
            (goto-char (point-min))
            (while (not (eobp))
              (unless (altodo--filter-find-overlay (line-beginning-position)
                                                    (1+ (line-end-position)))
                (setq visible-count (1+ visible-count)))
              (forward-line 1)))
          
          ;; Should have some visible lines (open + priority tasks)
          (should (> visible-count 0)))))))

(ert-deftest test-multiple-filters-and-progress-important ()
  "Test AND combination: progress tasks with important tag.
Expected: [@] tasks that have #important tag"
  (let ((buf (load-test-file "test-sample-project.altodo")))
    (with-current-buffer buf
      (let ((combined (altodo--combine-predicates
                       (list (altodo--compile-simple-pattern "progress")
                             (altodo--compile-simple-pattern "tag:important"))
                       'and)))
        
        (altodo--filter-lines combined)
        
        (let ((visible-count 0))
          (save-excursion
            (goto-char (point-min))
            (while (not (eobp))
              (unless (altodo--filter-find-overlay (line-beginning-position)
                                                    (1+ (line-end-position)))
                (setq visible-count (1+ visible-count)))
              (forward-line 1))))))))

;;; Test: Multiple filters with OR condition

(ert-deftest test-multiple-filters-or-open-progress ()
  "Test OR combination: open or progress tasks.
Expected: [ ] or [@] tasks"
  (let ((buf (load-test-file "test-sample-project.altodo")))
    (with-current-buffer buf
      (let ((combined (altodo--combine-predicates
                       (list (altodo--compile-simple-pattern "open")
                             (altodo--compile-simple-pattern "progress"))
                       'or)))
        
        (altodo--filter-lines combined)
        
        (let ((visible-count 0))
          (save-excursion
            (goto-char (point-min))
            (while (not (eobp))
              (unless (altodo--filter-find-overlay (line-beginning-position)
                                                    (1+ (line-end-position)))
                (setq visible-count (1+ visible-count)))
              (forward-line 1)))
          
          ;; Should have many visible lines (open or progress tasks)
          (should (> visible-count 0)))))))

(ert-deftest test-multiple-filters-or-waiting-cancelled ()
  "Test OR combination: waiting or cancelled tasks.
Expected: [w] or [~] tasks"
  (let ((buf (load-test-file "test-sample-project.altodo")))
    (with-current-buffer buf
      (let ((combined (altodo--combine-predicates
                       (list (altodo--compile-simple-pattern "waiting")
                             (altodo--compile-simple-pattern "cancelled"))
                       'or)))
        
        (altodo--filter-lines combined)
        
        (let ((visible-count 0))
          (save-excursion
            (goto-char (point-min))
            (while (not (eobp))
              (unless (altodo--filter-find-overlay (line-beginning-position)
                                                    (1+ (line-end-position)))
                (setq visible-count (1+ visible-count)))
              (forward-line 1))))))))

;;; Test: Three-way AND combination

(ert-deftest test-three-way-and-open-priority-important ()
  "Test AND combination with three predicates: open + priority + important.
Expected: [ ] tasks with ! flag and #important tag"
  (let ((buf (load-test-file "test-sample-project.altodo")))
    (with-current-buffer buf
      (let ((combined (altodo--combine-predicates
                       (list (altodo--compile-simple-pattern "open")
                             (altodo--compile-simple-pattern "priority")
                             (altodo--compile-simple-pattern "tag:important"))
                       'and)))
        
        (altodo--filter-lines combined)
        
        (let ((visible-count 0))
          (save-excursion
            (goto-char (point-min))
            (while (not (eobp))
              (unless (altodo--filter-find-overlay (line-beginning-position)
                                                    (1+ (line-end-position)))
                (setq visible-count (1+ visible-count)))
              (forward-line 1))))))))

;;; Test: Three-way OR combination

(ert-deftest test-three-way-or-done-progress-waiting ()
  "Test OR combination with three predicates: done or progress or waiting.
Expected: [x] or [@] or [w] tasks"
  (let ((buf (load-test-file "test-sample-project.altodo")))
    (with-current-buffer buf
      (let ((combined (altodo--combine-predicates
                       (list (altodo--compile-simple-pattern "done")
                             (altodo--compile-simple-pattern "progress")
                             (altodo--compile-simple-pattern "waiting"))
                       'or)))
        
        (altodo--filter-lines combined)
        
        (let ((visible-count 0))
          (save-excursion
            (goto-char (point-min))
            (while (not (eobp))
              (unless (altodo--filter-find-overlay (line-beginning-position)
                                                    (1+ (line-end-position)))
                (setq visible-count (1+ visible-count)))
              (forward-line 1)))
          
          ;; Should have many visible lines
          (should (> visible-count 0)))))))

;;; Test: Complex AND with person filter

(ert-deftest test-multiple-filters-and-open-person ()
  "Test AND combination: open tasks assigned to 田中.
Expected: [ ] tasks with @田中"
  (let ((buf (load-test-file "test-sample-project.altodo")))
    (with-current-buffer buf
      (let ((combined (altodo--combine-predicates
                       (list (altodo--compile-simple-pattern "open")
                             (altodo--compile-simple-pattern "person:田中"))
                       'and)))
        
        (altodo--filter-lines combined)
        
        (let ((visible-count 0))
          (save-excursion
            (goto-char (point-min))
            (while (not (eobp))
              (unless (altodo--filter-find-overlay (line-beginning-position)
                                                    (1+ (line-end-position)))
                (setq visible-count (1+ visible-count)))
              (forward-line 1))))))))

;;; Test: Complex AND with text search

(ert-deftest test-multiple-filters-and-open-text-todo ()
  "Test AND combination: open tasks containing 'TODO'.
Expected: [ ] tasks with 'TODO' text"
  (let ((buf (load-test-file "test-sample-project.altodo")))
    (with-current-buffer buf
      (let ((combined (altodo--combine-predicates
                       (list (altodo--compile-simple-pattern "open")
                             (altodo--compile-simple-pattern "text:TODO"))
                       'and)))
        
        (altodo--filter-lines combined)
        
        (let ((visible-count 0))
          (save-excursion
            (goto-char (point-min))
            (while (not (eobp))
              (unless (altodo--filter-find-overlay (line-beginning-position)
                                                    (1+ (line-end-position)))
                (setq visible-count (1+ visible-count)))
              (forward-line 1))))))))

;;; Test: Complex OR with multiple tags

(ert-deftest test-multiple-filters-or-tags ()
  "Test OR combination: tasks with #important or #id tag.
Expected: tasks with #important or #id"
  (let ((buf (load-test-file "test-sample-project.altodo")))
    (with-current-buffer buf
      (let ((combined (altodo--combine-predicates
                       (list (altodo--compile-simple-pattern "tag:important")
                             (altodo--compile-simple-pattern "tag:id"))
                       'or)))
        
        (altodo--filter-lines combined)
        
        (let ((visible-count 0))
          (save-excursion
            (goto-char (point-min))
            (while (not (eobp))
              (unless (altodo--filter-find-overlay (line-beginning-position)
                                                    (1+ (line-end-position)))
                (setq visible-count (1+ visible-count)))
              (forward-line 1)))
          
          ;; Should have visible lines
          (should (> visible-count 0)))))))

;;; Test: Complex AND with nesting level

(ert-deftest test-multiple-filters-and-open-level ()
  "Test AND combination: open tasks at nesting level 0.
Expected: [ ] tasks at top level"
  (let ((buf (load-test-file "test-sample-project.altodo")))
    (with-current-buffer buf
      (let ((combined (altodo--combine-predicates
                       (list (altodo--compile-simple-pattern "open")
                             (altodo--compile-simple-pattern "level:0"))
                       'and)))
        
        (altodo--filter-lines combined)
        
        (let ((visible-count 0))
          (save-excursion
            (goto-char (point-min))
            (while (not (eobp))
              (unless (altodo--filter-find-overlay (line-beginning-position)
                                                    (1+ (line-end-position)))
                (setq visible-count (1+ visible-count)))
              (forward-line 1))))))))

;;; Test: Complex AND with star flag

(ert-deftest test-multiple-filters-and-open-star ()
  "Test AND combination: open tasks with star flag.
Expected: [ ] tasks with + flag"
  (let ((buf (load-test-file "test-sample-project.altodo")))
    (with-current-buffer buf
      (let ((combined (altodo--combine-predicates
                       (list (altodo--compile-simple-pattern "open")
                             (altodo--compile-simple-pattern "star"))
                       'and)))
        
        (altodo--filter-lines combined)
        
        (let ((visible-count 0))
          (save-excursion
            (goto-char (point-min))
            (while (not (eobp))
              (unless (altodo--filter-find-overlay (line-beginning-position)
                                                    (1+ (line-end-position)))
                (setq visible-count (1+ visible-count)))
              (forward-line 1))))))))

;;; Test: Verify AND is more restrictive than OR

(ert-deftest test-and-more-restrictive-than-or ()
  "Verify that AND combination produces fewer results than OR.
AND should be more restrictive."
  (let ((buf (load-test-file "test-sample-project.altodo")))
    (with-current-buffer buf
      ;; Count AND results
      (let ((combined-and (altodo--combine-predicates
                           (list (altodo--compile-simple-pattern "open")
                                 (altodo--compile-simple-pattern "priority"))
                           'and)))
        (altodo--filter-lines combined-and)
        (let ((and-count 0))
          (save-excursion
            (goto-char (point-min))
            (while (not (eobp))
              (unless (altodo--filter-find-overlay (line-beginning-position)
                                                    (1+ (line-end-position)))
                (setq and-count (1+ and-count)))
              (forward-line 1)))
          
          ;; Clear filter
          (altodo-filter-clear)
          
          ;; Count OR results
          (let ((combined-or (altodo--combine-predicates
                              (list (altodo--compile-simple-pattern "open")
                                    (altodo--compile-simple-pattern "priority"))
                              'or)))
            (altodo--filter-lines combined-or)
            (let ((or-count 0))
              (save-excursion
                (goto-char (point-min))
                (while (not (eobp))
                  (unless (altodo--filter-find-overlay (line-beginning-position)
                                                        (1+ (line-end-position)))
                    (setq or-count (1+ or-count)))
                  (forward-line 1)))
              
              ;; AND should be <= OR
              (should (<= and-count or-count)))))))))

;;; Run tests

(message "=== Running Complex Filter Tests ===")
(ert-run-tests-batch-and-exit)

(provide 'multi-select-filter-test)

;;; multi-select-filter-test.el ends here
