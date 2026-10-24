;;; dynamic-filter-test.el --- Tests for dynamic filter tag/person extraction

;;; Commentary:
;; Tests for dynamic tag and person filter extraction.

;;; Code:

(require 'ert)
(require 'altodo)

;;; altodo--line-extract-all-tags tests

(ert-deftest dynamic-filter-test-extract-tags-name-only ()
  "Extract tags in name-only mode."
  (with-temp-buffer
    (insert "[ ] Task #java #priority:high #git\n")
    (altodo-mode)
    (goto-char (point-min))
    (let ((tags (altodo--line-extract-all-tags "name-only")))
      (should (member "java" tags))
      (should (member "priority" tags))
      (should (member "git" tags))
      (should (= 3 (length tags))))))

(ert-deftest dynamic-filter-test-extract-tags-all ()
  "Extract tags in all mode."
  (with-temp-buffer
    (insert "[ ] Task #java #priority:high\n")
    (altodo-mode)
    (goto-char (point-min))
    (let ((tags (altodo--line-extract-all-tags "all")))
      (should (member "java" tags))
      (should (member "priority:high" tags))
      (should (= 2 (length tags))))))

(ert-deftest dynamic-filter-test-extract-tags-with-value ()
  "Extract tags in with-value mode."
  (with-temp-buffer
    (insert "[ ] Task #java #priority:high #owner:john\n")
    (altodo-mode)
    (goto-char (point-min))
    (let ((tags (altodo--line-extract-all-tags "with-value")))
      (should (member "priority:high" tags))
      (should (member "owner:john" tags))
      (should-not (member "java" tags))
      (should (= 2 (length tags))))))

(ert-deftest dynamic-filter-test-extract-tags-no-tags ()
  "Extract tags from line without tags."
  (with-temp-buffer
    (insert "[ ] Task without tags\n")
    (altodo-mode)
    (goto-char (point-min))
    (let ((tags (altodo--line-extract-all-tags "name-only")))
      (should (null tags)))))

(ert-deftest dynamic-filter-test-extract-tags-special-tags ()
  "Extract special tags (id, dep, done)."
  (with-temp-buffer
    (insert "[ ] Task #id:001 #dep:002 #done:2026-01-01\n")
    (altodo-mode)
    (goto-char (point-min))
    (let ((tags (altodo--line-extract-all-tags "name-only")))
      (should (member "id" tags))
      (should (member "dep" tags))
      (should (member "done" tags)))))

(ert-deftest dynamic-filter-test-extract-tags-quoted-value ()
  "Extract tags with quoted values."
  (with-temp-buffer
    (insert "[ ] Task #owner:\"john doe\"\n")
    (altodo-mode)
    (goto-char (point-min))
    (let ((tags (altodo--line-extract-all-tags "all")))
      (should (member "owner:john doe" tags)))))

;;; altodo--line-extract-all-persons tests

(ert-deftest dynamic-filter-test-extract-persons-single ()
  "Extract single person."
  (with-temp-buffer
    (insert "[ ] Task @john\n")
    (altodo-mode)
    (goto-char (point-min))
    (let ((persons (altodo--line-extract-all-persons)))
      (should (equal '("john") persons)))))

(ert-deftest dynamic-filter-test-extract-persons-multiple ()
  "Extract multiple persons from same line."
  (with-temp-buffer
    (insert "[@] + Gather requirements @john @mary\n")
    (altodo-mode)
    (goto-char (point-min))
    (let ((persons (altodo--line-extract-all-persons)))
      (should (member "john" persons))
      (should (member "mary" persons))
      (should (= 2 (length persons))))))

(ert-deftest dynamic-filter-test-extract-persons-none ()
  "Extract persons from line without persons."
  (with-temp-buffer
    (insert "[ ] Task without persons\n")
    (altodo-mode)
    (goto-char (point-min))
    (let ((persons (altodo--line-extract-all-persons)))
      (should (null persons)))))

(ert-deftest dynamic-filter-test-extract-persons-special-chars ()
  "Extract persons with special characters."
  (with-temp-buffer
    (insert "[ ] Task @john-doe @mary_smith\n")
    (altodo-mode)
    (goto-char (point-min))
    (let ((persons (altodo--line-extract-all-persons)))
      (should (member "john-doe" persons))
      (should (member "mary_smith" persons)))))

;;; altodo--collect-dynamic-values-with-exclude tests

(ert-deftest dynamic-filter-test-collect-tags-exclude ()
  "Collect tags with exclusion."
  (with-temp-buffer
    (insert "[ ] Task #java #id:001 #dep:002\n")
    (insert "[ ] Task #git #done:2026-01-01\n")
    (altodo-mode)
    (let ((tags (altodo--collect-dynamic-values-with-exclude
                 "tag" (current-buffer) "name-only" nil '("id" "dep" "done") nil nil)))
      (should (assoc "java" tags))
      (should (assoc "git" tags))
      (should-not (assoc "id" tags))
      (should-not (assoc "dep" tags))
      (should-not (assoc "done" tags)))))

(ert-deftest dynamic-filter-test-collect-persons-multiple-per-line ()
  "Collect persons with multiple per line."
  (with-temp-buffer
    (insert "[@] Task @john @mary\n")
    (insert "[ ] Task @john @designer\n")
    (altodo-mode)
    (let ((persons (altodo--collect-dynamic-values-with-exclude "person" (current-buffer))))
      (should (equal 2 (cdr (assoc "john" persons))))
      (should (equal 1 (cdr (assoc "mary" persons))))
      (should (equal 1 (cdr (assoc "designer" persons)))))))

;;; Edge cases

(ert-deftest dynamic-filter-test-empty-line ()
  "Extract from empty line returns nil."
  (with-temp-buffer
    (insert "\n")
    (altodo-mode)
    (goto-char (point-min))
    (should (null (altodo--line-extract-all-tags "name-only")))
    (should (null (altodo--line-extract-all-persons)))))

(ert-deftest dynamic-filter-test-non-task-line ()
  "Extract from non-task line returns nil for persons."
  (with-temp-buffer
    (insert "This is not a task line @john #java\n")
    (altodo-mode)
    (goto-char (point-min))
    ;; Tags are extracted from any line
    (should (member "java" (altodo--line-extract-all-tags "name-only")))
    ;; Persons require task body (altodo--line-task-body returns nil for non-task)
    (should (null (altodo--line-extract-all-persons)))))

(ert-deftest dynamic-filter-test-comment-line ()
  "Extract from comment line."
  (with-temp-buffer
    (insert "/// Comment #java @john\n")
    (altodo-mode)
    (goto-char (point-min))
    ;; Tags are extracted from comment lines
    (should (member "java" (altodo--line-extract-all-tags "name-only")))
    ;; Persons require task body
    (should (null (altodo--line-extract-all-persons)))))

;;; Integration tests

(ert-deftest dynamic-filter-test-comprehensive-file ()
  "Test with comprehensive.altodo file."
  (with-temp-buffer
    (insert-file-contents "testfiles/comprehensive.altodo")
    (altodo-mode)
    (let ((tags (altodo--collect-dynamic-values-with-exclude
                 "tag" (current-buffer) "name-only" nil '("id" "dep" "done") nil nil))
          (persons (altodo--collect-dynamic-values-with-exclude "person" (current-buffer))))
      ;; Tags should include java, git
      (should (assoc "java" tags))
      (should (assoc "git" tags))
      ;; Tags should exclude id, dep, done
      (should-not (assoc "id" tags))
      (should-not (assoc "dep" tags))
      (should-not (assoc "done" tags))
      ;; Persons should include john, mary
      (should (assoc "john" persons))
      (should (assoc "mary" persons)))))

(provide 'dynamic-filter-test)
;;; dynamic-filter-test.el ends here
