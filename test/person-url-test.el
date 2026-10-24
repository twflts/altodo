;;; person-url-test.el --- Tests for @ inside a word and the dynamic :limit  -*- lexical-binding: t; -*-

;;; Commentary:
;; T20261019-7: an @ that is not at the beginning of the line or after a
;; space (the @ in a URL such as https://example.com/test@hogefuge, or in an
;; address) is not a person.  T20261019-6: `:limit 0' of a dynamic filter
;; means no limit.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defconst person-url-test--url "[ ] meeting https://example.com/test@hogefuge")

(defun person-url-test--persons (line)
  "Return the persons that the dynamic filter finds in the task LINE."
  (altodo-test-with-buffer line
    (altodo--line-extract-all-persons)))

(ert-deftest person-url-at-sign-in-url-is-not-a-person ()
  "The @ in a URL is not collected as a person."
  (should-not (person-url-test--persons person-url-test--url))
  (should-not (person-url-test--persons "[ ] mail john@example.com"))
  (should-not (person-url-test--persons "[ ] Teams https://teams.example.com/l/meetup-join/19%3a@thread.v2/0")))

(ert-deftest person-url-person-next-to-url ()
  "A person after a space is found even when the line has a URL with @."
  (should (equal (person-url-test--persons
                  "[ ] @john see https://example.com/test@hogefuge @mary")
                 '("john" "mary")))
  (should (equal (person-url-test--persons "[ ] https://a.com/x@y @bob")
                 '("bob"))))

(ert-deftest person-url-dynamic-values ()
  "The values collected for the dynamic filter do not have the URL's @."
  (let ((source (generate-new-buffer " person-url-source")))
    (unwind-protect
        (progn
          (with-current-buffer source
            (insert person-url-test--url "\n[ ] review @alice\n")
            (altodo-mode))
          (should (equal (altodo--collect-dynamic-values-with-exclude "person" source)
                         '(("alice" . 1)))))
      (kill-buffer source))))

(ert-deftest person-url-person-filter-ignores-url ()
  "The pattern `person:NAME' does not match the @ in a URL."
  (altodo-test-with-buffer (concat person-url-test--url "\n")
    (should-not (altodo--line-has-person-p "hogefuge"))
    (should-not (funcall (altodo--compile-simple-pattern "person:hogefuge"))))
  (altodo-test-with-buffer "[ ] review @alice\n"
    (should (altodo--line-has-person-p "alice")))
  (altodo-test-with-buffer "[@] @alice review\n"
    (should (altodo--line-has-person-p "alice"))))

(ert-deftest person-url-filter-show-person-ignores-url ()
  "`altodo-filter-show-person' does not show a line that has the @ in a URL."
  (altodo-test-with-buffer (concat person-url-test--url "\n[ ] review @hogefuge\n")
    (altodo-filter-show-person "hogefuge")
    (should (seq-some (lambda (ov) (overlay-get ov 'invisible))
                      (overlays-in 1 2)))
    (altodo-filter-clear)))

(ert-deftest dynamic-limit-zero-means-unlimited ()
  "`:limit 0' and `:limit nil' return all values; a positive limit cuts."
  (let ((alist '(("a" . 3) ("b" . 2) ("c" . 1))))
    (should (equal (altodo--limit-dynamic-values alist 0) alist))
    (should (equal (altodo--limit-dynamic-values alist nil) alist))
    (should (equal (altodo--limit-dynamic-values alist 2) '(("a" . 3) ("b" . 2))))
    (should (equal (altodo--limit-dynamic-values alist 9) alist))))

(ert-deftest dynamic-limit-zero-expands-all-persons ()
  "A person dynamic filter with `:limit 0' lists every person."
  (let ((source (generate-new-buffer " person-limit-source")))
    (unwind-protect
        (progn
          (with-current-buffer source
            (insert "[ ] @a @b @c\n")
            (altodo-mode))
          (dolist (limit '(0 nil))
            (should (= (length (altodo--expand-dynamic-filter
                                (list :title "@%s" :type 'dynamic
                                      :dynamic-type "person" :limit limit)
                                source))
                       3)))
          (should (= (length (altodo--expand-dynamic-filter
                              (list :title "@%s" :type 'dynamic
                                    :dynamic-type "person" :limit 2)
                              source))
                     2)))
      (kill-buffer source))))

(provide 'person-url-test)
;;; person-url-test.el ends here
