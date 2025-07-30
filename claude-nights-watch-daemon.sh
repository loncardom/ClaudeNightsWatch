#!/bin/bash

# Claude Nights Watch Daemon - Autonomous Task Execution
# Based on claude-auto-renew-daemon but executes tasks instead of simple renewals

# Multi-project support - read from environment variables set by manager
PROJECT_NAME="${CLAUDE_NIGHTS_WATCH_PROJECT:-default}"
TARGET_DIR="${CLAUDE_NIGHTS_WATCH_TARGET_DIR:-$(pwd)}"
NIGHTS_WATCH_DIR="${CLAUDE_NIGHTS_WATCH_DIR:-$(dirname "$0")}"

# Project-specific file paths
LOG_FILE="$NIGHTS_WATCH_DIR/logs/$PROJECT_NAME/claude-nights-watch-daemon.log"
PID_FILE="$NIGHTS_WATCH_DIR/logs/$PROJECT_NAME/claude-nights-watch-daemon.pid"
START_TIME_FILE="$NIGHTS_WATCH_DIR/logs/$PROJECT_NAME/claude-nights-watch-start-time"
LAST_ACTIVITY_FILE="$HOME/.claude-last-activity"

# Task and rules files - project-specific locations
TASK_FILE="$NIGHTS_WATCH_DIR/projects/$PROJECT_NAME/task.md"
RULES_FILE="$NIGHTS_WATCH_DIR/projects/$PROJECT_NAME/rules.md"
GLOBAL_RULES_FILE="$NIGHTS_WATCH_DIR/global-rules.md"
DEFAULT_TASK_FILE="$NIGHTS_WATCH_DIR/default-task.md"
TASK_QUEUE_FILE="$NIGHTS_WATCH_DIR/projects/$PROJECT_NAME/task-queue.json"
TASK_DIR="$TARGET_DIR"

# Ensure logs directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to handle shutdown
cleanup() {
    log_message "Daemon shutting down..."
    rm -f "$PID_FILE"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Function to check if we're past the start time
is_start_time_reached() {
    if [ ! -f "$START_TIME_FILE" ]; then
        # No start time set, always active
        return 0
    fi

    local start_epoch=$(cat "$START_TIME_FILE")
    local current_epoch=$(date +%s)

    if [ "$current_epoch" -ge "$start_epoch" ]; then
        return 0  # Start time reached
    else
        return 1  # Still waiting
    fi
}

# Function to get time until start
get_time_until_start() {
    if [ ! -f "$START_TIME_FILE" ]; then
        echo "0"
        return
    fi

    local start_epoch=$(cat "$START_TIME_FILE")
    local current_epoch=$(date +%s)
    local diff=$((start_epoch - current_epoch))

    if [ "$diff" -le 0 ]; then
        echo "0"
    else
        echo "$diff"
    fi
}

# Function to get ccusage command
get_ccusage_cmd() {
    if command -v ccusage &> /dev/null; then
        echo "ccusage"
    elif command -v bunx &> /dev/null; then
        echo "bunx ccusage"
    elif command -v npx &> /dev/null; then
        echo "npx ccusage@latest"
    else
        return 1
    fi
}

# Function to get minutes until reset
get_minutes_until_reset() {
    local ccusage_cmd=$(get_ccusage_cmd)
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Use JSON output with --active flag to get only the active block
    local json_output=$($ccusage_cmd blocks --json --active 2>/dev/null)

    if [ -z "$json_output" ]; then
        # No active block - fallback to 0 like original behavior
        echo "0"
        return 0
    fi

    # Extract endTime from the active block
    local end_time=$(echo "$json_output" | grep '"endTime"' | head -1 | sed 's/.*"endTime": *"\([^"]*\)".*/\1/')

    if [ -z "$end_time" ]; then
        echo "0"
        return 0
    fi

    # Convert ISO timestamp to Unix epoch for calculation
    local end_epoch
    if command -v date &> /dev/null; then
        # Try different date command formats (macOS vs Linux)
        # Linux format (handles UTC properly)
        if end_epoch=$(date -d "$end_time" +%s 2>/dev/null); then
            :
        # macOS format - need to specify UTC timezone
        elif end_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S.000Z" "$end_time" +%s 2>/dev/null); then
            :
        # macOS format without milliseconds in UTC
        elif end_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$end_time" +%s 2>/dev/null); then
            :
        # Try stripping the .000Z and parsing in UTC
        elif stripped_time=$(echo "$end_time" | sed 's/\.000Z$/Z/') && end_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$stripped_time" +%s 2>/dev/null); then
            :
        else
            log_message "Could not parse ccusage endTime format: $end_time" >&2
            echo "0"
            return 0
        fi
    else
        echo "0"
        return 0
    fi

    local current_epoch=$(date +%s)
    local time_diff=$((end_epoch - current_epoch))
    local remaining_minutes=$((time_diff / 60))

    if [ "$remaining_minutes" -gt 0 ]; then
        echo $remaining_minutes
    else
        echo "0"
        return 0
    fi
}

# Function to check if task queue should be used
should_use_task_queue() {
    [ -f "$TASK_QUEUE_FILE" ]
}

# Function to get next pending task from queue
get_next_task_from_queue() {
    if [ ! -f "$TASK_QUEUE_FILE" ]; then
        return 1
    fi

    # Load JSON validation library
    if [ -f "$NIGHTS_WATCH_DIR/lib/json-validation.sh" ]; then
        source "$NIGHTS_WATCH_DIR/lib/json-validation.sh"
    fi

    # Find first pending task with highest priority
    jq -r '.tasks[] | select(.status == "pending") | select(.priority == "high") | .id' "$TASK_QUEUE_FILE" 2>/dev/null | head -1 || \
    jq -r '.tasks[] | select(.status == "pending") | select(.priority == "medium") | .id' "$TASK_QUEUE_FILE" 2>/dev/null | head -1 || \
    jq -r '.tasks[] | select(.status == "pending") | select(.priority == "low") | .id' "$TASK_QUEUE_FILE" 2>/dev/null | head -1
}

# Function to get task details by ID
get_task_details() {
    local task_id="$1"
    if [ ! -f "$TASK_QUEUE_FILE" ] || [ -z "$task_id" ]; then
        return 1
    fi

    jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | {title: .title, description: .description, working_directory: .execution_context.working_directory}' "$TASK_QUEUE_FILE" 2>/dev/null
}

# Function to update task status
update_task_status() {
    local task_id="$1"
    local new_status="$2"
    local start_time="$3"
    local duration="$4"

    if [ ! -f "$TASK_QUEUE_FILE" ] || [ -z "$task_id" ] || [ -z "$new_status" ]; then
        return 1
    fi

    # Create a temporary file for the update
    local temp_file=$(mktemp)

    # Update the task with new status and timing info
    jq --arg id "$task_id" --arg status "$new_status" --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --arg start "$start_time" --arg duration "$duration" \
       '(.tasks[] | select(.id == $id)) |= (
         .status = $status |
         .updated = $updated |
         (if $start != "" then .started_at = $start else . end) |
         (if $duration != "" then .actual_duration_minutes = ($duration | tonumber) else . end)
       ) |
       .last_updated = $updated |
       .queue_metadata.pending_tasks = ([.tasks[] | select(.status == "pending")] | length) |
       .queue_metadata.in_progress_tasks = ([.tasks[] | select(.status == "in_progress")] | length) |
       .queue_metadata.completed_tasks = ([.tasks[] | select(.status == "completed")] | length)' \
       "$TASK_QUEUE_FILE" > "$temp_file"

    # Replace original file if update succeeded
    if [ $? -eq 0 ]; then
        mv "$temp_file" "$TASK_QUEUE_FILE"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Function to prepare task prompt from JSON queue
prepare_task_queue_prompt() {
    local task_id="$1"
    if [ -z "$task_id" ]; then
        return 1
    fi

    local prompt=""

    # Add global rules if they exist
    if [ -f "$GLOBAL_RULES_FILE" ]; then
        prompt="GLOBAL SAFETY CONSTRAINTS:\n\n"
        prompt+=$(cat "$GLOBAL_RULES_FILE")
        prompt+="\n\n---END OF GLOBAL RULES---\n\n"
        log_message "Applied global rules from $GLOBAL_RULES_FILE"
    fi

    # Add project-specific rules if they exist
    if [ -f "$RULES_FILE" ]; then
        prompt+="PROJECT-SPECIFIC RULES:\n\n"
        prompt+=$(cat "$RULES_FILE")
        prompt+="\n\n---END OF PROJECT RULES---\n\n"
        log_message "Applied project rules from $RULES_FILE"
    fi

    # Get task details from queue
    local task_details=$(get_task_details "$task_id")
    local task_title=$(echo "$task_details" | jq -r '.title // ""' 2>/dev/null)
    local task_description=$(echo "$task_details" | jq -r '.description // ""' 2>/dev/null)
    local working_dir=$(echo "$task_details" | jq -r '.working_directory // ""' 2>/dev/null)

    # Add task content
    prompt+="TASK TO EXECUTE:\n\n"
    prompt+="**Task ID:** $task_id\n"
    prompt+="**Title:** $task_title\n\n"
    prompt+="**Description:**\n$task_description\n\n"
    prompt+="---END OF TASK---\n\n"
    prompt+="Please create a todo list from the above task and execute it step by step."
    if [ -n "$working_dir" ]; then
        prompt+=" Work in the target directory: $working_dir"
    else
        prompt+=" Work in the target directory: $TARGET_DIR"
    fi

    echo -e "$prompt"
}

# Function to prepare task with rules
prepare_task_prompt() {
    local prompt=""

    # Add global rules if they exist
    if [ -f "$GLOBAL_RULES_FILE" ]; then
        prompt="GLOBAL SAFETY CONSTRAINTS:\n\n"
        prompt+=$(cat "$GLOBAL_RULES_FILE")
        prompt+="\n\n---END OF GLOBAL RULES---\n\n"
        log_message "Applied global rules from $GLOBAL_RULES_FILE"
    fi

    # Add project-specific rules if they exist
    if [ -f "$RULES_FILE" ]; then
        prompt+="PROJECT-SPECIFIC RULES:\n\n"
        prompt+=$(cat "$RULES_FILE")
        prompt+="\n\n---END OF PROJECT RULES---\n\n"
        log_message "Applied project rules from $RULES_FILE"
    fi

    # Determine which task to use
    local task_content=""
    local using_default=false

    if [ -f "$TASK_FILE" ]; then
        # Check if it's a template file (contains TEMPLATE marker)
        if grep -q "TEMPLATE" "$TASK_FILE" 2>/dev/null; then
            log_message "Template detected in $TASK_FILE, using default task"
            if [ -f "$DEFAULT_TASK_FILE" ]; then
                task_content=$(cat "$DEFAULT_TASK_FILE")
                using_default=true
            else
                log_message "ERROR: Default task file not found at $DEFAULT_TASK_FILE"
                return 1
            fi
        else
            task_content=$(cat "$TASK_FILE")
        fi
    else
        log_message "ERROR: Task file not found at $TASK_FILE"
        return 1
    fi

    # Add task content
    prompt+="TASK TO EXECUTE:\n\n"
    prompt+="$task_content"
    prompt+="\n\n---END OF TASK---\n\n"
    prompt+="Please create a todo list from the above task and execute it step by step. Work in the target directory: $TARGET_DIR"

    if [ "$using_default" = true ]; then
        log_message "Using default task due to template detection"
    else
        log_message "Using project-specific task from $TASK_FILE"
    fi

    echo -e "$prompt"
}

# Function to execute task (supports both JSON queue and task.md)
execute_task() {
    if ! command -v claude &> /dev/null; then
        log_message "ERROR: claude command not found"
        return 1
    fi

    local full_prompt=""
    local task_id=""
    local start_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local execution_start=$(date +%s)

    # Determine execution mode: JSON task queue or traditional task.md
    if should_use_task_queue; then
        log_message "Using JSON task queue system"

        # Get next pending task
        task_id=$(get_next_task_from_queue)
        if [ -z "$task_id" ] || [ "$task_id" = "null" ]; then
            log_message "No pending tasks found in queue"
            return 1
        fi

        log_message "Executing task: $task_id"

        # Update task status to in_progress
        if ! update_task_status "$task_id" "in_progress" "$start_time" ""; then
            log_message "ERROR: Failed to update task status to in_progress"
            return 1
        fi

        # Prepare prompt from task queue
        full_prompt=$(prepare_task_queue_prompt "$task_id")
        if [ $? -ne 0 ]; then
            log_message "ERROR: Failed to prepare task queue prompt"
            update_task_status "$task_id" "failed" "$start_time" ""
            return 1
        fi
    else
        log_message "Using fallback task.md system"

        # Check if task file exists
        if [ ! -f "$TASK_FILE" ]; then
            log_message "ERROR: Task file not found at $TASK_FILE"
            return 1
        fi

        # Prepare the full prompt with rules and task
        full_prompt=$(prepare_task_prompt)
        if [ $? -ne 0 ]; then
            log_message "ERROR: Failed to prepare task.md prompt"
            return 1
        fi
    fi

    log_message "Executing task with Claude (autonomous mode)..."

    # Log the full prompt being sent
    echo "" >> "$LOG_FILE"
    echo "=== PROMPT SENT TO CLAUDE ===" >> "$LOG_FILE"
    echo -e "$full_prompt" >> "$LOG_FILE"
    echo "=== END OF PROMPT ===" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    # Change to target directory and execute task with Claude
    local original_dir=$(pwd)
    local claude_md_copied=false

    # Copy CLAUDE.md to target directory if it doesn't exist there
    if [ -f "$NIGHTS_WATCH_DIR/CLAUDE.md" ] && [ ! -f "$TARGET_DIR/CLAUDE.md" ]; then
        cp "$NIGHTS_WATCH_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
        claude_md_copied=true
        log_message "Temporarily copied CLAUDE.md to target directory"
    fi

    cd "$TARGET_DIR" || {
        log_message "ERROR: Cannot change to target directory: $TARGET_DIR"
        return 1
    }

    log_message "=== CLAUDE RESPONSE START ==="
    (echo -e "$full_prompt" | claude --dangerously-skip-permissions 2>&1) | tee -a "$LOG_FILE" &
    local pid=$!

    # Monitor execution (no timeout for complex tasks)
    log_message "Task execution started (PID: $pid)"

    # Wait for completion
    wait $pid
    local result=$?

    log_message "=== CLAUDE RESPONSE END ==="

    # Clean up: return to original directory and remove temporary CLAUDE.md
    cd "$original_dir"
    if [ "$claude_md_copied" = true ]; then
        rm -f "$TARGET_DIR/CLAUDE.md"
        log_message "Removed temporary CLAUDE.md from target directory"
    fi

    # Calculate execution duration
    local execution_end=$(date +%s)
    local duration_seconds=$((execution_end - execution_start))
    local duration_minutes=$((duration_seconds / 60))

    if [ $result -eq 0 ]; then
        log_message "Task execution completed successfully"
        date +%s > "$LAST_ACTIVITY_FILE"

        # Update task status if using JSON queue
        if [ -n "$task_id" ]; then
            if update_task_status "$task_id" "completed" "$start_time" "$duration_minutes"; then
                log_message "Updated task $task_id status to completed (duration: ${duration_minutes}m)"
            else
                log_message "WARNING: Failed to update task $task_id status to completed"
            fi
        fi

        return 0
    else
        log_message "ERROR: Task execution failed with code $result"

        # Update task status if using JSON queue
        if [ -n "$task_id" ]; then
            if update_task_status "$task_id" "failed" "$start_time" "$duration_minutes"; then
                log_message "Updated task $task_id status to failed (duration: ${duration_minutes}m)"
            else
                log_message "WARNING: Failed to update task $task_id status to failed"
            fi
        fi

        return 1
    fi
}

# Function to calculate next check time
calculate_sleep_duration() {
    # EAGER MODE: Use shorter intervals for JSON task queues
    if should_use_task_queue; then
        local next_task_id=$(get_next_task_from_queue)
        if [ -n "$next_task_id" ] && [ "$next_task_id" != "null" ]; then
            # Have pending tasks - check frequently for capacity
            echo 30
        else
            # No pending tasks - use longer intervals
            echo 300  # 5 minutes
        fi
        return
    fi

    # LEGACY MODE: Time-based intervals for task.md system
    local minutes_remaining=$(get_minutes_until_reset)

    if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ]; then
        log_message "Time remaining: $minutes_remaining minutes" >&2

        if [ "$minutes_remaining" -le 5 ]; then
            # Check every 30 seconds when close to reset
            echo 30
        elif [ "$minutes_remaining" -le 30 ]; then
            # Check every 2 minutes when within 30 minutes
            echo 120
        else
            # Check every 10 minutes otherwise
            echo 600
        fi
    else
        # Fallback: check based on last activity
        if [ -f "$LAST_ACTIVITY_FILE" ]; then
            local last_activity=$(cat "$LAST_ACTIVITY_FILE")
            local current_time=$(date +%s)
            local time_diff=$((current_time - last_activity))
            local remaining=$((18000 - time_diff))  # 5 hours = 18000 seconds

            if [ "$remaining" -le 300 ]; then  # 5 minutes
                echo 30
            elif [ "$remaining" -le 1800 ]; then  # 30 minutes
                echo 120
            else
                echo 600
            fi
        else
            # No info available, check every 5 minutes
            echo 300
        fi
    fi
}

# Main daemon loop
main() {
    # Check if already running
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo "Daemon already running with PID $OLD_PID"
            exit 1
        else
            log_message "Removing stale PID file"
            rm -f "$PID_FILE"
        fi
    fi

    # Save PID
    echo $$ > "$PID_FILE"

    log_message "=== Claude Nights Watch Daemon Started ==="
    log_message "PID: $$"
    log_message "Project: $PROJECT_NAME"
    log_message "Target directory: $TARGET_DIR"
    log_message "Logs: $LOG_FILE"
    log_message "Git workflow: ${CLAUDE_NIGHTS_WATCH_GIT_WORKFLOW:-true}"


    # Check for global rules file
    if [ -f "$GLOBAL_RULES_FILE" ]; then
        log_message "Global rules file found at $GLOBAL_RULES_FILE"
    else
        log_message "No global rules file found at $GLOBAL_RULES_FILE"
    fi

    # Check for project rules file
    if [ -f "$RULES_FILE" ]; then
        log_message "Project rules file found at $RULES_FILE"
    else
        log_message "No project rules file found at $RULES_FILE"
    fi

    # Check for task queue first (preferred method)
    if [ -f "$TASK_QUEUE_FILE" ]; then
        local pending_count=$(jq -r '.tasks[] | select(.status == "pending") | .id' "$TASK_QUEUE_FILE" 2>/dev/null | wc -l)
        log_message "Task queue file found at $TASK_QUEUE_FILE ($pending_count pending tasks)"
    else
        log_message "No task queue file found at $TASK_QUEUE_FILE"
    fi

    # Check for task file (fallback method)
    if [ -f "$TASK_FILE" ]; then
        # Check if it's a template file
        if grep -q "TEMPLATE" "$TASK_FILE" 2>/dev/null; then
            log_message "Project task file found at $TASK_FILE - using fallback mode"
        else
            log_message "Project task file found at $TASK_FILE"
        fi
    else
        log_message "WARNING: Task file not found at $TASK_FILE"
        log_message "Please create a task file with your tasks"
    fi

    # Report execution mode
    if should_use_task_queue; then
        log_message "Daemon will use JSON task queue system"
    else
        log_message "Daemon will use fallback task.md system"
    fi

    # Check for start time
    if [ -f "$START_TIME_FILE" ]; then
        start_epoch=$(cat "$START_TIME_FILE")
        log_message "Start time configured: $(date -d "@$start_epoch" 2>/dev/null || date -r "$start_epoch")"
    else
        log_message "No start time set - will begin monitoring immediately"
    fi

    # Check ccusage availability
    if ! get_ccusage_cmd &> /dev/null; then
        log_message "WARNING: ccusage not found. Using time-based checking."
        log_message "Install ccusage for more accurate timing: npm install -g ccusage"
    fi

    # Main loop
    while true; do
        # Check if we're past start time
        if ! is_start_time_reached; then
            time_until_start=$(get_time_until_start)
            hours=$((time_until_start / 3600))
            minutes=$(((time_until_start % 3600) / 60))
            seconds=$((time_until_start % 60))

            if [ "$hours" -gt 0 ]; then
                log_message "Waiting for start time (${hours}h ${minutes}m remaining)..."
                sleep 300  # Check every 5 minutes when waiting
            elif [ "$minutes" -gt 2 ]; then
                log_message "Waiting for start time (${minutes}m ${seconds}s remaining)..."
                sleep 60   # Check every minute when close
            elif [ "$time_until_start" -gt 10 ]; then
                log_message "Waiting for start time (${minutes}m ${seconds}s remaining)..."
                sleep 10   # Check every 10 seconds when very close
            else
                log_message "Waiting for start time (${seconds}s remaining)..."
                sleep 2    # Check every 2 seconds when imminent
            fi
            continue
        fi

        # If we just reached start time, log it
        if [ -f "$START_TIME_FILE" ]; then
            # Check if this is the first time we're active
            if [ ! -f "${START_TIME_FILE}.activated" ]; then
                log_message "✅ Start time reached! Beginning task execution monitoring..."
                touch "${START_TIME_FILE}.activated"
            fi
        fi

        # Get minutes until reset
        minutes_remaining=$(get_minutes_until_reset)

        # Check if we should execute task
        should_execute=false

        # EAGER MODE: Execute immediately if using JSON task queue with pending tasks
        if should_use_task_queue; then
            next_task_id=$(get_next_task_from_queue)
            if [ -n "$next_task_id" ] && [ "$next_task_id" != "null" ]; then
                should_execute=true
                log_message "EAGER MODE: Executing task $next_task_id immediately (JSON task queue)"
            else
                log_message "JSON task queue has no pending tasks, entering monitoring mode"
            fi
        else
            # LEGACY MODE: Wait for 5-hour window expiry (task.md system)
            if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ]; then
                if [ "$minutes_remaining" -le 2 ]; then
                    should_execute=true
                    log_message "Reset imminent ($minutes_remaining minutes), preparing to execute task..."
                fi
            else
                # Fallback check
                if [ -f "$LAST_ACTIVITY_FILE" ]; then
                    last_activity=$(cat "$LAST_ACTIVITY_FILE")
                    current_time=$(date +%s)
                    time_diff=$((current_time - last_activity))

                    if [ $time_diff -ge 18000 ]; then
                        should_execute=true
                        log_message "5 hours elapsed since last activity, executing task..."
                    fi
                else
                    # No activity recorded, safe to start
                    should_execute=true
                    log_message "No previous activity recorded, starting initial task execution..."
                fi
            fi
        fi

        # Execute task if needed
        if [ "$should_execute" = true ]; then
            # Check if task file exists before execution
            if [ ! -f "$TASK_FILE" ]; then
                log_message "ERROR: Cannot execute - task file not found at $TASK_FILE"
                log_message "Waiting 5 minutes before next check..."
                sleep 300
                continue
            fi

            # Wait a bit to ensure we're in the renewal window
            sleep 60

            # Try to execute task
            if execute_task; then
                log_message "Task execution completed!"
                # Sleep for 5 minutes after successful execution
                sleep 300
            else
                log_message "Task execution failed, will retry in 1 minute"
                sleep 60
            fi
        fi

        # Calculate how long to sleep
        sleep_duration=$(calculate_sleep_duration)
        log_message "Next check in $((sleep_duration / 60)) minutes"

        # Sleep until next check
        sleep "$sleep_duration"
    done
}

# Start the daemon
main
