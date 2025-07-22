#!/bin/bash

# Simple test to verify basic functionality

echo "=== Claude Nights Watch Simple Test ==="
echo ""

# Set paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export CLAUDE_NIGHTS_WATCH_DIR="$(dirname "$SCRIPT_DIR")"
TASK_FILE="test-task-simple.md"
RULES_FILE="test-rules-simple.md"

# Temporarily use test files
cd "$CLAUDE_NIGHTS_WATCH_DIR"
mv task.md task.md.bak 2>/dev/null || true
mv rules.md rules.md.bak 2>/dev/null || true
cp test/$TASK_FILE task.md
cp test/$RULES_FILE rules.md

echo "Test files prepared:"
echo "- Task: test-task-simple.md"
echo "- Rules: test-rules-simple.md"
echo ""

# Run the test
echo "Running test execution..."
./test/test-immediate-execution.sh

# Restore original files
mv task.md.bak task.md 2>/dev/null || true
mv rules.md.bak rules.md 2>/dev/null || true

echo ""
echo "=== Test Complete ==="
echo "Check the log file: $CLAUDE_NIGHTS_WATCH_DIR/logs/claude-nights-watch-test.log"
echo "Check if test-output.txt was created"