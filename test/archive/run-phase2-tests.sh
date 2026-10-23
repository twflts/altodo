#!/bin/bash
# run-phase2-tests.sh - Run all Phase 2 tests

set -e

echo "==================================="
echo "Phase 2: Testing Existing Functions"
echo "==================================="
echo ""

TIMEOUT=10
FAILED=0

run_test() {
    local test_file=$1
    local test_name=$(basename "$test_file" .el)
    
    echo "Running: $test_name"
    output=$(timeout $TIMEOUT emacs --batch --eval "(progn (require 'package) (package-initialize) (add-to-list 'load-path package-user-dir) (load-file \"altodo.el\") (load-file \"$test_file\") (ert-run-tests-batch-and-exit))" 2>&1)
    
    if echo "$output" | grep -q "results as expected, 0 unexpected"; then
        echo "✓ $test_name passed"
    else
        echo "✗ $test_name failed"
        FAILED=$((FAILED + 1))
    fi
    echo ""
}

# Helper function tests
echo "--- Helper Function Tests ---"
run_test "test/helper-state-test.el"
run_test "test/helper-flag-test.el"
run_test "test/helper-date-test.el"
run_test "test/helper-id-test.el"
run_test "test/helper-dependency-test.el"

# Font-lock tests
echo "--- Font-lock Tests ---"
run_test "test/fontlock-matcher-test.el"
run_test "test/fontlock-facespec-test.el"
run_test "test/fontlock-subexp-test.el"
run_test "test/fontlock-layer-test.el"
run_test "test/fontlock-priority-test.el"
run_test "test/fontlock-integration-test.el"

# Command tests
echo "--- Command Tests ---"
run_test "test/command-test.el"
run_test "test/indent-test.el"
run_test "test/filter-function-test.el"
run_test "test/move-task-test.el"
run_test "test/misc-test.el"
run_test "test/id-test.el"
run_test "test/task-operation-test.el"
run_test "test/input-test.el"
run_test "test/matcher-advanced-test.el"
run_test "test/id-generation-test.el"
run_test "test/task-search-test.el"
run_test "test/multiline-comment-test.el"
run_test "test/done-file-test.el"
run_test "test/other-test.el"
run_test "test/user-command-advanced-test.el"
run_test "test/debug-test.el"

echo "==================================="
if [ $FAILED -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "$FAILED test(s) failed"
    exit 1
fi
