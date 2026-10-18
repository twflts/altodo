;;; flag-combination-test.el --- Tests for star and priority flags used together  -*- lexical-binding: t; -*-

;;; Commentary:
;; A line can have a star flag and a priority flag together, in either order.
;; The commands write the star first.

;;; Code:

(require 'ert)
(require 'altodo)
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'altodo-test-helper)

(defun flag-combination-test--after (text &rest body)
  "Return the text of a buffer holding TEXT after running BODY at its start."
  (altodo-test-with-buffer text
    (eval `(progn ,@body) t)
    (buffer-substring-no-properties (point-min) (point-max))))

(ert-deftest flag-combination-test-parse-flags ()
  (dolist (case '(("+ !! text" (t 2 "text"))
                  ("!! + text" (t 2 "text"))
                  ("  + text" (t nil "text"))
                  ("!!!! text" (nil 3 "text"))
                  ("++ text" (nil nil "++ text"))
                  ("+ + text" (t nil "+ text"))
                  ("! !! text" (nil 1 "!! text"))
                  ("+text" (nil nil "+text"))
                  ("+ " (t nil ""))))
    (should (equal (altodo--parse-flags (car case)) (cadr case)))))

(ert-deftest flag-combination-test-format-flags ()
  (should (equal (altodo--format-flags t 2 "text") "+ !! text"))
  (should (equal (altodo--format-flags t nil "text") "+ text"))
  (should (equal (altodo--format-flags nil 3 "") "!!!"))
  (should (equal (altodo--format-flags nil nil "text") "text")))

(ert-deftest flag-combination-test-set-priority-keeps-star ()
  (should (equal (flag-combination-test--after "[ ] + a\n"
                   '(altodo-set-priority-1))
                 "[ ] + ! a\n"))
  (should (equal (flag-combination-test--after "[ ] ! + a\n"
                   '(altodo-set-priority-2))
                 "[ ] + !! a\n"))
  (should (equal (flag-combination-test--after "/// + note\n"
                   '(altodo-set-priority-3))
                 "/// + !!! note\n")))

(ert-deftest flag-combination-test-toggle-star-keeps-priority ()
  (should (equal (flag-combination-test--after "[ ] !! a\n"
                   '(altodo-toggle-star-flag))
                 "[ ] + !! a\n"))
  (should (equal (flag-combination-test--after "[ ] + !! a\n"
                   '(altodo-toggle-star-flag))
                 "[ ] !! a\n"))
  (should (equal (flag-combination-test--after "[ ] !! + a\n"
                   '(altodo-toggle-star-flag))
                 "[ ] !! a\n")))

(ert-deftest flag-combination-test-predicates ()
  (dolist (text '("[ ] + !! a\n" "[ ] !! + a\n"))
    (altodo-test-with-buffer text
      (should (altodo--line-has-star-p))
      (should (altodo--line-has-priority-p))
      (should (= (altodo--get-priority-level) 2))))
  (altodo-test-with-buffer "[ ] ++ a\n"
    (should-not (altodo--line-has-star-p))
    (should-not (altodo--line-has-priority-p)))
  (altodo-test-with-buffer "/// + !! note\n"
    (should (= (altodo--get-priority-level) 2))))

(ert-deftest flag-combination-test-dsl-patterns ()
  (altodo-test-with-buffer "[ ] + !! a\n"
    (should (funcall (altodo--compile-simple-pattern "and:star,priority")))))

(defun flag-combination-test--has-face (text column face)
  "Return non-nil if FACE is applied at COLUMN of the first line of TEXT."
  (altodo-test-with-buffer text
    (font-lock-ensure)
    (let ((faces (get-text-property (+ (point-min) column) 'face)))
      (memq face (if (listp faces) faces (list faces))))))

(ert-deftest flag-combination-test-faces ()
  "Both flags get their own face, in either order."
  (should (flag-combination-test--has-face "[ ] + !! text\n" 4
                                           'altodo-flag-star-face))
  (should (flag-combination-test--has-face "[ ] + !! text\n" 6
                                           'altodo-flag-priority2-face))
  (should (flag-combination-test--has-face "[ ] !!! + text\n" 4
                                           'altodo-flag-priority3-face))
  (should (flag-combination-test--has-face "[ ] !!! + text\n" 8
                                           'altodo-flag-star-face)))

(provide 'flag-combination-test)
;;; flag-combination-test.el ends here
