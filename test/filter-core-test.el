;;; filter-core-test.el --- Tests for filter core functions

(require 'ert)
(load-file "altodo.el")

(defvar test-buffer nil)

(defun setup-test-buffer ()
  (setq test-buffer (get-buffer-create "*altodo-filter-core-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task 1\n")
    (insert "    [ ] Task 1.1\n")
    (insert "[x] Task 2\n")
    (insert "[@] Task 3\n")
    (insert "[w] Task 4\n")
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))


;;; Tests for altodo--find-matching-lines

(ert-deftest test-find-matching-lines-all-match ()
  "Test finding all lines that match."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((ranges (altodo--find-matching-lines
                   (lambda () t))))
      (should (= (length ranges) 5))))
  (cleanup-test-buffer))

(ert-deftest test-find-matching-lines-none-match ()
  "Test finding no lines that match."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((ranges (altodo--find-matching-lines
                   (lambda () nil))))
      (should (= (length ranges) 0))))
  (cleanup-test-buffer))

(ert-deftest test-find-matching-lines-done-tasks ()
  "Test finding done tasks."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((ranges (altodo--find-matching-lines
                   (lambda () (looking-at "^\\[x\\]")))))
      (should (= (length ranges) 1))))
  (cleanup-test-buffer))

(ert-deftest test-find-matching-lines-indented-tasks ()
  "Test finding indented tasks."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((ranges (altodo--find-matching-lines
                   (lambda () (looking-at "^    ")))))
      (should (= (length ranges) 1))))
  (cleanup-test-buffer))

(ert-deftest test-find-matching-lines-range-format ()
  "Test that ranges have correct format (start . end)."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((ranges (altodo--find-matching-lines
                   (lambda () (looking-at "^\\[x\\]")))))
      (should (consp (car ranges)))
      (should (numberp (caar ranges)))
      (should (numberp (cdar ranges)))
      (should (< (caar ranges) (cdar ranges)))))
  (cleanup-test-buffer))

(ert-deftest test-find-matching-lines-empty-buffer ()
  "Test finding lines in empty buffer."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (erase-buffer)
    (let ((ranges (altodo--find-matching-lines
                   (lambda () t))))
      (should (= (length ranges) 0))))
  (cleanup-test-buffer))


;;; Tests for altodo--invert-ranges

(ert-deftest test-invert-ranges-single-range ()
  "Test inverting a single range."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let* ((ranges '((10 . 20)))
           (inverted (altodo--invert-ranges ranges)))
      (should (= (length inverted) 2))
      (should (= (caar inverted) (point-min)))
      (should (= (cdar inverted) 10))
      (should (= (caadr inverted) 20))
      (should (= (cdadr inverted) (point-max)))))
  (cleanup-test-buffer))

(ert-deftest test-invert-ranges-multiple-ranges ()
  "Test inverting multiple ranges."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let* ((ranges '((10 . 20) (30 . 40)))
           (inverted (altodo--invert-ranges ranges)))
      (should (= (length inverted) 3))))
  (cleanup-test-buffer))

(ert-deftest test-invert-ranges-empty ()
  "Test inverting empty ranges."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((inverted (altodo--invert-ranges nil)))
      (should (= (length inverted) 1))
      (should (= (caar inverted) (point-min)))
      (should (= (cdar inverted) (point-max)))))
  (cleanup-test-buffer))

(ert-deftest test-invert-ranges-full-coverage ()
  "Test inverting ranges that cover entire buffer."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let* ((ranges `((,(point-min) . ,(point-max))))
           (inverted (altodo--invert-ranges ranges)))
      (should (= (length inverted) 0))))
  (cleanup-test-buffer))


;;; Tests for altodo--merge-consecutive-ranges

(ert-deftest test-merge-consecutive-ranges-consecutive ()
  "Test merging consecutive ranges."
  (let ((ranges '((1 . 10) (10 . 20)))
        (merged (altodo--merge-consecutive-ranges '((1 . 10) (10 . 20)))))
    (should (= (length merged) 1))
    (should (= (caar merged) 1))
    (should (= (cdar merged) 20))))

(ert-deftest test-merge-consecutive-ranges-non-consecutive ()
  "Test merging non-consecutive ranges."
  (let ((merged (altodo--merge-consecutive-ranges '((1 . 10) (15 . 20)))))
    (should (= (length merged) 2))))

(ert-deftest test-merge-consecutive-ranges-empty ()
  "Test merging empty ranges."
  (let ((merged (altodo--merge-consecutive-ranges nil)))
    (should (null merged))))

(ert-deftest test-merge-consecutive-ranges-single ()
  "Test merging single range."
  (let ((merged (altodo--merge-consecutive-ranges '((1 . 10)))))
    (should (= (length merged) 1))
    (should (= (caar merged) 1))
    (should (= (cdar merged) 10))))

(ert-deftest test-merge-consecutive-ranges-multiple-consecutive ()
  "Test merging multiple consecutive ranges."
  (let ((merged (altodo--merge-consecutive-ranges '((1 . 10) (10 . 20) (20 . 30)))))
    (should (= (length merged) 1))
    (should (= (caar merged) 1))
    (should (= (cdar merged) 30))))


;;; Tests for altodo--create-overlays

(ert-deftest test-create-overlays-single-range ()
  "Test creating overlay for single range."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let* ((ranges '((10 . 20)))
           (overlays (altodo--create-overlays ranges)))
      (should (= (length overlays) 1))
      (should (overlayp (car overlays)))
      (should (= (overlay-start (car overlays)) 10))
      (should (= (overlay-end (car overlays)) 20))))
  (cleanup-test-buffer))

(ert-deftest test-create-overlays-multiple-ranges ()
  "Test creating overlays for multiple ranges."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let* ((ranges '((10 . 20) (30 . 40)))
           (overlays (altodo--create-overlays ranges)))
      (should (= (length overlays) 2))
      (should (overlayp (car overlays)))
      (should (overlayp (cadr overlays)))))
  (cleanup-test-buffer))

(ert-deftest test-create-overlays-invisible-property ()
  "Test that overlays have invisible property."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let* ((ranges '((10 . 20)))
           (overlays (altodo--create-overlays ranges)))
      (should (eq (overlay-get (car overlays) 'invisible) 'altodo-filter))))
  (cleanup-test-buffer))

(ert-deftest test-create-overlays-evaporate-property ()
  "Test that overlays have evaporate property."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let* ((ranges '((10 . 20)))
           (overlays (altodo--create-overlays ranges)))
      (should (eq (overlay-get (car overlays) 'evaporate) t))))
  (cleanup-test-buffer))

(ert-deftest test-create-overlays-empty ()
  "Test creating overlays for empty ranges."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (let ((overlays (altodo--create-overlays nil)))
      (should (null overlays))))
  (cleanup-test-buffer))


(provide 'filter-core-test)
