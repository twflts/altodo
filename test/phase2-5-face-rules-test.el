;;; phase2-5-face-rules-test.el --- Tests for Phase 2-5 face-rules

(require 'ert)
(require 'altodo)

;;; altodo--evaluate-face-rules tests

(ert-deftest test-face-rules-evaluate-first-match ()
  "First matching rule wins."
  (let ((rules '((>= 10 face-high) (>= 1 face-mid) (= 0 face-zero))))
    (should (eq (altodo--evaluate-face-rules rules 15) 'face-high))
    (should (eq (altodo--evaluate-face-rules rules 10) 'face-high))
    (should (eq (altodo--evaluate-face-rules rules 5) 'face-mid))
    (should (eq (altodo--evaluate-face-rules rules 1) 'face-mid))
    (should (eq (altodo--evaluate-face-rules rules 0) 'face-zero))))

(ert-deftest test-face-rules-evaluate-no-match ()
  "Returns nil when no rule matches."
  (let ((rules '((>= 10 face-high) (= 5 face-five))))
    (should (null (altodo--evaluate-face-rules rules 3)))))

(ert-deftest test-face-rules-evaluate-empty-rules ()
  "Returns nil for empty rules."
  (should (null (altodo--evaluate-face-rules nil 5)))
  (should (null (altodo--evaluate-face-rules '() 5))))

(ert-deftest test-face-rules-evaluate-operators ()
  "All comparison operators work correctly."
  (should (eq (altodo--evaluate-face-rules '((> 5 face-gt)) 6) 'face-gt))
  (should (null (altodo--evaluate-face-rules '((> 5 face-gt)) 5)))
  (should (eq (altodo--evaluate-face-rules '((= 5 face-eq)) 5) 'face-eq))
  (should (null (altodo--evaluate-face-rules '((= 5 face-eq)) 4)))
  (should (eq (altodo--evaluate-face-rules '((<= 5 face-le)) 4) 'face-le))
  (should (null (altodo--evaluate-face-rules '((<= 5 face-le)) 6)))
  (should (eq (altodo--evaluate-face-rules '((< 5 face-lt)) 4) 'face-lt))
  (should (null (altodo--evaluate-face-rules '((< 5 face-lt)) 5))))

(ert-deftest test-face-rules-evaluate-face-spec ()
  "Face spec (plist) works as face value."
  (let ((rules `((>= 1 (:foreground "red" :weight bold)))))
    (should (equal (altodo--evaluate-face-rules rules 5)
                   '(:foreground "red" :weight bold)))))

(ert-deftest test-face-rules-evaluate-single-rule ()
  "Single rule works."
  (should (eq (altodo--evaluate-face-rules '((>= 0 face-all)) 0) 'face-all))
  (should (eq (altodo--evaluate-face-rules '((>= 0 face-all)) 100) 'face-all)))

(ert-deftest test-face-rules-evaluate-order-matters ()
  "Earlier rules take priority over later ones."
  (let ((rules '((>= 1 face-first) (>= 5 face-second))))
    (should (eq (altodo--evaluate-face-rules rules 10) 'face-first))))

;;; altodo--get-entry-count tests

(ert-deftest test-get-entry-count-search-simple ()
  "Count matching lines for search-simple."
  (with-temp-buffer
    (insert "[x] done task 1\n[ ] open task\n[x] done task 2\n")
    (altodo-mode)
    (let ((entry '(:title "D" :type search-simple :pattern "done")))
      (should (= (altodo--get-entry-count entry (current-buffer)) 2)))))

(ert-deftest test-get-entry-count-zero ()
  "Returns 0 when no matches."
  (with-temp-buffer
    (insert "[ ] task one\n[ ] task two\n")
    (altodo-mode)
    (let ((entry '(:title "D" :type search-simple :pattern "done")))
      (should (= (altodo--get-entry-count entry (current-buffer)) 0)))))

(ert-deftest test-get-entry-count-uses-count-pattern-simple ()
  "Prefers :count-pattern-simple over :pattern."
  (with-temp-buffer
    (insert "[x] done task\n[ ] open task\n[ ] another open\n")
    (altodo-mode)
    (let ((entry '(:title "T" :type search-simple :pattern "done"
                   :count-pattern-simple "open")))
      ;; count-pattern-simple "open" matches 2 lines, not "done" (1 line)
      (should (= (altodo--get-entry-count entry (current-buffer)) 2)))))

;;; altodo-sidebar--get-face with :face-rules tests

(ert-deftest test-get-face-face-rules-high-count ()
  "face-rules returns high-count face when count >= 10."
  (with-temp-buffer
    (dotimes (_ 12) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done %n" :type search-simple :pattern "done"
                   :count-format t
                   :face-rules ((>= 10 face-high) (>= 1 face-mid) (= 0 face-zero)))))
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer)) 'face-high)))))

(ert-deftest test-get-face-face-rules-mid-count ()
  "face-rules returns mid face when 1 <= count < 10."
  (with-temp-buffer
    (dotimes (_ 3) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done %n" :type search-simple :pattern "done"
                   :count-format t
                   :face-rules ((>= 10 face-high) (>= 1 face-mid) (= 0 face-zero)))))
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer)) 'face-mid)))))

(ert-deftest test-get-face-face-rules-zero-count ()
  "face-rules returns zero face when count = 0."
  (with-temp-buffer
    (insert "[ ] open task\n")
    (altodo-mode)
    (let ((entry '(:title "Done %n" :type search-simple :pattern "done"
                   :count-format t
                   :face-rules ((>= 10 face-high) (>= 1 face-mid) (= 0 face-zero)))))
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer)) 'face-zero)))))

(ert-deftest test-get-face-face-rules-no-match-fallback-to-face ()
  "Falls back to :face when no rule matches."
  (with-temp-buffer
    (dotimes (_ 3) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "D %n" :type search-simple :pattern "done"
                   :count-format t
                   :face bold
                   :face-rules ((>= 10 face-high)))))
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer)) 'bold)))))

(ert-deftest test-get-face-face-rules-no-match-fallback-to-default ()
  "Falls back to type default when no rule matches and no :face."
  (with-temp-buffer
    (dotimes (_ 3) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "D %n" :type search-simple :pattern "done"
                   :count-format t
                   :face-rules ((>= 10 face-high)))))
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer))
                  'altodo-sidebar-search-simple-face)))))

(ert-deftest test-get-face-face-rules-requires-count-format ()
  "face-rules ignored when :count-format is nil."
  (with-temp-buffer
    (dotimes (_ 12) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry '(:title "Done" :type search-simple :pattern "done"
                   :face bold
                   :face-rules ((>= 1 face-high)))))
      (should (eq (altodo-sidebar--get-face entry nil (current-buffer)) 'bold)))))

(ert-deftest test-get-face-face-rules-with-face-spec ()
  "face-rules works with face spec (plist)."
  (with-temp-buffer
    (dotimes (_ 5) (insert "[x] done task\n"))
    (altodo-mode)
    (let ((entry `(:title "D %n" :type search-simple :pattern "done"
                   :count-format t
                   :face-rules ((>= 1 (:foreground "red" :weight bold))))))
      (should (equal (altodo-sidebar--get-face entry nil (current-buffer))
                     '(:foreground "red" :weight bold))))))

;;; altodo--format-sidebar-title with :count-face-rules tests

(ert-deftest test-title-count-face-rules-applied ()
  "count-face-rules applies face to count string."
  (with-temp-buffer
    (dotimes (_ 5) (insert "[x] done task\n"))
    (altodo-mode)
    (let* ((spec '(:title "Done - %n" :type search-simple :pattern "done"
                   :count-format t
                   :count-face-rules ((>= 5 face-high) (>= 1 face-mid))))
           (result (altodo--format-sidebar-title spec (current-buffer)))
           (pos (string-match "[0-9]" result)))
      (should (eq (get-text-property pos 'face result) 'face-high)))))

(ert-deftest test-title-count-face-rules-mid ()
  "count-face-rules applies mid face for lower count."
  (with-temp-buffer
    (dotimes (_ 2) (insert "[x] done task\n"))
    (altodo-mode)
    (let* ((spec '(:title "Done - %n" :type search-simple :pattern "done"
                   :count-format t
                   :count-face-rules ((>= 5 face-high) (>= 1 face-mid))))
           (result (altodo--format-sidebar-title spec (current-buffer)))
           (pos (string-match "[0-9]" result)))
      (should (eq (get-text-property pos 'face result) 'face-mid)))))

(ert-deftest test-title-count-face-rules-no-match-fallback-face-count ()
  "Falls back to :face-count when no count-face-rules match."
  (with-temp-buffer
    (insert "[ ] open task\n")
    (altodo-mode)
    (let* ((spec '(:title "Done - %n" :type search-simple :pattern "done"
                   :count-format t
                   :face-count face-default
                   :count-face-rules ((>= 1 face-high))))
           (result (altodo--format-sidebar-title spec (current-buffer)))
           (pos (string-match "[0-9]" result)))
      (should (eq (get-text-property pos 'face result) 'face-default)))))

(ert-deftest test-title-count-face-rules-priority-over-face-count ()
  "count-face-rules takes priority over :face-count."
  (with-temp-buffer
    (dotimes (_ 3) (insert "[x] done task\n"))
    (altodo-mode)
    (let* ((spec '(:title "Done - %n" :type search-simple :pattern "done"
                   :count-format t
                   :face-count face-default
                   :count-face-rules ((>= 1 face-rules-win))))
           (result (altodo--format-sidebar-title spec (current-buffer)))
           (pos (string-match "[0-9]" result)))
      (should (eq (get-text-property pos 'face result) 'face-rules-win)))))

(ert-deftest test-title-count-face-rules-with-face-spec ()
  "count-face-rules works with face spec."
  (with-temp-buffer
    (dotimes (_ 3) (insert "[x] done task\n"))
    (altodo-mode)
    (let* ((spec `(:title "Done - %n" :type search-simple :pattern "done"
                   :count-format t
                   :count-face-rules ((>= 1 (:foreground "red")))))
           (result (altodo--format-sidebar-title spec (current-buffer)))
           (pos (string-match "[0-9]" result)))
      (should (equal (get-text-property pos 'face result)
                     '(:foreground "red"))))))

;;; Combined :face-rules and :count-face-rules tests

(ert-deftest test-both-face-rules-and-count-face-rules ()
  "Both :face-rules and :count-face-rules can be specified simultaneously."
  (with-temp-buffer
    (dotimes (_ 5) (insert "[x] done task\n"))
    (altodo-mode)
    (let* ((entry '(:title "Done - %n" :type search-simple :pattern "done"
                    :count-format t
                    :face-rules ((>= 1 face-title))
                    :count-face-rules ((>= 1 face-count))))
           (title-face (altodo-sidebar--get-face entry nil (current-buffer)))
           (result (altodo--format-sidebar-title entry (current-buffer)))
           (pos (string-match "[0-9]" result)))
      (should (eq title-face 'face-title))
      (should (eq (get-text-property pos 'face result) 'face-count)))))

(ert-deftest test-face-rules-independent-thresholds ()
  "face-rules and count-face-rules can have different thresholds."
  (with-temp-buffer
    (dotimes (_ 7) (insert "[x] done task\n"))
    (altodo-mode)
    (let* ((entry '(:title "Done - %n" :type search-simple :pattern "done"
                    :count-format t
                    :face-rules ((>= 10 face-title-high) (>= 1 face-title-low))
                    :count-face-rules ((>= 5 face-count-high) (>= 1 face-count-low))))
           (title-face (altodo-sidebar--get-face entry nil (current-buffer)))
           (result (altodo--format-sidebar-title entry (current-buffer)))
           (pos (string-match "[0-9]" result)))
      ;; count=7: face-rules >= 10 no, >= 1 yes -> face-title-low
      (should (eq title-face 'face-title-low))
      ;; count=7: count-face-rules >= 5 yes -> face-count-high
      (should (eq (get-text-property pos 'face result) 'face-count-high)))))

(provide 'phase2-5-face-rules-test)
;;; phase2-5-face-rules-test.el ends here
