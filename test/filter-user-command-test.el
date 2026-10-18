;;; filter-user-command-test.el --- Tests for filter user commands

(require 'ert)
(load-file "altodo.el")

(defvar test-buffer nil)

(defun setup-test-buffer ()
  (setq test-buffer (get-buffer-create "*altodo-filter-user-command-test*"))
  (with-current-buffer test-buffer
    (erase-buffer)
    (insert "[ ] Task 1\n")
    (insert "[x] Task 2\n")
    (insert "[@] Task 3\n")
    (insert "[w] Task 4\n")
    (insert "[~] Task 5\n")
    (insert "[ ] Task 6 #important\n")
    (insert "[ ] Task 7 @john\n")
    (insert "[ ] Task 8 -> 2026-01-01\n")
    (insert "[ ] Task 9 !\n")
    (insert "[ ] Task 10 +\n")
    (altodo-mode)
    (goto-char (point-min))))

(defun cleanup-test-buffer ()
  (when test-buffer
    (kill-buffer test-buffer)
    (setq test-buffer nil)))


;;; Tests for altodo-filter-clear

(ert-deftest test-filter-clear ()
  "Test clearing filters."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-filter-show-done-only)
    (should (eq altodo--filter-mode 'done))
    (should (> (length altodo--filter-overlays) 0))
    (altodo-filter-clear)
    (should (null altodo--filter-mode))
    (should (null altodo--filter-overlays)))
  (cleanup-test-buffer))


;;; Tests for altodo-filter-show-done-only

(ert-deftest test-filter-show-done-only ()
  "Test showing only done tasks."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-filter-show-done-only)
    (should (eq altodo--filter-mode 'done))
    (should (> (length altodo--filter-overlays) 0)))
  (cleanup-test-buffer))


;;; Tests for altodo-filter-show-progress-only

(ert-deftest test-filter-show-progress-only ()
  "Test showing only progress tasks."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-filter-show-progress-only)
    (should (eq altodo--filter-mode 'progress))
    (should (> (length altodo--filter-overlays) 0)))
  (cleanup-test-buffer))


;;; Tests for altodo-filter-show-waiting-only

(ert-deftest test-filter-show-waiting-only ()
  "Test showing only waiting tasks."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-filter-show-waiting-only)
    (should (eq altodo--filter-mode 'waiting))
    (should (> (length altodo--filter-overlays) 0)))
  (cleanup-test-buffer))


;;; Tests for altodo-filter-show-open-only

(ert-deftest test-filter-show-open-only ()
  "Test showing only open tasks."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-filter-show-open-only)
    (should (eq altodo--filter-mode 'open))
    (should (> (length altodo--filter-overlays) 0)))
  (cleanup-test-buffer))


;;; Tests for altodo-filter-show-cancelled-only

(ert-deftest test-filter-show-cancelled-only ()
  "Test showing only cancelled tasks."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-filter-show-cancelled-only)
    (should (eq altodo--filter-mode 'cancelled))
    (should (> (length altodo--filter-overlays) 0)))
  (cleanup-test-buffer))


;;; Tests for altodo-filter-show-priority

(ert-deftest test-filter-show-priority ()
  "Test showing only priority tasks."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-filter-show-priority)
    (should (eq altodo--filter-mode 'priority))
    (should (> (length altodo--filter-overlays) 0)))
  (cleanup-test-buffer))


;;; Tests for altodo-filter-show-star

(ert-deftest test-filter-show-star ()
  "Test showing only star tasks."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-filter-show-star)
    (should (eq altodo--filter-mode 'star))
    (should (> (length altodo--filter-overlays) 0)))
  (cleanup-test-buffer))


;;; Tests for altodo-filter-show-tag

(ert-deftest test-filter-show-tag ()
  "Test showing only tasks with specific tag."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-filter-show-tag "important")
    (should (eq altodo--filter-mode (intern "tag:important")))
    (should (> (length altodo--filter-overlays) 0)))
  (cleanup-test-buffer))


;;; Tests for altodo-filter-show-person

(ert-deftest test-filter-show-person ()
  "Test showing only tasks with specific person."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-filter-show-person "john")
    (should (eq altodo--filter-mode (intern "person:john")))
    (should (> (length altodo--filter-overlays) 0)))
  (cleanup-test-buffer))


;;; Tests for altodo-filter-show-overdue

(ert-deftest test-filter-show-overdue ()
  "Test showing only overdue tasks."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (altodo-filter-show-overdue)
    (should (eq altodo--filter-mode 'overdue))
    (should (> (length altodo--filter-overlays) 0)))
  (cleanup-test-buffer))


;;; Tests for filter mode variable

(ert-deftest test-filter-mode-variable ()
  "Test that filter mode variable is set correctly."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (should (null altodo--filter-mode))
    (altodo-filter-show-done-only)
    (should (eq altodo--filter-mode 'done))
    (altodo-filter-clear)
    (should (null altodo--filter-mode)))
  (cleanup-test-buffer))


;;; Tests for filter overlays variable

(ert-deftest test-filter-overlays-variable ()
  "Test that filter overlays variable is managed correctly."
  (setup-test-buffer)
  (with-current-buffer test-buffer
    (should (null altodo--filter-overlays))
    (altodo-filter-show-done-only)
    (should (> (length altodo--filter-overlays) 0))
    (altodo-filter-clear)
    (should (null altodo--filter-overlays)))
  (cleanup-test-buffer))


(provide 'filter-user-command-test)
