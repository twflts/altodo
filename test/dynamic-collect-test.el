;;; dynamic-collect-test.el --- Tests for dynamic filter functionality

(require 'ert)
(require 'altodo)

;;; Basic Tests

(ert-deftest dynamic-collect-test-collect-person ()
  "Test collecting @person values from buffer."
  (with-temp-buffer
    (insert "[x] Task A @alice\n")
    (insert "[x] Task B @alice\n")
    (insert "[x] Task C @bob\n")
    (let ((result (altodo--collect-dynamic-values "person" (current-buffer))))
      (should (equal (length result) 2))
      (should (assoc "alice" result))
      (should (assoc "bob" result))
      (should (= (cdr (assoc "alice" result)) 2))
      (should (= (cdr (assoc "bob" result)) 1)))))

(ert-deftest dynamic-collect-test-collect-tag-ignore-value-t ()
  "Test collecting #tag names with tag-mode name-only."
  (with-temp-buffer
    (insert "[x] Task A #tag:important\n")
    (insert "[x] Task B #tag:urgent\n")
    (insert "[x] Task C #tag:important\n")
    (let ((result (altodo--collect-dynamic-values "tag" (current-buffer) "name-only")))
      (should (equal (length result) 1))
      (should (assoc "tag" result))
      (should (= (cdr (assoc "tag" result)) 3)))))

(ert-deftest dynamic-collect-test-collect-tag-ignore-value-nil ()
  "Test collecting #tag values with tag-mode with-value."
  (with-temp-buffer
    (insert "[x] Task A #priority:high\n")
    (insert "[x] Task B #priority:high\n")
    (insert "[x] Task C #priority:low\n")
    (let ((result (altodo--collect-dynamic-values "tag" (current-buffer) "with-value")))
      (should (equal (length result) 2))
      (should (assoc "priority:high" result))
      (should (assoc "priority:low" result))
      (should (= (cdr (assoc "priority:high" result)) 2))
      (should (= (cdr (assoc "priority:low" result)) 1)))))

(ert-deftest dynamic-collect-test-collect-due ()
  "Test collecting the due dates (-> DATE) from buffer."
  (with-temp-buffer
    (insert "[x] Task A -> 2026-03-05\n")
    (insert "[x] Task B -> 2026-03-05\n")
    (insert "[x] Task C -> 2026-03-10\n")
    (let ((result (altodo--collect-dynamic-values "due" (current-buffer))))
      (should (equal (length result) 2))
      (should (assoc "2026-03-05" result))
      (should (assoc "2026-03-10" result))
      (should (= (cdr (assoc "2026-03-05" result)) 2))
      (should (= (cdr (assoc "2026-03-10" result)) 1)))))

(ert-deftest dynamic-collect-test-collect-start ()
  "Test collecting the start dates (DATE ->) from buffer."
  (with-temp-buffer
    (insert "[x] Task A 2026-03-05 ->\n")
    (insert "[x] Task B 2026-03-10 ->\n")
    (insert "[x] Task C 2026-03-10 ->\n")
    (let ((result (altodo--collect-dynamic-values "start" (current-buffer))))
      (should (equal (length result) 2))
      (should (assoc "2026-03-05" result))
      (should (assoc "2026-03-10" result))
      (should (= (cdr (assoc "2026-03-05" result)) 1))
      (should (= (cdr (assoc "2026-03-10" result)) 2)))))

;;; Sort & Limit Tests

(ert-deftest dynamic-collect-test-sort-alpha ()
  "Test sorting by alphabetical order."
  (let ((alist '(("charlie" . 1) ("alice" . 3) ("bob" . 2)))
        (result (altodo--sort-dynamic-values '(("charlie" . 1) ("alice" . 3) ("bob" . 2)) "alpha")))
    (should (equal (mapcar 'car result) '("alice" "bob" "charlie")))))

(ert-deftest dynamic-collect-test-sort-count ()
  "Test sorting by count descending."
  (let ((result (altodo--sort-dynamic-values '(("charlie" . 1) ("alice" . 3) ("bob" . 2)) "count")))
    (should (equal (mapcar 'car result) '("alice" "bob" "charlie")))
    (should (equal (mapcar 'cdr result) '(3 2 1)))))

(ert-deftest dynamic-collect-test-limit ()
  "Test limiting results."
  (let* ((alist '(("a" . 1) ("b" . 2) ("c" . 3) ("d" . 4) ("e" . 5)))
         (result (altodo--limit-dynamic-values alist 3)))
    (should (equal (length result) 3))
    (should (equal (mapcar 'car result) '("a" "b" "c")))))

;;; Placeholder Tests

(ert-deftest dynamic-collect-test-format-placeholder-s ()
  "Test %s placeholder replacement."
  (let ((result (altodo--format-placeholder "@%s [%n]" '(("s" . "alice")))))
    (should (equal result "@alice [%n]"))))

(ert-deftest dynamic-collect-test-format-placeholder-n ()
  "Test %n placeholder replacement."
  (let ((result (altodo--format-placeholder "@%s [%n]" '(("n" . "3")))))
    (should (equal result "@%s [3]"))))

(ert-deftest dynamic-collect-test-format-placeholder-both ()
  "Test both %s and %n placeholder replacement."
  (let ((result (altodo--format-placeholder "@%s [%n]" '(("s" . "alice") ("n" . "3")))))
    (should (equal result "@alice [3]"))))

;;; Expand Dynamic Filter Tests

(ert-deftest dynamic-collect-test-expand-person ()
  "Test expanding person dynamic filter."
  (with-temp-buffer
    (insert "[x] Task A @alice\n")
    (insert "[x] Task B @alice\n")
    (insert "[x] Task C @bob\n")
    (let* ((entry '(:title "@%s [%n]" :type dynamic :dynamic-type "person" :count-format t))
           (result (altodo--expand-dynamic-filter entry (current-buffer))))
      (should (equal (length result) 2))
      (should (equal (plist-get (car result) :title) "@alice [%n]"))
      (should (equal (plist-get (car result) :pattern) "person:alice")))))

(ert-deftest dynamic-collect-test-expand-tag ()
  "Test expanding tag dynamic filter."
  (with-temp-buffer
    (insert "[x] Task A #priority:high\n")
    (insert "[x] Task B #priority:high\n")
    (insert "[x] Task C #priority:low\n")
    (let* ((entry '(:title "#%s [%n]" :type dynamic :dynamic-type "tag" :tag-mode "with-value" :count-format t))
           (result (altodo--expand-dynamic-filter entry (current-buffer))))
      (should (equal (length result) 2))
      (should (equal (plist-get (car result) :title) "#priority:high [%n]"))
      (should (equal (plist-get (car result) :pattern) "tag:priority:high")))))

(ert-deftest dynamic-collect-test-expand-due ()
  "Test expanding due dynamic filter."
  (with-temp-buffer
    (insert "[x] Task A -> 2026-03-05\n")
    (insert "[x] Task B -> 2026-03-10\n")
    (let* ((entry '(:title "Due: %s [%n]" :type dynamic :dynamic-type "due" :count-format t))
           (result (altodo--expand-dynamic-filter entry (current-buffer))))
      (should (equal (length result) 2))
      (should (equal (plist-get (car result) :pattern) "due-date:2026-03-05")))))

;;; Complex Tests

(ert-deftest dynamic-collect-test-complex-sort-and-limit ()
  "Test sorting by count and limiting results."
  (with-temp-buffer
    (insert "[x] Task A @alice\n")
    (insert "[x] Task B @alice\n")
    (insert "[x] Task C @alice\n")
    (insert "[x] Task D @bob\n")
    (insert "[x] Task E @bob\n")
    (insert "[x] Task F @charlie\n")
    (let* ((entry '(:title "@%s [%n]" :type dynamic :dynamic-type "person" :sort-by "count" :limit 2 :count-format t))
           (result (altodo--expand-dynamic-filter entry (current-buffer))))
      (should (equal (length result) 2))
      (should (equal (plist-get (car result) :title) "@alice [%n]"))
      (should (equal (plist-get (cadr result) :title) "@bob [%n]")))))

(ert-deftest dynamic-collect-test-complex-mixed-tags ()
  "Test collecting mixed tag names and values."
  (with-temp-buffer
    (insert "[x] Task A #priority:high\n")
    (insert "[x] Task B #priority:high\n")
    (insert "[x] Task C #priority:low\n")
    (insert "[x] Task D #status:open\n")
    (let ((result (altodo--collect-dynamic-values "tag" (current-buffer) "with-value")))
      (should (equal (length result) 3))
      (should (assoc "priority:high" result))
      (should (assoc "priority:low" result))
      (should (assoc "status:open" result)))))

(ert-deftest dynamic-collect-test-complex-tag-ignore-value ()
  "Test collecting tag names only with multiple tags."
  (with-temp-buffer
    (insert "[x] Task A #priority:high\n")
    (insert "[x] Task B #priority:high\n")
    (insert "[x] Task C #priority:low\n")
    (insert "[x] Task D #status:open\n")
    (let ((result (altodo--collect-dynamic-values "tag" (current-buffer) "name-only")))
      (should (equal (length result) 2))
      (should (assoc "priority" result))
      (should (assoc "status" result))
      (should (= (cdr (assoc "priority" result)) 3))
      (should (= (cdr (assoc "status" result)) 1)))))

(ert-deftest dynamic-collect-test-complex-multiple-persons ()
  "Test collecting persons (only first person per line)."
  (with-temp-buffer
    (insert "[x] Task A @alice\n")
    (insert "[x] Task B @alice\n")
    (insert "[x] Task C @charlie\n")
    (let ((result (altodo--collect-dynamic-values "person" (current-buffer))))
      ;; Only first person is extracted per line
      (should (equal (length result) 2))
      (should (assoc "alice" result))
      (should (assoc "charlie" result))
      (should (= (cdr (assoc "alice" result)) 2))
      (should (= (cdr (assoc "charlie" result)) 1)))))

(ert-deftest dynamic-collect-test-complex-dates-multiple ()
  "Test collecting multiple dates with different counts."
  (with-temp-buffer
    (insert "[x] Task A -> 2026-03-05\n")
    (insert "[x] Task B -> 2026-03-05\n")
    (insert "[x] Task C -> 2026-03-05\n")
    (insert "[x] Task D -> 2026-03-10\n")
    (insert "[x] Task E -> 2026-03-15\n")
    (let* ((entry '(:title "Due: %s [%n]" :type dynamic :dynamic-type "due" :limit 2 :count-format t))
           (result (altodo--expand-dynamic-filter entry (current-buffer))))
      (should (equal (length result) 2))
      (should (equal (plist-get (car result) :title) "Due: 2026-03-05 [%n]"))
      (should (equal (plist-get (cadr result) :title) "Due: 2026-03-10 [%n]")))))

(ert-deftest dynamic-collect-test-due-sort-by ()
  "`:sort-by' applies to the dates: ascending by default, then by count."
  (with-temp-buffer
    (insert "[ ] A -> 2026-03-20\n[ ] B -> 2026-03-20\n[ ] C -> 2026-03-05\n")
    (altodo-mode)
    (cl-flet ((titles (entry)
                (mapcar (lambda (e) (plist-get e :title))
                        (altodo--expand-dynamic-filter entry (current-buffer)))))
      (should (equal (titles '(:title "%s" :type dynamic :dynamic-type "due"))
                     '("2026-03-05" "2026-03-20")))
      (should (equal (titles '(:title "%s" :type dynamic :dynamic-type "due"
                               :sort-by "count"))
                     '("2026-03-20" "2026-03-05"))))))

(ert-deftest dynamic-collect-test-due-counts-and-pattern ()
  "The entry of a due date counts the tasks that the pattern matches."
  (with-temp-buffer
    (insert "[ ] A -> 2026-03-20\n[x] B -> 2026-03-20\n[ ] C 2026-03-20 ->\n")
    (altodo-mode)
    (let ((entry (car (altodo--expand-dynamic-filter
                       '(:title "%s" :type dynamic :dynamic-type "due")
                       (current-buffer)))))
      (should (equal (plist-get entry :pattern) "due-date:2026-03-20"))
      (should (= (altodo--compute-entry-count entry (current-buffer)) 2)))))

(ert-deftest dynamic-collect-test-due-uses-the-date-format ()
  "The title and the pattern of a date use `altodo-date-format'."
  (let ((altodo-date-format "%Y/%m/%d"))
    (with-temp-buffer
      (insert "[ ] A -> 2026/03/20\n")
      (altodo-mode)
      (let ((entry (car (altodo--expand-dynamic-filter
                         '(:title "%s" :type dynamic :dynamic-type "due")
                         (current-buffer)))))
        (should (equal (plist-get entry :title) "2026/03/20"))
        (should (equal (plist-get entry :pattern) "due-date:2026/03/20"))
        (should (= (altodo--compute-entry-count entry (current-buffer)) 1))))))

(ert-deftest dynamic-collect-test-date-that-does-not-exist-is-left-out ()
  "A date that does not exist makes no entry (its pattern would be invalid)."
  (with-temp-buffer
    (insert "[ ] A -> 2026-02-30\n")
    (altodo-mode)
    (should-not (altodo--collect-dynamic-values "due" (current-buffer)))))

(ert-deftest dynamic-collect-test-dynamic-type-as-symbol ()
  "A symbol such as `person' is the same as the string \"person\"."
  (with-temp-buffer
    (insert "[ ] A @bob #java\n")
    (altodo-mode)
    (dolist (type '(person "person"))
      (should (equal (mapcar (lambda (e) (plist-get e :title))
                             (altodo--expand-dynamic-filter
                              (list :title "%s" :type 'dynamic
                                    :dynamic-type type)
                              (current-buffer)))
                     '("bob"))))))

(ert-deftest dynamic-collect-test-exclusion-is-exact ()
  "An exclusion is the whole name, in any case, with or without # or @."
  (with-temp-buffer
    (insert "[ ] A #id:1 #idea #Video #dependency #dep:1 #java @bob @bobby @Rob\n")
    (altodo-mode)
    (cl-flet ((titles (entry)
                (mapcar (lambda (e) (plist-get e :title))
                        (altodo--expand-dynamic-filter entry (current-buffer)))))
      (should (equal (titles '(:title "%s" :type dynamic :dynamic-type "tag"
                               :exclude-tag ("ID" "#dep" "video")))
                     '("dependency" "idea" "java")))
      (should (equal (titles '(:title "%s" :type dynamic :dynamic-type "person"
                               :exclude-person ("@bob" "rob")))
                     '("bobby")))
      (should (equal (titles '(:title "%s" :type dynamic :dynamic-type "tag"
                               :tag-mode "all"
                               :exclude-tag-value ("id:1")))
                     '("dep:1" "dependency" "idea" "java" "Video"))))))

(ert-deftest dynamic-collect-test-sort-is-not-read ()
  "`:sort' is not a property: the order stays ascending."
  (with-temp-buffer
    (insert "[ ] A @bob\n[ ] B @bob\n[ ] C @ann\n")
    (altodo-mode)
    (let ((titles (mapcar (lambda (e) (plist-get e :title))
                          (altodo--expand-dynamic-filter
                           '(:title "%s" :type dynamic :dynamic-type "person"
                             :sort "count")
                           (current-buffer)))))
      (should (equal titles '("ann" "bob"))))))

(ert-deftest dynamic-collect-test-complex-empty-buffer ()
  "Test collecting from empty buffer."
  (with-temp-buffer
    (let ((result (altodo--collect-dynamic-values "person" (current-buffer))))
      (should (equal (length result) 0)))))

(ert-deftest dynamic-collect-test-complex-no-matching-values ()
  "Test collecting when no matching values exist."
  (with-temp-buffer
    (insert "[x] Task A\n")
    (insert "[x] Task B\n")
    (let ((result (altodo--collect-dynamic-values "person" (current-buffer))))
      (should (equal (length result) 0)))))

(ert-deftest dynamic-collect-test-complex-nested-filter ()
  "Test expanding filter with nest parameter."
  (with-temp-buffer
    (insert "[x] Task A @alice\n")
    (insert "[x] Task B @bob\n")
    (let* ((entry '(:title "@%s" :type dynamic :dynamic-type "person" :nest 2 :count-format nil))
           (result (altodo--expand-dynamic-filter entry (current-buffer))))
      (should (equal (length result) 2))
      (should (equal (plist-get (car result) :nest) 2))
      (should (equal (plist-get (cadr result) :nest) 2)))))

(ert-deftest dynamic-collect-test-complex-face-inheritance ()
  "Test that face and face-count are inherited in expanded entries."
  (with-temp-buffer
    (insert "[x] Task A @alice\n")
    (insert "[x] Task B @bob\n")
    (let* ((entry '(:title "@%s [%n]" :type dynamic :dynamic-type "person" :face altodo-person-face :face-count altodo-count-face :count-format t))
           (result (altodo--expand-dynamic-filter entry (current-buffer))))
      (should (equal (length result) 2))
      (should (equal (plist-get (car result) :face) 'altodo-person-face))
      (should (equal (plist-get (car result) :face-count) 'altodo-count-face)))))

(ert-deftest dynamic-collect-test-complex-sidebar-render ()
  "Test sidebar rendering with dynamic filter."
  (let ((source-buffer (get-buffer-create "*test-source*"))
        (sidebar-buffer (get-buffer-create "*test-sidebar*")))
    (unwind-protect
        (progn
          (with-current-buffer source-buffer
            (insert "[x] Task A @alice\n")
            (insert "[x] Task B @alice\n")
            (insert "[x] Task C @bob\n"))
          (let ((config `(:source-buffer ,source-buffer
                          :indent 2
                          :entries ((:title "@%s [%n]" :type dynamic :dynamic-type "person" :count-format t)))))
            (altodo-sidebar--render sidebar-buffer config)
            (with-current-buffer sidebar-buffer
              (let ((content (buffer-string)))
                (should (string-match "@alice \\[2\\]" content))
                (should (string-match "@bob \\[1\\]" content))))))
      (kill-buffer source-buffer)
      (kill-buffer sidebar-buffer))))

(provide 'dynamic-collect-test)
;;; dynamic-collect-test.el ends here
