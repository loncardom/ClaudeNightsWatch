#!/bin/bash

# Claude Nights Watch Audit Manager - Task Completion Oversight System
# Monitors completed tasks and provides quality assurance audits

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
MANAGER_MANDATE_FILE="$BASE_DIR/manager-mandate.md"
AUDIT_LOG_FILE="$BASE_DIR/logs/audit-manager.log"
AUDIT_PID_FILE="$BASE_DIR/logs/audit-manager.pid"
AUDIT_RESULTS_DIR="$BASE_DIR/audit-results"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure required directories and files exist
mkdir -p "$(dirname "$AUDIT_LOG_FILE")" "$AUDIT_RESULTS_DIR" 2>/dev/null

# Function to log audit messages
audit_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AUDIT-MANAGER] $1" | tee -a "$AUDIT_LOG_FILE"
}

# Function to validate task queue JSON
validate_task_queue() {
    local queue_file="$1"

    if [ ! -f "$queue_file" ]; then
        return 1
    fi

    if ! jq empty "$queue_file" 2>/dev/null; then
        return 1
    fi

    return 0
}

# Function to get completed tasks since last audit
get_completed_tasks_since() {
    local project="$1"
    local since_timestamp="$2"
    local queue_file="$BASE_DIR/projects/$project/task-queue.json"

    if ! validate_task_queue "$queue_file"; then
        return 1
    fi

    # Get tasks completed after the given timestamp
    jq -r --arg since "$since_timestamp" '
        .tasks[]
        | select(.status == "completed" and .updated > $since)
        | "\(.id)|\(.title)|\(.updated)|\(.actual_duration_minutes)"
    ' "$queue_file" 2>/dev/null
}

# Function to get PR diff for a task
get_task_pr_diff() {
    local project="$1"
    local task_id="$2"
    local target_dir="$3"

    # Look for task-specific branch
    cd "$target_dir" 2>/dev/null || return 1

    # Check if we can find the task branch or recent commits
    local daemon_branches=$(git branch --all | grep -E "claude/[0-9]+\.task" | head -5)

    if [ -n "$daemon_branches" ]; then
        # Get diff from the most recent daemon branch
        local recent_branch=$(echo "$daemon_branches" | head -1 | sed 's/^[* ]*//' | sed 's/remotes\\/origin\\///')
        git diff main.."$recent_branch" 2>/dev/null || git diff HEAD~10..HEAD 2>/dev/null
    else
        # Fallback to recent commits
        git diff HEAD~5..HEAD 2>/dev/null
    fi
}

# Function to get daemon log for task execution
get_task_execution_log() {
    local project="$1"
    local task_id="$2"
    local completion_time="$3"

    local daemon_log="$BASE_DIR/logs/$project/claude-nights-watch-daemon.log"

    if [ ! -f "$daemon_log" ]; then
        return 1
    fi

    # Extract log entries around the task execution time
    # Look for entries with the task ID and surrounding context
    awk -v task_id="$task_id" '
        /\[.*\]/ {
            if (match($0, task_id) || context > 0) {
                print $0
                context = (match($0, task_id)) ? 20 : context - 1
            }
        }
    ' "$daemon_log" 2>/dev/null
}

# Function to perform task audit using Claude
audit_completed_task() {
    local project="$1"
    local task_id="$2"
    local task_title="$3"
    local completion_time="$4"
    local duration="$5"

    audit_log "Starting audit for task: $task_id ($task_title)"

    # Get task details from the queue
    local queue_file="$BASE_DIR/projects/$project/task-queue.json"
    local task_data=$(jq --arg task_id "$task_id" '.tasks[] | select(.id == $task_id)' "$queue_file" 2>/dev/null)

    if [ -z "$task_data" ]; then
        audit_log "ERROR: Could not retrieve task data for $task_id"
        return 1
    fi

    # Get target directory for the project
    local target_dir
    if [ -f "$BASE_DIR/projects/$project/.target" ]; then
        target_dir=$(cat "$BASE_DIR/projects/$project/.target")
    else
        target_dir="$BASE_DIR"  # Fallback
    fi

    # Collect evidence
    local pr_diff=$(get_task_pr_diff "$project" "$task_id" "$target_dir")
    local execution_log=$(get_task_execution_log "$project" "$task_id" "$completion_time")

    # Create audit prompt
    local audit_prompt="$(cat "$MANAGER_MANDATE_FILE")

=== TASK AUDIT REQUEST ===

You are the autonomous management overseer for Claude Nights Watch. Please audit the following completed task according to the mandate above.

**TASK DETAILS:**
$task_data

**EXECUTION LOG:**
\`\`\`
$execution_log
\`\`\`

**CODE CHANGES (PR DIFF):**
\`\`\`diff
$pr_diff
\`\`\`

**EXECUTION METADATA:**
- Completion Time: $completion_time
- Actual Duration: ${duration:-Unknown} minutes
- Project: $project

Please provide a complete audit assessment following the format specified in the manager mandate. Focus on completeness, quality, safety, and efficiency as outlined."

    # Execute audit using Claude
    local audit_result_file="$AUDIT_RESULTS_DIR/${project}_${task_id}_$(date +%Y%m%d_%H%M%S).md"

    audit_log "Executing audit analysis with Claude..."

    # Run Claude audit in the target directory for context
    cd "$target_dir" 2>/dev/null || cd "$BASE_DIR"

    if echo "$audit_prompt" | claude --dangerously-skip-permissions > "$audit_result_file" 2>/dev/null; then
        audit_log "Audit completed successfully: $audit_result_file"

        # Extract overall status from audit
        local audit_status=$(grep -E "Status.*:(.*)(APPROVED|REJECTED)" "$audit_result_file" | head -1 | sed 's/.*Status.*: *\\([^*]*\\).*/\\1/' | tr -d '*')
        local overall_score=$(grep -E "Overall Score.*: *[0-9]+" "$audit_result_file" | head -1 | sed 's/.*Overall Score.*: *\\([0-9]\\+\\).*/\\1/')

        audit_log "Task $task_id audit result: ${audit_status:-UNKNOWN} (Score: ${overall_score:-N/A})"

        # Update task with audit results
        update_task_audit_results "$project" "$task_id" "$audit_result_file" "$audit_status" "$overall_score"

        return 0
    else
        audit_log "ERROR: Claude audit execution failed for task $task_id"
        return 1
    fi
}

# Function to update task with audit results
update_task_audit_results() {
    local project="$1"
    local task_id="$2"
    local audit_file="$3"
    local audit_status="$4"
    local audit_score="$5"

    local queue_file="$BASE_DIR/projects/$project/task-queue.json"
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Add audit trail entry
    local temp_file=$(mktemp)
    jq --arg task_id "$task_id" \\
       --arg timestamp "$timestamp" \\
       --arg audit_file "$audit_file" \\
       --arg audit_status "$audit_status" \\
       --arg audit_score "$audit_score" \\
       '(.tasks[] | select(.id == $task_id)) |= {
         . + {
           updated: $timestamp,
           audit_trail: (.audit_trail + [{
             timestamp: $timestamp,
             action: "audit_completed",
             audit_file: $audit_file,
             audit_status: $audit_status,
             audit_score: ($audit_score | if . != "" then tonumber else null end),
             auditor: "claude-audit-manager"
           }])
         }
       } |
       .last_updated = $timestamp' \\
       "$queue_file" > "$temp_file"

    if [ $? -eq 0 ]; then
        mv "$temp_file" "$queue_file"
        audit_log "Updated task $task_id with audit results"
    else
        rm -f "$temp_file"
        audit_log "ERROR: Failed to update task with audit results"
    fi
}

# Function to audit all projects
audit_all_projects() {
    local last_audit_time="$1"
    local projects_audited=0
    local tasks_audited=0

    for project_dir in "$BASE_DIR/projects"/*; do
        if [ -d "$project_dir" ]; then
            local project=$(basename "$project_dir")
            local queue_file="$project_dir/task-queue.json"

            if validate_task_queue "$queue_file"; then
                audit_log "Checking project: $project"

                # Get completed tasks since last audit
                local completed_tasks=$(get_completed_tasks_since "$project" "$last_audit_time")

                if [ -n "$completed_tasks" ]; then
                    projects_audited=$((projects_audited + 1))

                    echo "$completed_tasks" | while IFS='|' read -r task_id title completion_time duration; do
                        if [ -n "$task_id" ]; then
                            audit_completed_task "$project" "$task_id" "$title" "$completion_time" "$duration"
                            tasks_audited=$((tasks_audited + 1))
                        fi
                    done
                fi
            fi
        fi
    done

    audit_log "Audit cycle completed: $projects_audited projects, $tasks_audited tasks audited"
}

# Function to handle cleanup on shutdown
cleanup_audit_manager() {
    audit_log "Audit manager shutting down..."
    rm -f "$AUDIT_PID_FILE"
    exit 0
}

# Set up signal handlers
trap cleanup_audit_manager SIGTERM SIGINT

# Main audit manager daemon function
main_audit_daemon() {
    # Check if already running
    if [ -f "$AUDIT_PID_FILE" ]; then
        local old_pid=$(cat "$AUDIT_PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            echo "Audit manager already running with PID $old_pid"
            exit 1
        else
            audit_log "Removing stale PID file"
            rm -f "$AUDIT_PID_FILE"
        fi
    fi

    # Save PID
    echo $$ > "$AUDIT_PID_FILE"

    audit_log "=== Claude Nights Watch Audit Manager Started ==="
    audit_log "PID: $$"
    audit_log "Audit results directory: $AUDIT_RESULTS_DIR"
    audit_log "Manager mandate: $MANAGER_MANDATE_FILE"

    # Check if Claude is available
    if ! command -v claude &> /dev/null; then
        audit_log "ERROR: claude command not found - audit manager cannot function"
        exit 1
    fi

    # Check if manager mandate exists
    if [ ! -f "$MANAGER_MANDATE_FILE" ]; then
        audit_log "ERROR: Manager mandate file not found: $MANAGER_MANDATE_FILE"
        exit 1
    fi

    local last_audit_time=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    audit_log "Starting audit cycles every 5 minutes..."

    # Main audit loop
    while true; do
        audit_log "Starting audit cycle..."

        # Audit all projects for completed tasks
        audit_all_projects "$last_audit_time"

        # Update last audit time
        last_audit_time=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

        # Sleep for 5 minutes
        audit_log "Next audit cycle in 5 minutes..."
        sleep 300
    done
}

# Command handling
case "${1:-daemon}" in
    daemon)
        main_audit_daemon
        ;;
    status)
        if [ -f "$AUDIT_PID_FILE" ]; then
            pid=$(cat "$AUDIT_PID_FILE")
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "${GREEN}Audit manager is running with PID $pid${NC}"
                echo "Audit results: $AUDIT_RESULTS_DIR"
                echo "Recent audits:"
                ls -lt "$AUDIT_RESULTS_DIR"/*.md 2>/dev/null | head -5 | while read line; do
                    echo "  $line"
                done
            else
                echo -e "${RED}Audit manager is not running (stale PID file)${NC}"
                exit 1
            fi
        else
            echo -e "${RED}Audit manager is not running${NC}"
            exit 1
        fi
        ;;
    stop)
        if [ -f "$AUDIT_PID_FILE" ]; then
            pid=$(cat "$AUDIT_PID_FILE")
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid"
                echo -e "${GREEN}Audit manager stopped${NC}"
            else
                echo -e "${YELLOW}Audit manager was not running${NC}"
                rm -f "$AUDIT_PID_FILE"
            fi
        else
            echo -e "${YELLOW}Audit manager was not running${NC}"
        fi
        ;;
    logs)
        if [ -f "$AUDIT_LOG_FILE" ]; then
            if [ "$2" = "-f" ]; then
                tail -f "$AUDIT_LOG_FILE"
            else
                tail -50 "$AUDIT_LOG_FILE"
            fi
        else
            echo -e "${RED}No audit log file found${NC}"
            exit 1
        fi
        ;;
    *)
        echo "Claude Nights Watch Audit Manager"
        echo ""
        echo "Usage: $0 {daemon|status|stop|logs} [options]"
        echo ""
        echo "Commands:"
        echo "  daemon          - Start the audit manager daemon (default)"
        echo "  status          - Show audit manager status and recent audits"
        echo "  stop            - Stop the audit manager daemon"
        echo "  logs [-f]       - Show audit logs (use -f to follow)"
        echo ""
        echo "The audit manager monitors completed tasks every 5 minutes and"
        echo "provides independent quality assurance using Claude analysis."
        ;;
esac
