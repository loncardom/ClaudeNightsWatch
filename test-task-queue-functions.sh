#!/bin/bash

# Test the task queue functions directly

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="claude-nights-watch"
TASK_QUEUE_FILE="$BASE_DIR/projects/$PROJECT_NAME/task-queue.json"

echo "🔍 Testing Task Queue Functions"
echo "==============================="

# Source the task queue functions from the daemon
source <(grep -A 200 "# Task Queue Management Functions" "$BASE_DIR/claude-nights-watch-daemon.sh" | grep -B 200 "^#.*Function to check if using task queue")

# Test validation
echo "📋 Task queue file: $TASK_QUEUE_FILE"
echo "📝 File exists: $([ -f "$TASK_QUEUE_FILE" ] && echo "✅ Yes" || echo "❌ No")"

if [ -f "$TASK_QUEUE_FILE" ]; then
    echo "📊 JSON validation:"
    if jq empty "$TASK_QUEUE_FILE" 2>/dev/null; then
        echo "   ✅ JSON is valid"
    else
        echo "   ❌ JSON is invalid"
        echo "   Error details:"
        jq empty "$TASK_QUEUE_FILE"
    fi

    echo ""
    echo "🎯 Testing queue functions:"

    # Test should_use_task_queue
    echo -n "   should_use_task_queue(): "
    if should_use_task_queue; then
        echo "✅ True - will use task queue"
    else
        echo "❌ False - will use fallback"
    fi

    # Test get_next_task
    echo -n "   get_next_task(): "
    if next_task=$(get_next_task); then
        echo "✅ Found task: $next_task"
    else
        echo "❌ No tasks found"
    fi

    # Test count_tasks
    echo "   Task counts:"
    echo "     Pending: $(count_tasks 'pending')"
    echo "     In Progress: $(count_tasks 'in_progress')"
    echo "     Completed: $(count_tasks 'completed')"
    echo "     Failed: $(count_tasks 'failed')"
else
    echo "❌ Task queue file not found!"
fi

echo ""
echo "🏁 Test completed"
