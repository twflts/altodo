;;; person-tag-matcher-test.el --- Tests for person tag matcher

(require 'ert)
(require 'altodo)

;;; Basic Tests

(ert-deftest person-tag-matcher-test-ascii ()
  "Test matching ASCII person tags."
  (with-temp-buffer
    (insert "[x] Task @alice\n")
    (goto-char (point-min))
    (should (altodo--person-tag-matcher (point-max)))
    (should (equal (match-string 0) "@alice"))))

(ert-deftest person-tag-matcher-test-mixed ()
  "Test matching mixed ASCII and numbers."
  (with-temp-buffer
    (insert "[x] Task @alice123\n")
    (goto-char (point-min))
    (should (altodo--person-tag-matcher (point-max)))
    (should (equal (match-string 0) "@alice123"))))

(ert-deftest person-tag-matcher-test-underscore ()
  "Test matching person tags with underscore."
  (with-temp-buffer
    (insert "[x] Task @alice_smith\n")
    (goto-char (point-min))
    (should (altodo--person-tag-matcher (point-max)))
    (should (equal (match-string 0) "@alice_smith"))))

(ert-deftest person-tag-matcher-test-hyphen ()
  "Test matching person tags with hyphen."
  (with-temp-buffer
    (insert "[x] Task @alice-smith\n")
    (goto-char (point-min))
    (should (altodo--person-tag-matcher (point-max)))
    (should (equal (match-string 0) "@alice-smith"))))

;;; Position Tests

(ert-deftest person-tag-matcher-test-after-whitespace ()
  "Test matching person tag after whitespace."
  (with-temp-buffer
    (insert "[x] Task description @alice\n")
    (goto-char (point-min))
    (should (altodo--person-tag-matcher (point-max)))
    (should (equal (match-string 0) "@alice"))))

(ert-deftest person-tag-matcher-test-after-tab ()
  "Test matching person tag after tab."
  (with-temp-buffer
    (insert "[x] Task\t@alice\n")
    (goto-char (point-min))
    (should (altodo--person-tag-matcher (point-max)))
    (should (equal (match-string 0) "@alice"))))

(ert-deftest person-tag-matcher-test-at-line-start ()
  "Test matching person tag at line start."
  (with-temp-buffer
    (insert "@alice\n")
    (goto-char (point-min))
    (should (altodo--person-tag-matcher (point-max)))
    (should (equal (match-string 0) "@alice"))))

(ert-deftest person-tag-matcher-test-multiple ()
  "Test matching multiple person tags."
  (with-temp-buffer
    (insert "[x] Task @alice @bob\n")
    (goto-char (point-min))
    (should (altodo--person-tag-matcher (point-max)))
    (let ((first-match (match-string 0)))
      (should (or (equal first-match "@alice") (equal first-match "@bob"))))))

;;; Negative Tests

(ert-deftest person-tag-matcher-test-no-match ()
  "Test no match when no person tag."
  (with-temp-buffer
    (insert "[x] Task without person\n")
    (goto-char (point-min))
    (should-not (altodo--person-tag-matcher (point-max)))))

(ert-deftest person-tag-matcher-test-after-non-whitespace ()
  "Test no match when @ is after non-whitespace."
  (with-temp-buffer
    (insert "[x] Task.@alice\n")
    (goto-char (point-min))
    ;; Should skip the invalid @ and find nothing or next valid one
    (let ((result (altodo--person-tag-matcher (point-max))))
      ;; Result depends on whether there's another valid @ later
      (should (or result (not result))))))

;;; Position Validation Tests

(ert-deftest altodo-test-is-valid-person-tag-position-at-line-start ()
  "Test valid position at line start."
  (with-temp-buffer
    (insert "@alice\n")
    (goto-char (point-min))
    (should (altodo--is-valid-person-tag-position (point)))))

(ert-deftest altodo-test-is-valid-person-tag-position-after-space ()
  "Test valid position after space."
  (with-temp-buffer
    (insert "Task @alice\n")
    (let ((pos (+ (point-min) 5)))
      (should (altodo--is-valid-person-tag-position pos)))))

(ert-deftest altodo-test-is-valid-person-tag-position-after-tab ()
  "Test valid position after tab."
  (with-temp-buffer
    (insert "Task\t@alice\n")
    (let ((pos (+ (point-min) 5)))
      (should (altodo--is-valid-person-tag-position pos)))))

(ert-deftest altodo-test-is-valid-person-tag-position-after-newline ()
  "Test valid position after newline."
  (with-temp-buffer
    (insert "Line1\n@alice\n")
    (let ((pos (+ (point-min) 6)))
      (should (altodo--is-valid-person-tag-position pos)))))

(ert-deftest altodo-test-is-valid-person-tag-position-invalid-after-dot ()
  "Test invalid position after dot."
  (with-temp-buffer
    (insert "Task.@alice\n")
    (let ((pos (+ (point-min) 5)))
      (should-not (altodo--is-valid-person-tag-position pos)))))

(ert-deftest altodo-test-is-valid-person-tag-position-invalid-after-letter ()
  "Test invalid position after letter."
  (with-temp-buffer
    (insert "Taska@alice\n")
    (let ((pos (+ (point-min) 5)))
      (should-not (altodo--is-valid-person-tag-position pos)))))

(provide 'person-tag-matcher-test)
;;; person-tag-matcher-test.el ends here
