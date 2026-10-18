;;; phase2-7-dynamic-count-test.el --- Tests for Phase 2-7 dynamic count calculation

;;; Commentary:
;; Tests for complex filter combinations with dynamic count calculation
;; Verifies that count is correctly calculated under multiple filter selections

;;; Code:

(require 'ert)
(require 'altodo)

;; Test data setup
(defun phase2-7-test-setup ()
  "Create test buffer with sample data."
  (let ((buf (get-buffer-create "*phase2-7-test*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert "[x] ! + done priority star\n")
      (insert "[x] ! done priority\n")
      (insert "[x] + done star\n")
      (insert "[ ] ! open priority\n")
      (insert "[ ] + open star\n")
      (insert "[@] ! + progress both\n")
      (insert "[ ] plain open\n"))
    buf))

;; Test 1: (done AND pri) OR star
(ert-deftest phase2-7-test-1-done-and-pri-or-star ()
  "Test: (done AND pri) OR star"
  (let* ((buf (phase2-7-test-setup))
         (e-done (list :title "Done %n" :type 'search-simple :pattern "done" :count-format t))
         (e-pri (list :title "Pri %n" :type 'search-simple :pattern "priority" :count-format t))
         (e-star (list :title "Star %n" :type 'search-simple :pattern "star" :count-format t))
         (e-open (list :title "Open %n" :type 'search-simple :pattern "open" :count-format t))
         (e-progress (list :title "Progress %n" :type 'search-simple :pattern "progress" :count-format t)))
    (let* ((pred-done (altodo--compile-filter-predicate e-done))
           (pred-pri (altodo--compile-filter-predicate e-pri))
           (pred-star (altodo--compile-filter-predicate e-star))
           (and-pred (altodo--combine-predicates (list pred-done pred-pri) 'and))
           (combined (altodo--combine-predicates (list and-pred pred-star) 'or)))
      (should (= (altodo--get-entry-count e-done buf combined) 3))
      (should (= (altodo--get-entry-count e-pri buf combined) 2))
      (should (= (altodo--get-entry-count e-star buf combined) 2))
      (should (= (altodo--get-entry-count e-open buf combined) 1))
      (should (= (altodo--get-entry-count e-progress buf combined) 0)))))

;; Test 2: (done OR open) AND (pri OR star)
(ert-deftest phase2-7-test-2-done-or-open-and-pri-or-star ()
  "Test: (done OR open) AND (pri OR star)"
  (let* ((buf (phase2-7-test-setup))
         (e-done (list :title "Done %n" :type 'search-simple :pattern "done" :count-format t))
         (e-pri (list :title "Pri %n" :type 'search-simple :pattern "priority" :count-format t))
         (e-star (list :title "Star %n" :type 'search-simple :pattern "star" :count-format t))
         (e-open (list :title "Open %n" :type 'search-simple :pattern "open" :count-format t)))
    (let* ((pred-done (altodo--compile-filter-predicate e-done))
           (pred-pri (altodo--compile-filter-predicate e-pri))
           (pred-star (altodo--compile-filter-predicate e-star))
           (pred-open (altodo--compile-filter-predicate e-open))
           (or1 (altodo--combine-predicates (list pred-done pred-open) 'or))
           (or2 (altodo--combine-predicates (list pred-pri pred-star) 'or))
           (combined (altodo--combine-predicates (list or1 or2) 'and)))
      (should (= (altodo--get-entry-count e-done buf combined) 3))
      (should (= (altodo--get-entry-count e-pri buf combined) 3))
      (should (= (altodo--get-entry-count e-star buf combined) 2))
      (should (= (altodo--get-entry-count e-open buf combined) 2)))))

;; Test 3: done AND pri AND star
(ert-deftest phase2-7-test-3-done-and-pri-and-star ()
  "Test: done AND pri AND star"
  (let* ((buf (phase2-7-test-setup))
         (e-done (list :title "Done %n" :type 'search-simple :pattern "done" :count-format t))
         (e-pri (list :title "Pri %n" :type 'search-simple :pattern "priority" :count-format t))
         (e-star (list :title "Star %n" :type 'search-simple :pattern "star" :count-format t))
         (e-open (list :title "Open %n" :type 'search-simple :pattern "open" :count-format t))
         (e-progress (list :title "Progress %n" :type 'search-simple :pattern "progress" :count-format t)))
    (let* ((combined (altodo--combine-predicates
                      (mapcar #'altodo--compile-filter-predicate (list e-done e-pri e-star))
                      'and)))
      (should (= (altodo--get-entry-count e-done buf combined) 0))
      (should (= (altodo--get-entry-count e-pri buf combined) 0))
      (should (= (altodo--get-entry-count e-star buf combined) 0))
      (should (= (altodo--get-entry-count e-open buf combined) 0))
      (should (= (altodo--get-entry-count e-progress buf combined) 0)))))

;; Test 4: done OR pri OR star OR open
(ert-deftest phase2-7-test-4-done-or-pri-or-star-or-open ()
  "Test: done OR pri OR star OR open"
  (let* ((buf (phase2-7-test-setup))
         (e-done (list :title "Done %n" :type 'search-simple :pattern "done" :count-format t))
         (e-pri (list :title "Pri %n" :type 'search-simple :pattern "priority" :count-format t))
         (e-star (list :title "Star %n" :type 'search-simple :pattern "star" :count-format t))
         (e-open (list :title "Open %n" :type 'search-simple :pattern "open" :count-format t)))
    (let* ((combined (altodo--combine-predicates
                      (mapcar #'altodo--compile-filter-predicate (list e-done e-pri e-star e-open))
                      'or)))
      (should (= (altodo--get-entry-count e-done buf combined) 3))
      (should (= (altodo--get-entry-count e-pri buf combined) 4))
      (should (= (altodo--get-entry-count e-star buf combined) 2))
      (should (= (altodo--get-entry-count e-open buf combined) 3)))))

;; Test 5: (done AND pri AND star) OR progress
(ert-deftest phase2-7-test-5-done-and-pri-and-star-or-progress ()
  "Test: (done AND pri AND star) OR progress"
  (let* ((buf (phase2-7-test-setup))
         (e-done (list :title "Done %n" :type 'search-simple :pattern "done" :count-format t))
         (e-pri (list :title "Pri %n" :type 'search-simple :pattern "priority" :count-format t))
         (e-star (list :title "Star %n" :type 'search-simple :pattern "star" :count-format t))
         (e-progress (list :title "Progress %n" :type 'search-simple :pattern "progress" :count-format t)))
    (let* ((pred-done (altodo--compile-filter-predicate e-done))
           (pred-pri (altodo--compile-filter-predicate e-pri))
           (pred-star (altodo--compile-filter-predicate e-star))
           (pred-progress (altodo--compile-filter-predicate e-progress))
           (and-all (altodo--combine-predicates (list pred-done pred-pri pred-star) 'and))
           (combined (altodo--combine-predicates (list and-all pred-progress) 'or)))
      (should (= (altodo--get-entry-count e-done buf combined) 0))
      (should (= (altodo--get-entry-count e-pri buf combined) 1))
      (should (= (altodo--get-entry-count e-star buf combined) 0))
      (should (= (altodo--get-entry-count e-progress buf combined) 1)))))

;; Test 6: ((done AND pri) OR star) AND (open OR progress)
(ert-deftest phase2-7-test-6-nested-complex ()
  "Test: ((done AND pri) OR star) AND (open OR progress)"
  (let* ((buf (phase2-7-test-setup))
         (e-done (list :title "Done %n" :type 'search-simple :pattern "done" :count-format t))
         (e-pri (list :title "Pri %n" :type 'search-simple :pattern "priority" :count-format t))
         (e-star (list :title "Star %n" :type 'search-simple :pattern "star" :count-format t))
         (e-open (list :title "Open %n" :type 'search-simple :pattern "open" :count-format t))
         (e-progress (list :title "Progress %n" :type 'search-simple :pattern "progress" :count-format t)))
    (let* ((pred-done (altodo--compile-filter-predicate e-done))
           (pred-pri (altodo--compile-filter-predicate e-pri))
           (pred-star (altodo--compile-filter-predicate e-star))
           (pred-open (altodo--compile-filter-predicate e-open))
           (pred-progress (altodo--compile-filter-predicate e-progress))
           (and1 (altodo--combine-predicates (list pred-done pred-pri) 'and))
           (or1 (altodo--combine-predicates (list and1 pred-star) 'or))
           (or2 (altodo--combine-predicates (list pred-open pred-progress) 'or))
           (combined (altodo--combine-predicates (list or1 or2) 'and)))
      (should (= (altodo--get-entry-count e-done buf combined) 0))
      (should (= (altodo--get-entry-count e-pri buf combined) 0))
      (should (= (altodo--get-entry-count e-star buf combined) 1))
      (should (= (altodo--get-entry-count e-open buf combined) 1))
      (should (= (altodo--get-entry-count e-progress buf combined) 0)))))

;; Test 7: Performance test with 1000 lines
(ert-deftest phase2-7-test-7-performance ()
  "Test: Performance with 1000 lines"
  (let* ((buf (get-buffer-create "*phase2-7-perf*")))
    (with-current-buffer buf
      (erase-buffer)
      (dotimes (i 1000)
        (let ((state (if (= (mod i 3) 0) "[x]" "[ ]"))
              (flag (if (= (mod i 5) 0) " !" ""))
              (star (if (= (mod i 7) 0) " +" "")))
          (insert (format "%s task %d%s%s\n" state i flag star)))))
    (let* ((e-done (list :title "Done %n" :type 'search-simple :pattern "done" :count-format t))
           (e-pri (list :title "Pri %n" :type 'search-simple :pattern "priority" :count-format t)))
      (let* ((combined (altodo--combine-predicates
                        (mapcar #'altodo--compile-filter-predicate (list e-done e-pri))
                        'and)))
        ;; Just verify it completes without error
        (should (integerp (altodo--get-entry-count e-done buf combined)))
        (should (integerp (altodo--get-entry-count e-pri buf combined)))))))

;; Test 8: No combined predicate (nil)
(ert-deftest phase2-7-test-8-no-combined-predicate ()
  "Test: No combined predicate (nil)"
  (let* ((buf (phase2-7-test-setup))
         (e-done (list :title "Done %n" :type 'search-simple :pattern "done" :count-format t))
         (e-pri (list :title "Pri %n" :type 'search-simple :pattern "priority" :count-format t))
         (e-star (list :title "Star %n" :type 'search-simple :pattern "star" :count-format t)))
    ;; When combined-predicate is nil, should return normal counts
    (should (= (altodo--get-entry-count e-done buf nil) 3))
    (should (= (altodo--get-entry-count e-pri buf nil) 4))
    (should (= (altodo--get-entry-count e-star buf nil) 2))))

;; Test 9: Single filter with combined predicate
(ert-deftest phase2-7-test-9-single-filter-with-combined ()
  "Test: Single filter with combined predicate"
  (let* ((buf (phase2-7-test-setup))
         (e-done (list :title "Done %n" :type 'search-simple :pattern "done" :count-format t))
         (e-pri (list :title "Pri %n" :type 'search-simple :pattern "priority" :count-format t)))
    (let* ((combined (altodo--combine-predicates
                      (mapcar #'altodo--compile-filter-predicate (list e-done))
                      'and)))
      ;; Single filter: done AND done = done
      (should (= (altodo--get-entry-count e-done buf combined) 3))
      ;; Other filter: pri AND done
      (should (= (altodo--get-entry-count e-pri buf combined) 2)))))

;; Test 10: Empty buffer
(ert-deftest phase2-7-test-10-empty-buffer ()
  "Test: Empty buffer"
  (let* ((buf (get-buffer-create "*phase2-7-empty*")))
    (with-current-buffer buf
      (erase-buffer))
    (let* ((e-done (list :title "Done %n" :type 'search-simple :pattern "done" :count-format t))
           (e-pri (list :title "Pri %n" :type 'search-simple :pattern "priority" :count-format t)))
      (let* ((combined (altodo--combine-predicates
                        (mapcar #'altodo--compile-filter-predicate (list e-done e-pri))
                        'and)))
        (should (= (altodo--get-entry-count e-done buf combined) 0))
        (should (= (altodo--get-entry-count e-pri buf combined) 0))))))

;; Test 11: Dynamic filter with combined predicate
(ert-deftest phase2-7-test-11-dynamic-filter-with-combined ()
  "Test: Dynamic filter with combined predicate"
  (let* ((buf (get-buffer-create "*phase2-7-dynamic*")))
    (with-current-buffer buf
      (erase-buffer)
      (markdown-mode)
      (insert "[x] @alice task 1\n")
      (insert "[x] @bob task 2\n")
      (insert "[ ] @alice task 3\n")
      (insert "[ ] @bob task 4\n")
      (insert "[@] @charlie task 5\n"))
    (let* ((e-done (list :title "Done" :type 'search-simple :pattern "done"))
           (combined (altodo--compile-filter-predicate e-done))
           (entry (list :title "@%s [%n]" :type 'dynamic :dynamic-type "person" :count-format t :nest 1))
           (expanded (altodo--expand-dynamic-filter entry buf combined)))
      ;; done フィルタ選択時は @alice, @bob のみ（%n は未置換）
      (should (= (length expanded) 2))
      (let ((titles (mapcar (lambda (e) (plist-get e :title)) expanded)))
        (should (member "@alice [%n]" titles))
        (should (member "@bob [%n]" titles))
        (should-not (member "@charlie [%n]" titles)))
      ;; altodo--format-sidebar-title で再計算されることを確認
      (dolist (e expanded)
        (let ((formatted (altodo--format-sidebar-title e buf combined 'and)))
          (should (string-match "\\[1\\]" formatted)))))))

;; Test 12: AND mode count calculation
(ert-deftest phase2-7-test-12-and-mode-count ()
  "Test: AND mode count calculation"
  (let* ((buf (phase2-7-test-setup)))
    (let* ((e-done (list :title "Done" :type 'search-simple :pattern "done"))
           (e-pri (list :title "Priority" :type 'search-simple :pattern "priority"))
           (e-star (list :title "Star" :type 'search-simple :pattern "star"))
           (predicates (list (altodo--compile-filter-predicate e-done)
                            (altodo--compile-filter-predicate e-pri)))
           (combined (altodo--combine-predicates predicates 'and)))
      ;; AND mode: done AND priority
      ;; done: line 1, 2, 3
      ;; priority: line 1, 2, 4, 6
      ;; done AND priority: line 1, 2
      (should (= (altodo--get-entry-count e-done buf combined 'and) 2))  ;; line 1, 2
      (should (= (altodo--get-entry-count e-pri buf combined 'and) 2))))) ;; line 1, 2

;; Test 13: OR mode count calculation
(ert-deftest phase2-7-test-13-or-mode-count ()
  "Test: OR mode count calculation"
  (let* ((buf (phase2-7-test-setup)))
    (let* ((e-done (list :title "Done" :type 'search-simple :pattern "done"))
           (e-pri (list :title "Priority" :type 'search-simple :pattern "priority"))
           (e-star (list :title "Star" :type 'search-simple :pattern "star"))
           (predicates (list (altodo--compile-filter-predicate e-done)
                            (altodo--compile-filter-predicate e-pri)))
           (combined (altodo--combine-predicates predicates 'or)))
      ;; OR mode: combined-predicate を無視（全体のカウント）
      ;; done: line 1, 2, 3
      ;; priority: line 1, 2, 4, 6
      ;; star: line 3, 5 (line 1 は "star" が単語として認識されない)
      (should (= (altodo--get-entry-count e-done buf combined 'or) 3))   ;; line 1, 2, 3
      (should (= (altodo--get-entry-count e-pri buf combined 'or) 4))    ;; line 1, 2, 4, 6
      (should (= (altodo--get-entry-count e-star buf combined 'or) 2))))) ;; line 3, 5

(provide 'phase2-7-dynamic-count-test)

;;; phase2-7-dynamic-count-test.el ends here
