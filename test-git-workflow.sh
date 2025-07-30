#!/bin/bash

# Test script for git workflow with immediate execution
# This script manually triggers task execution to test the git workflow

echo "=== Testing Git Workflow Integration ==="
echo "Timestamp: $(date)"
echo "Target Project: $CLAUDE_NIGHTS_WATCH_TARGET_DIR"
echo "Current Branch: $(git -C "$CLAUDE_NIGHTS_WATCH_TARGET_DIR" branch --show-current)"
echo

# Set environment variables for the test
export CLAUDE_NIGHTS_WATCH_PROJECT=structric
export CLAUDE_NIGHTS_WATCH_TARGET_DIR=/home/faz/development/structric
export CLAUDE_NIGHTS_WATCH_GIT_WORKFLOW=true

# Source the daemon functions so we can call them directly
source ./claude-nights-watch-daemon.sh

echo "Testing execute_task function directly..."

# Call the execute_task function directly (this will bypass the timing logic)
if execute_task; then
    echo "✅ Task execution completed successfully!"
    echo "Checking git status..."
    git -C "$CLAUDE_NIGHTS_WATCH_TARGET_DIR" status --porcelain | head -10
    echo
    echo "Current branch: $(git -C "$CLAUDE_NIGHTS_WATCH_TARGET_DIR" branch --show-current)"
    echo "Recent commits:"
    git -C "$CLAUDE_NIGHTS_WATCH_TARGET_DIR" log --oneline -3
else
    echo "❌ Task execution failed"
fi

echo "=== Test Complete ==="
