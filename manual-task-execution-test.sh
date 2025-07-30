#!/bin/bash

# Manual task execution test - directly execute the next task in queue

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="claude-nights-watch"
TARGET_DIR="/home/faz/development/ClaudeNightsWatch"
TASK_QUEUE_FILE="$BASE_DIR/projects/$PROJECT_NAME/task-queue.json"

echo "🧪 Manual Task Execution Test"
echo "============================"

# Check if task queue exists and is valid
if [ ! -f "$TASK_QUEUE_FILE" ]; then
    echo "❌ Task queue file not found: $TASK_QUEUE_FILE"
    exit 1
fi

if ! jq empty "$TASK_QUEUE_FILE" 2>/dev/null; then
    echo "❌ Invalid JSON in task queue file"
    exit 1
fi

echo "✅ Task queue file is valid"

# Get next pending task
echo ""
echo "🔍 Finding next pending task..."
NEXT_TASK_ID=$(jq -r '.tasks[] | select(.status == "pending") | .id' "$TASK_QUEUE_FILE" 2>/dev/null | head -1)

if [ "$NEXT_TASK_ID" = "null" ] || [ -z "$NEXT_TASK_ID" ]; then
    echo "❌ No pending tasks found in queue"
    echo "Available tasks:"
    jq -r '.tasks[] | "  \(.id): \(.title) [\(.status)]"' "$TASK_QUEUE_FILE"
    exit 1
fi

echo "🎯 Found next task: $NEXT_TASK_ID"

# Get task details
TASK_DATA=$(jq --arg task_id "$NEXT_TASK_ID" '.tasks[] | select(.id == $task_id)' "$TASK_QUEUE_FILE")
TASK_TITLE=$(echo "$TASK_DATA" | jq -r '.title')
TASK_DESCRIPTION=$(echo "$TASK_DATA" | jq -r '.description')

echo "📋 Task details:"
echo "   ID: $NEXT_TASK_ID"
echo "   Title: $TASK_TITLE"
echo "   Description: $TASK_DESCRIPTION"

# Update task status to in_progress
echo ""
echo "⏳ Updating task status to in_progress..."
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
TEMP_FILE=$(mktemp)

jq --arg task_id "$NEXT_TASK_ID" \
   --arg timestamp "$TIMESTAMP" \
   '(.tasks[] | select(.id == $task_id)) |= {
     . + {
       status: "in_progress",
       updated: $timestamp,
       audit_trail: (.audit_trail + [{
         timestamp: $timestamp,
         action: "status_change",
         old_status: .status,
         new_status: "in_progress",
         executor: "manual-test"
       }])
     }
   } |
   .last_updated = $timestamp |
   .queue_metadata.pending_tasks = ([.tasks[] | select(.status == "pending")] | length) |
   .queue_metadata.in_progress_tasks = ([.tasks[] | select(.status == "in_progress")] | length)' \
   "$TASK_QUEUE_FILE" > "$TEMP_FILE"

if [ $? -eq 0 ]; then
    mv "$TEMP_FILE" "$TASK_QUEUE_FILE"
    echo "✅ Task status updated to in_progress"
else
    rm -f "$TEMP_FILE"
    echo "❌ Failed to update task status"
    exit 1
fi

# Build the execution prompt
echo ""
echo "🔨 Building execution prompt..."

PROMPT="GLOBAL SAFETY RULES:

$(cat "$BASE_DIR/global-rules.md" 2>/dev/null || echo "No global rules found")

---END OF GLOBAL RULES---

PROJECT RULES:

$(cat "$BASE_DIR/projects/$PROJECT_NAME/rules.md" 2>/dev/null || echo "No project rules found")

---END OF PROJECT RULES---

TASK TO EXECUTE:

**Task ID:** $NEXT_TASK_ID
**Title:** $TASK_TITLE
**Priority:** $(echo "$TASK_DATA" | jq -r '.priority')

**Description:**
$TASK_DESCRIPTION

**Success Criteria:**
$(echo "$TASK_DATA" | jq -r '.execution_context.success_criteria[]?' | sed 's/^/- /')

**Safety Constraints:**
$(echo "$TASK_DATA" | jq -r '.execution_context.safety_constraints[]?' | sed 's/^/- /')

---END OF TASK---

Please create a todo list from the above task and execute it step by step. Work in the target directory: $TARGET_DIR. When complete, the task will be automatically marked as completed."

echo "📝 Prompt created ($(echo "$PROMPT" | wc -l) lines)"

# Execute with Claude
echo ""
echo "🚀 Executing task with Claude..."
echo "   Working directory: $TARGET_DIR"
echo "   Press Ctrl+C to interrupt execution"

START_TIME=$(date +%s)

cd "$TARGET_DIR" || {
    echo "❌ Cannot change to target directory: $TARGET_DIR"
    exit 1
}

# Execute Claude with the prepared prompt and capture result
if echo "$PROMPT" | claude --dangerously-skip-permissions; then
    END_TIME=$(date +%s)
    DURATION_MINUTES=$(((END_TIME - START_TIME) / 60))

    echo ""
    echo "✅ Task execution completed successfully!"
    echo "   Duration: ${DURATION_MINUTES} minutes"

    # Update task status to completed
    echo "📝 Updating task status to completed..."

    COMPLETION_TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    TEMP_FILE=$(mktemp)

    jq --arg task_id "$NEXT_TASK_ID" \
       --arg timestamp "$COMPLETION_TIMESTAMP" \
       --arg duration "$DURATION_MINUTES" \
       '(.tasks[] | select(.id == $task_id)) |= {
         . + {
           status: "completed",
           updated: $timestamp,
           actual_duration_minutes: ($duration | tonumber),
           audit_trail: (.audit_trail + [{
             timestamp: $timestamp,
             action: "status_change",
             old_status: .status,
             new_status: "completed",
             executor: "manual-test",
             duration_minutes: ($duration | tonumber)
           }])
         }
       } |
       .last_updated = $timestamp |
       .queue_metadata.in_progress_tasks = ([.tasks[] | select(.status == "in_progress")] | length) |
       .queue_metadata.completed_tasks = ([.tasks[] | select(.status == "completed")] | length)' \
       "$TASK_QUEUE_FILE" > "$TEMP_FILE"

    if [ $? -eq 0 ]; then
        mv "$TEMP_FILE" "$TASK_QUEUE_FILE"
        echo "✅ Task marked as completed"

        # Show updated queue status
        echo ""
        echo "📊 Updated queue status:"
        echo "   Total: $(jq -r '.queue_metadata.total_tasks' "$TASK_QUEUE_FILE")"
        echo "   Pending: $(jq -r '.queue_metadata.pending_tasks' "$TASK_QUEUE_FILE")"
        echo "   In Progress: $(jq -r '.queue_metadata.in_progress_tasks' "$TASK_QUEUE_FILE")"
        echo "   Completed: $(jq -r '.queue_metadata.completed_tasks' "$TASK_QUEUE_FILE")"

        echo ""
        echo "🎉 Test completed successfully!"
        echo "   The audit manager should detect this completed task within 5 minutes"
    else
        rm -f "$TEMP_FILE"
        echo "❌ Failed to update task status"
    fi

else
    echo ""
    echo "❌ Task execution failed"

    # Update task status to failed
    FAILURE_TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    TEMP_FILE=$(mktemp)

    jq --arg task_id "$NEXT_TASK_ID" \
       --arg timestamp "$FAILURE_TIMESTAMP" \
       '(.tasks[] | select(.id == $task_id)) |= {
         . + {
           status: "failed",
           updated: $timestamp,
           audit_trail: (.audit_trail + [{
             timestamp: $timestamp,
             action: "status_change",
             old_status: .status,
             new_status: "failed",
             executor: "manual-test"
           }])
         }
       } |
       .last_updated = $timestamp |
       .queue_metadata.in_progress_tasks = ([.tasks[] | select(.status == "in_progress")] | length) |
       .queue_metadata.failed_tasks = ([.tasks[] | select(.status == "failed")] | length)' \
       "$TASK_QUEUE_FILE" > "$TEMP_FILE"

    if [ $? -eq 0 ]; then
        mv "$TEMP_FILE" "$TASK_QUEUE_FILE"
        echo "✅ Task marked as failed"
    else
        rm -f "$TEMP_FILE"
        echo "❌ Failed to update task status"
    fi

    exit 1
fi
