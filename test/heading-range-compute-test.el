;;; heading-range-compute-test.el --- 見出し範囲の一括計算のテスト  -*- lexical-binding: t; -*-

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defun heading-range-compute-test--ranges (text)
  "Return the heading ranges of TEXT as (heading-text start end) lists.
Positions are line numbers (1-origin): start is the first line after the
heading, end is the line that ends the range (or the last line + 1)."
  (altodo-test-with-buffer text
    (mapcar (lambda (entry)
              (list (car entry)
                    (line-number-at-pos (cadr entry))
                    (line-number-at-pos (cddr entry))))
            (altodo--compute-all-heading-ranges))))

(ert-deftest heading-range-compute-nested-levels ()
  "A range ends at the next heading of the same or a higher level."
  (should (equal (heading-range-compute-test--ranges
                  "# A\n[ ] a\n## B\n[ ] b\n### C\n[ ] c\n## D\n[ ] d\n# E\n[ ] e\n")
                 '(("A" 2 9) ("B" 4 7) ("C" 6 7) ("D" 8 9) ("E" 10 11)))))

(ert-deftest heading-range-compute-duplicate-headings ()
  "Headings with the same text get their own ranges, in buffer order."
  (should (equal (heading-range-compute-test--ranges
                  "# Work\n[ ] a\n# Home\n[ ] b\n# Work\n[ ] c\n")
                 '(("Work" 2 3) ("Home" 4 5) ("Work" 6 7)))))

(ert-deftest heading-range-compute-special-characters ()
  "Regexp special characters in heading text are kept as text."
  (should (equal (mapcar #'car (heading-range-compute-test--ranges
                                "# C++ (draft) [1]\n[ ] a\n## a.b*c\n[ ] b\n"))
                 '("C++ (draft) [1]" "a.b*c"))))

(ert-deftest heading-range-compute-without-headings ()
  "A buffer without headings gives no ranges."
  (should-not (heading-range-compute-test--ranges "[ ] a\n[ ] b\n")))

(ert-deftest heading-range-compute-last-heading-reaches-end ()
  "The range of the last heading ends at the end of the buffer."
  (altodo-test-with-buffer "# A\n[ ] a\n[ ] b"
    (let ((range (cdr (car (altodo--compute-all-heading-ranges)))))
      (should (= (cdr range) (point-max))))))

(ert-deftest heading-range-compute-heading-without-body ()
  "A heading directly followed by a heading of the same level has an empty range."
  (should (equal (heading-range-compute-test--ranges "# A\n# B\n[ ] b\n")
                 '(("A" 2 2) ("B" 3 4)))))

(ert-deftest heading-range-compute-setext-level ()
  "`altodo--heading-level' recognizes Setext headings without counting lines."
  (altodo-test-with-buffer "Title\n=====\n[ ] a\nSub\n---\nlast line"
    (should (= (altodo--heading-level) 1))
    (forward-line 2)
    (should-not (altodo--heading-level))
    (forward-line 1)
    (should (= (altodo--heading-level) 2))
    (forward-line 2)
    (should-not (altodo--heading-level))))

(ert-deftest heading-range-compute-line-ranges ()
  "`altodo--heading-line-ranges' gives (HEADING-LINE START-LINE END-LINE)."
  (altodo-test-with-buffer "# A\n[ ] a\n## B\n[ ] b\n# C\n[ ] c\n"
    (should (equal (append (altodo--heading-line-ranges
                            (altodo--compute-all-heading-ranges))
                           nil)
                   '((1 2 5) (3 4 5) (5 6 7))))))

(ert-deftest heading-range-compute-map-lines-to-headings ()
  "Each line maps to the headings containing it, outer heading first."
  (altodo-test-with-buffer "# A\n[ ] a\n## B\n[ ] b\n# C\n[ ] c\n"
    (let* ((ranges (altodo--heading-line-ranges
                    (altodo--compute-all-heading-ranges)))
           (table (altodo--map-lines-to-headings '(6 2 4 4) ranges)))
      (should (equal (gethash 2 table) '(0)))
      (should (equal (gethash 4 table) '(0 1)))
      (should (equal (gethash 6 table) '(2)))
      (should-not (gethash 3 table)))))

(ert-deftest heading-range-compute-display-lines-add-headings ()
  "A matched line adds its headings and the lines around them."
  (altodo-test-with-buffer "# A\n[ ] a\n## B\n[ ] b\n# C\n[ ] c\n"
    (should (equal (sort (altodo--compute-display-lines '(4) 'heading-only) #'<)
                   '(1 2 3 4)))
    (should (equal (altodo--compute-display-lines '(4) 'none) '(4)))))

(ert-deftest heading-range-compute-display-lines-comment-at-buffer-end ()
  "A matched last line without a final newline does not add missing lines."
  (altodo-test-with-buffer "[ ] a\n    comment\n[ ] b"
    (should (equal (sort (altodo--compute-display-lines '(1 3) 'all) #'<)
                   '(1 2 3)))
    (should (equal (sort (altodo--compute-display-lines '(3) 'all) #'<)
                   '(3)))))

(ert-deftest heading-range-compute-filter-keeps-overlay-list-live ()
  "After `altodo--filter-lines', the overlay list holds only live overlays."
  (altodo-test-with-buffer "# A\n[ ] a\n[x] b\n[ ] c\n"
    (altodo--filter-lines (lambda () (looking-at "\\[ \\]")) t 'all)
    (should altodo--filter-overlays)
    (should (cl-every #'overlay-buffer altodo--filter-overlays))
    (should (= (length altodo--filter-overlays) 1))))

(provide 'heading-range-compute-test)
;;; heading-range-compute-test.el ends here
