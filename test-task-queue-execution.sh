#!/bin/bash

# Test script to trigger task queue execution
# This simulates the condition where the 5-hour window is about to expire

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="claude-nights-watch"
DAEMON_LOG="$BASE_DIR/logs/$PROJECT_NAME/claude-nights-watch-daemon.log"

echo "🧪 Testing Claude Nights Watch Task Queue System"
echo "================================================"

# Check current queue status
echo "📋 Current queue status:"
./claude-nights-watch-manager.sh queue-status --project $PROJECT_NAME

echo ""
echo "⏰ Simulating 5-hour window expiration to trigger task execution..."

# Method 1: Temporarily modify the last activity file to simulate 5 hours passed
LAST_ACTIVITY_FILE="$HOME/.claude-last-activity"
BACKUP_FILE="$HOME/.claude-last-activity.backup"

# Backup current activity file if it exists
if [ -f "$LAST_ACTIVITY_FILE" ]; then
    cp "$LAST_ACTIVITY_FILE" "$BACKUP_FILE"
    echo "🔄 Backed up current activity file"
fi

# Set activity time to 5+ hours ago (18000+ seconds)
FIVE_HOURS_AGO=$(($(date +%s) - 18300))  # 5 hours and 5 minutes ago
echo "$FIVE_HOURS_AGO" > "$LAST_ACTIVITY_FILE"
echo "⏱️  Set last activity to 5+ hours ago: $(date -d @$FIVE_HOURS_AGO)"

echo ""
echo "🔍 Monitoring daemon log for task execution (will wait up to 2 minutes)..."
echo "   Press Ctrl+C to stop monitoring"

# Monitor the daemon log for task execution
timeout 120 tail -f "$DAEMON_LOG" &
TAIL_PID=$!

# Wait for a bit to see if task execution starts
sleep 10

# Check if any tasks have changed status
echo ""
echo "📊 Queue status after trigger:"
./claude-nights-watch-manager.sh queue-status --project $PROJECT_NAME

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🧹 Cleaning up test..."

    # Kill the tail process if still running
    if kill -0 $TAIL_PID 2>/dev/null; then
        kill $TAIL_PID 2>/dev/null
    fi

    # Restore original activity file
    if [ -f "$BACKUP_FILE" ]; then
        mv "$BACKUP_FILE" "$LAST_ACTIVITY_FILE"
        echo "✅ Restored original activity file"
    else
        # Set to current time if no backup existed
        echo "$(date +%s)" > "$LAST_ACTIVITY_FILE"
        echo "✅ Reset activity file to current time"
    fi

    echo "🏁 Test completed"
    exit 0
}

# Set up cleanup on script exit
trap cleanup EXIT INT TERM

# Wait for task execution or timeout
echo ""
echo "⏳ Waiting for task execution... (monitoring for 2 minutes)"
echo "   Check the log output above for task execution details"
wait $TAIL_PID 2>/dev/null
