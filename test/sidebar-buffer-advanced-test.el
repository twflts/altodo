;;; sidebar-buffer-advanced-test.el --- Advanced tests for the sidebar buffers -*- lexical-binding: t; -*-

(require 'ert)
(require 'altodo)

;;; Test 1: Sidebar buffer name format

(ert-deftest altodo-test-sidebar-buffer-sidebar-buffer-name ()
  "Test sidebar buffer name format."
  (let ((source-buffer (generate-new-buffer "myproject.altodo")))
    (unwind-protect
        (with-current-buffer source-buffer
          (altodo-mode)
          (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer)))
            ;; バッファ名が正しい形式か確認
            (should (string-match "*altodo-sidebar<myproject.altodo>*" 
                                  (buffer-name sidebar-buffer)))
            ;; クリーンアップ
            (when (buffer-live-p sidebar-buffer)
              (kill-buffer sidebar-buffer))))
      (when (buffer-live-p source-buffer)
        (kill-buffer source-buffer)))))

;;; Test 2: Source buffer reference in sidebar

(ert-deftest altodo-test-sidebar-buffer-source-buffer-reference ()
  "Test that sidebar buffer has correct source buffer reference."
  (let ((source-buffer (generate-new-buffer "test.altodo")))
    (unwind-protect
        (with-current-buffer source-buffer
          (altodo-mode)
          (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer)))
            ;; sidebar-buffer で source-buffer を参照できるか確認
            (with-current-buffer sidebar-buffer
              (should (eq altodo-sidebar--source-buffer source-buffer)))
            ;; クリーンアップ
            (when (buffer-live-p sidebar-buffer)
              (kill-buffer sidebar-buffer))))
      (when (buffer-live-p source-buffer)
        (kill-buffer source-buffer)))))

;;; Test 3: Alist consistency

(ert-deftest altodo-test-sidebar-buffer-alist-consistency ()
  "Test that alist is consistent with buffer references."
  (let ((buffer1 (generate-new-buffer "test1.altodo"))
        (buffer2 (generate-new-buffer "test2.altodo"))
        (buffer3 (generate-new-buffer "test3.altodo")))
    (unwind-protect
        (progn
          ;; 3 つのバッファでサイドバーを作成
          (with-current-buffer buffer1 (altodo-mode))
          (with-current-buffer buffer2 (altodo-mode))
          (with-current-buffer buffer3 (altodo-mode))
          
          (let ((sidebar1 (altodo-sidebar--get-or-create-buffer buffer1))
                (sidebar2 (altodo-sidebar--get-or-create-buffer buffer2))
                (sidebar3 (altodo-sidebar--get-or-create-buffer buffer3)))
            
            ;; alist に 3 つのエントリがあるか確認
            (should (= 3 (length altodo-sidebar--buffer-alist)))
            
            ;; 各エントリが正しいか確認
            (should (eq sidebar1 (cdr (assoc buffer1 altodo-sidebar--buffer-alist))))
            (should (eq sidebar2 (cdr (assoc buffer2 altodo-sidebar--buffer-alist))))
            (should (eq sidebar3 (cdr (assoc buffer3 altodo-sidebar--buffer-alist))))
            
            ;; クリーンアップ
            (when (buffer-live-p sidebar1) (kill-buffer sidebar1))
            (when (buffer-live-p sidebar2) (kill-buffer sidebar2))
            (when (buffer-live-p sidebar3) (kill-buffer sidebar3))))
      
      ;; クリーンアップ
      (when (buffer-live-p buffer1) (kill-buffer buffer1))
      (when (buffer-live-p buffer2) (kill-buffer buffer2))
      (when (buffer-live-p buffer3) (kill-buffer buffer3)))))

;;; Test 4: Partial cleanup (one buffer deleted)

(ert-deftest altodo-test-sidebar-buffer-partial-cleanup ()
  "Test cleanup when one buffer is deleted among multiple."
  (let ((buffer1 (generate-new-buffer "test1.altodo"))
        (buffer2 (generate-new-buffer "test2.altodo")))
    (unwind-protect
        (progn
          (with-current-buffer buffer1 (altodo-mode))
          (with-current-buffer buffer2 (altodo-mode))
          
          (let ((sidebar1 (altodo-sidebar--get-or-create-buffer buffer1))
                (sidebar2 (altodo-sidebar--get-or-create-buffer buffer2)))
            
            ;; alist に 2 つのエントリがあるか確認
            (should (= 2 (length altodo-sidebar--buffer-alist)))
            
            ;; buffer1 を削除
            (kill-buffer buffer1)
            
            ;; sidebar1 も削除されているか確認
            (should-not (buffer-live-p sidebar1))
            
            ;; alist に 1 つのエントリのみ残っているか確認
            (should (= 1 (length altodo-sidebar--buffer-alist)))
            
            ;; buffer2 と sidebar2 は残っているか確認
            (should (buffer-live-p buffer2))
            (should (buffer-live-p sidebar2))
            (should (eq sidebar2 (cdr (assoc buffer2 altodo-sidebar--buffer-alist))))
            
            ;; クリーンアップ
            (when (buffer-live-p sidebar2) (kill-buffer sidebar2))))
      
      ;; クリーンアップ
      (when (buffer-live-p buffer1) (kill-buffer buffer1))
      (when (buffer-live-p buffer2) (kill-buffer buffer2)))))

;;; Test 5: Reuse existing sidebar buffer

(ert-deftest altodo-test-sidebar-buffer-reuse-sidebar ()
  "Test that existing sidebar buffer is reused."
  (let ((source-buffer (generate-new-buffer "test.altodo")))
    (unwind-protect
        (with-current-buffer source-buffer
          (altodo-mode)
          
          ;; 最初のサイドバーを作成
          (let ((sidebar1 (altodo-sidebar--get-or-create-buffer source-buffer)))
            ;; 2 回目の呼び出しで同じバッファが返されるか確認
            (let ((sidebar2 (altodo-sidebar--get-or-create-buffer source-buffer)))
              (should (eq sidebar1 sidebar2))
              
              ;; alist に 1 つのエントリのみあるか確認
              (should (= 1 (length altodo-sidebar--buffer-alist)))
              
              ;; クリーンアップ
              (when (buffer-live-p sidebar1)
                (kill-buffer sidebar1)))))
      
      (when (buffer-live-p source-buffer)
        (kill-buffer source-buffer)))))

;;; Test 6: Non-altodo-mode buffer cleanup

(ert-deftest altodo-test-sidebar-buffer-non-altodo-cleanup ()
  "Test that non-altodo-mode buffers don't trigger cleanup."
  (let ((buffer (generate-new-buffer "test.txt")))
    (unwind-protect
        (with-current-buffer buffer
          ;; altodo-mode ではなく text-mode を使用
          (text-mode)
          
          ;; kill-buffer-hook を手動で実行
          (run-hooks 'kill-buffer-hook)
          
          ;; alist が変更されていないか確認
          (should (= 0 (length altodo-sidebar--buffer-alist))))
      
      (when (buffer-live-p buffer)
        (kill-buffer buffer)))))

;;; Test 7: Buffer with special characters in name

(ert-deftest altodo-test-sidebar-buffer-special-chars-in-name ()
  "Test sidebar buffer creation with special characters in source buffer name."
  (let ((source-buffer (generate-new-buffer "my-project_v1.0.altodo")))
    (unwind-protect
        (with-current-buffer source-buffer
          (altodo-mode)
          (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer)))
            ;; バッファが作成されているか確認
            (should sidebar-buffer)
            (should (buffer-live-p sidebar-buffer))
            
            ;; バッファ名に特殊文字が含まれているか確認
            (should (string-match "my-project_v1.0.altodo" 
                                  (buffer-name sidebar-buffer)))
            
            ;; クリーンアップ
            (when (buffer-live-p sidebar-buffer)
              (kill-buffer sidebar-buffer))))
      
      (when (buffer-live-p source-buffer)
        (kill-buffer source-buffer)))))

;;; Test 8: Rapid create and cleanup

(ert-deftest altodo-test-sidebar-buffer-rapid-operations ()
  "Test rapid creation and cleanup of sidebar buffers."
  (let ((buffers (list)))
    (unwind-protect
        (progn
          ;; 5 つのバッファを素早く作成
          (dotimes (i 5)
            (let ((buf (generate-new-buffer (format "test%d.altodo" i))))
              (with-current-buffer buf
                (altodo-mode)
                (altodo-sidebar--get-or-create-buffer buf))
              (push buf buffers)))
          
          ;; alist に 5 つのエントリがあるか確認
          (should (= 5 (length altodo-sidebar--buffer-alist)))
          
          ;; 全てのバッファを削除
          (dolist (buf buffers)
            (when (buffer-live-p buf)
              (kill-buffer buf)))
          
          ;; alist が空になっているか確認
          (should (= 0 (length altodo-sidebar--buffer-alist))))
      
      ;; クリーンアップ
      (dolist (buf buffers)
        (when (buffer-live-p buf)
          (kill-buffer buf))))))

;;; Test 9: Get buffer with nil source-buffer

(ert-deftest altodo-test-sidebar-buffer-get-buffer-with-nil ()
  "Test altodo-sidebar--get-buffer with nil source-buffer uses current buffer."
  (let ((source-buffer (generate-new-buffer "test.altodo")))
    (unwind-protect
        (with-current-buffer source-buffer
          (altodo-mode)
          (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer)))
            ;; nil を渡すと current-buffer を使用するか確認
            (should (eq sidebar-buffer (altodo-sidebar--get-buffer nil)))
            
            ;; クリーンアップ
            (when (buffer-live-p sidebar-buffer)
              (kill-buffer sidebar-buffer))))
      
      (when (buffer-live-p source-buffer)
        (kill-buffer source-buffer)))))

;;; Test 10: Cleanup with dead buffer

(ert-deftest altodo-test-sidebar-buffer-cleanup-dead-buffer ()
  "Test cleanup handles dead buffers gracefully."
  (let ((source-buffer (generate-new-buffer "test.altodo")))
    (with-current-buffer source-buffer
      (altodo-mode))
    
    (let ((sidebar-buffer (altodo-sidebar--get-or-create-buffer source-buffer)))
      ;; sidebar-buffer を手動で削除
      (kill-buffer sidebar-buffer)
      
      ;; cleanup を呼び出しても エラーが発生しないか確認
      (should-not (condition-case err
                      (altodo-sidebar--cleanup-buffer source-buffer)
                    (error t)))
      
      ;; alist から削除されているか確認
      (should-not (assoc source-buffer altodo-sidebar--buffer-alist)))
    
    ;; クリーンアップ
    (when (buffer-live-p source-buffer)
      (kill-buffer source-buffer))))

(provide 'sidebar-buffer-advanced-test)
;;; sidebar-buffer-advanced-test.el ends here
