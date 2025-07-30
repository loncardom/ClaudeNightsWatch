#!/bin/bash

# Simple task execution test

echo "🧪 Simple Task Queue Test"
echo "========================="

# Test 1: Show current queue status
echo "📊 Current queue status:"
./claude-nights-watch-manager.sh queue-status --project claude-nights-watch

echo ""
echo "🚀 Test 2: Add a simple test task"
./claude-nights-watch-manager.sh add-task \
    --project claude-nights-watch \
    --title "Simple Test Task" \
    --description "Create a file called 'queue-test-result.txt' with the current date and time to prove the task queue system works" \
    --priority high \
    --duration 2

echo ""
echo "📊 Updated queue status:"
./claude-nights-watch-manager.sh queue-status --project claude-nights-watch

echo ""
echo "🔍 Test 3: Check audit manager status"
./claude-nights-watch-manager.sh audit-manager status

echo ""
echo "🎯 Test 4: Check daemon status"
./claude-nights-watch-manager.sh status --project claude-nights-watch

echo ""
echo "✅ Basic system test completed!"
echo "💡 To test actual task execution, wait for the 5-hour window to approach"
echo "   or implement a test trigger in the daemon logic."

# Test 5: Show a few lines from recent logs
echo ""
echo "📋 Recent daemon activity:"
./claude-nights-watch-manager.sh logs --project claude-nights-watch | tail -5
