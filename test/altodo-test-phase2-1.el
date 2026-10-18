;;; altodo-test-phase2-1.el --- Tests for Phase 2-1 Multiple Buffer Support -*- lexical-binding: t; -*-

(require 'ert)
(require 'altodo)

;;; Test 1: altodo-sidebar--get-buffer

(ert-deftest altodo-test-phase2-1-get-buffer-nil ()
  "Test altodo-sidebar--get-buffer returns nil when no sidebar exists."
  (with-temp-buffer
    (altodo-mode)
    (should-not (altodo-sidebar--get-buffer (current-buffer)))))

;;; Test 2: altodo-sidebar--get-or-create-buffer

(ert-deftest altodo-test-phase2-1-get-or-create-buffer ()
  "Test altodo-sidebar--get-or-create-buffer creates a new buffer."
  (let ((source-buffer (generate-new-buffer "test.altodo")))
    (unwind-protect
        (with-current-buffer source-buffer
          (altodo-mode)
          (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer)))
            ;; sidebar-buffer が作成されているか確認
            (should sidebar-buffer)
            (should (buffer-live-p sidebar-buffer))
            ;; alist に登録されているか確認
            (should (assoc source-buffer altodo-sidebar--buffer-alist))
            ;; 同じバッファが返されるか確認
            (should (eq sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer)))
            ;; クリーンアップ
            (when (buffer-live-p sidebar-buffer)
              (kill-buffer sidebar-buffer))))
      ;; source-buffer を削除
      (when (buffer-live-p source-buffer)
        (kill-buffer source-buffer)))))

;;; Test 3: altodo-sidebar--cleanup-buffer

(ert-deftest altodo-test-phase2-1-cleanup-buffer ()
  "Test altodo-sidebar--cleanup-buffer removes sidebar buffer."
  (let ((source-buffer (generate-new-buffer "test.altodo")))
    (unwind-protect
        (with-current-buffer source-buffer
          (altodo-mode)
          (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer)))
            ;; sidebar-buffer が作成されているか確認
            (should sidebar-buffer)
            ;; クリーンアップ
            (altodo-sidebar--cleanup-buffer source-buffer)
            ;; sidebar-buffer が削除されているか確認
            (should-not (buffer-live-p sidebar-buffer))
            ;; alist から削除されているか確認
            (should-not (assoc source-buffer altodo-sidebar--buffer-alist))))
      ;; source-buffer を削除
      (when (buffer-live-p source-buffer)
        (kill-buffer source-buffer)))))

;;; Test 4: Multiple buffers

(ert-deftest altodo-test-phase2-1-multiple-buffers ()
  "Test multiple buffers have independent sidebar buffers."
  (let ((buffer1 (generate-new-buffer "test1.altodo"))
        (buffer2 (generate-new-buffer "test2.altodo")))
    (unwind-protect
        (progn
          ;; バッファ 1 でサイドバーを作成
          (with-current-buffer buffer1
            (altodo-mode))
          (let ((sidebar1 (altodo-sidebar--get-or-create-buffer buffer1)))
            
            ;; バッファ 2 でサイドバーを作成
            (with-current-buffer buffer2
              (altodo-mode))
            (let ((sidebar2 (altodo-sidebar--get-or-create-buffer buffer2)))
              
              ;; 各バッファに対応する sidebar-buffer が存在するか確認
              (should sidebar1)
              (should sidebar2)
              
              ;; sidebar-buffer が異なるか確認
              (should-not (eq sidebar1 sidebar2))
              
              ;; クリーンアップ
              (when (buffer-live-p sidebar1)
                (kill-buffer sidebar1))
              (when (buffer-live-p sidebar2)
                (kill-buffer sidebar2)))))
      
      ;; クリーンアップ
      (when (buffer-live-p buffer1)
        (kill-buffer buffer1))
      (when (buffer-live-p buffer2)
        (kill-buffer buffer2)))))

;;; Test 5: Auto cleanup on buffer kill

(ert-deftest altodo-test-phase2-1-auto-cleanup ()
  "Test automatic cleanup when source buffer is killed."
  (let ((buffer (generate-new-buffer "test.altodo")))
    (with-current-buffer buffer
      (altodo-mode))
    
    (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer buffer)))
      ;; sidebar-buffer が存在することを確認
      (should sidebar-buffer)
      (should (buffer-live-p sidebar-buffer))
      
      ;; source-buffer を削除
      (kill-buffer buffer)
      
      ;; sidebar-buffer も削除されているか確認
      (should-not (buffer-live-p sidebar-buffer))
      
      ;; alist から削除されているか確認
      (should-not (assoc buffer altodo-sidebar--buffer-alist)))))

(provide 'altodo-test-phase2-1)
;;; altodo-test-phase2-1.el ends here
