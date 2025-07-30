#!/bin/bash

# Claude Nights Watch Manager - Start, stop, and manage the task execution daemon

# Base directory is always the ClaudeNightsWatch installation
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
DAEMON_SCRIPT="$BASE_DIR/claude-nights-watch-daemon.sh"
PID_FILE="$TASK_DIR/logs/claude-nights-watch-daemon.pid"
LOG_FILE="$TASK_DIR/logs/claude-nights-watch-daemon.log"
START_TIME_FILE="$TASK_DIR/logs/claude-nights-watch-start-time"
TASK_FILE="task.md"
RULES_FILE="rules.md"

# Audit injection settings
ENABLE_AUDIT_INJECTION=${CLAUDE_NIGHTS_WATCH_ENABLE_AUDIT_INJECTION:-true}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_task() {
    echo -e "${BLUE}[TASK]${NC} $1"
}

count_pending_tasks() {
    local queue_file="$1"

    if [ ! -f "$queue_file" ]; then
        echo "0"
        return
    fi

    # Check if JSON is valid
    if ! jq empty "$queue_file" 2>/dev/null; then
        echo "0"
        return
    fi

    # Count pending tasks
    local pending_count=$(jq '.tasks | map(select(.status == "pending")) | length' "$queue_file" 2>/dev/null || echo "0")
    echo "$pending_count"
}

inject_audit_task() {
    local project_name="$1"
    local target_dir="$2"

    if [ "$ENABLE_AUDIT_INJECTION" != "true" ]; then
        return 0
    fi

    local project_config_dir="$BASE_DIR/projects/$project_name"
    local task_file="$project_config_dir/task.md"
    local queue_file="$project_config_dir/task-queue.json"

    # Skip if this is the ClaudeNightsWatch project itself
    if [[ "$target_dir" == *"ClaudeNightsWatch"* ]]; then
        return 0
    fi

    # Check if project needs audit injection
    local needs_audit=false

    # Case 1: No task files at all (traditional check)
    if [ ! -f "$task_file" ] && [ ! -f "$queue_file" ]; then
        needs_audit=true
        print_status "No tasks found for project '$project_name' - needs audit injection"
    # Case 2: Has task queue but 0 pending tasks
    elif [ -f "$queue_file" ]; then
        local pending_count=$(count_pending_tasks "$queue_file")
        if [ "$pending_count" -eq 0 ]; then
            needs_audit=true
            print_status "Task queue for project '$project_name' has $pending_count pending tasks - needs audit injection"
        else
            print_status "Task queue for project '$project_name' has $pending_count pending tasks - skipping audit injection"
            return 0
        fi
    # Case 3: Only has task.md but no queue (legacy support)
    elif [ -f "$task_file" ]; then
        print_status "Project '$project_name' has task.md file - skipping audit injection"
        return 0
    fi

    if [ "$needs_audit" = true ]; then
        print_status "No tasks found for project '$project_name' - injecting audit task"

        # Create project directory if it doesn't exist
        mkdir -p "$project_config_dir"

        # Check if target directory has README.md
        local readme_exists=false
        if [ -f "$target_dir/README.md" ] || [ -f "$target_dir/readme.md" ] || [ -f "$target_dir/Readme.md" ]; then
            readme_exists=true
        fi

        # Generate audit task based on README existence
        if [ "$readme_exists" = true ]; then
            # Add audit signature to existing README
            cat > "$task_file" << 'EOF'
# Audit Task - Add Audit Signature

Add an "Audited by Claude Nights Watch" signature to the existing README file.

## Task
1. Navigate to the target project directory
2. Locate the README file (README.md, readme.md, or Readme.md)
3. Add the following audit signature at the end of the file:

```
---
*Audited by Claude Nights Watch on $(date '+%Y-%m-%d %H:%M:%S')*
```

4. Commit the changes with message: "Add Claude Nights Watch audit signature"

## Safety Rules
- Only modify README files
- Do not alter existing content
- Only add the audit signature
- Use git for all changes
EOF
        else
            # Create new README.md
            cat > "$task_file" << 'EOF'
# Audit Task - Create README

Create a basic README.md file for this project since none exists.

## Task
1. Navigate to the target project directory
2. Analyze the project structure to understand what kind of project this is
3. Create a basic README.md file with the following sections:
   - Project title (inferred from directory name or package.json)
   - Brief description of what this project does
   - Basic installation/setup instructions if applicable
   - Usage instructions if applicable
   - Audit signature: "---\n*Audited by Claude Nights Watch on $(date '+%Y-%m-%d %H:%M:%S')*"

4. Commit the changes with message: "Add README.md via Claude Nights Watch audit"

## Safety Rules
- Only create README.md file
- Do not modify existing files
- Keep content professional and minimal
- Use git for all changes
EOF
        fi

        print_status "Audit task injected for project '$project_name'"
        return 0
    fi

    return 0
}

audit_all_projects() {
    if [ "$ENABLE_AUDIT_INJECTION" != "true" ]; then
        print_status "Audit injection is disabled globally"
        return 0
    fi

    if [ ! -d "$BASE_DIR/projects" ]; then
        print_status "No projects directory found - nothing to audit"
        return 0
    fi

    print_status "Running audit injection for all projects..."
    local projects_audited=0

    for project_dir in "$BASE_DIR/projects"/*; do
        if [ -d "$project_dir" ]; then
            local project_name=$(basename "$project_dir")
            local target_file="$project_dir/.target"

            if [ -f "$target_file" ]; then
                local target_dir=$(cat "$target_file")
                print_status "Checking project: $project_name (target: $target_dir)"

                # Check if project needs audit injection
                local task_file="$project_dir/task.md"
                local queue_file="$project_dir/task-queue.json"

                local needs_audit=false

                # Case 1: No task files at all
                if [ ! -f "$task_file" ] && [ ! -f "$queue_file" ]; then
                    needs_audit=true
                # Case 2: Has task queue but 0 pending tasks
                elif [ -f "$queue_file" ]; then
                    local pending_count=$(count_pending_tasks "$queue_file")
                    if [ "$pending_count" -eq 0 ]; then
                        needs_audit=true
                    fi
                fi

                if [ "$needs_audit" = true ]; then
                    inject_audit_task "$project_name" "$target_dir"
                    projects_audited=$((projects_audited + 1))
                else
                    if [ -f "$queue_file" ]; then
                        local pending_count=$(count_pending_tasks "$queue_file")
                        print_status "Project $project_name has $pending_count pending tasks - skipping audit injection"
                    elif [ -f "$task_file" ]; then
                        print_status "Project $project_name has task.md file - skipping audit injection"
                    fi
                fi
            else
                print_warning "No .target file found for project $project_name - skipping"
            fi
        fi
    done

    print_status "Audit injection completed - $projects_audited projects received audit tasks"
    return 0
}

start_daemon() {
    # If no project is specified, start all daemons
    if [[ ! "$*" =~ "--project" ]]; then
        print_status "No project specified, attempting to start all daemons..."
        if [ ! -d "$BASE_DIR/projects" ]; then
            print_warning "No projects directory found. Cannot start any daemons."
            return 1
        fi

        # First, run audit injection for all projects
        print_status "=== Running audit injection for all projects before startup ==="
        audit_all_projects
        echo ""

        for project_dir in "$BASE_DIR/projects"/*; do
            if [ -d "$project_dir" ]; then
                local project_name=$(basename "$project_dir")
                local target_file="$project_dir/.target"
                if [ -f "$target_file" ]; then
                    local target_dir=$(cat "$target_file")
                    print_status "--- Starting daemon for project: $project_name ---"
                    # Call start_daemon with the required parameters
                    start_daemon start --project "$project_name" --target "$target_dir"
                else
                    print_warning "No .target file found for project $project_name. Cannot start daemon."
                fi
            fi
        done
        return 0
    fi

    # Parse parameters
    local project_name=""
    local target_dir=""
    local start_time=""
    local disable_audit_injection=false

    shift # remove 'start'
    while [ $# -gt 0 ]; do
        case "$1" in
            --project)
                project_name="$2"
                shift 2
                ;;
            --target)
                target_dir="$2"
                shift 2
                ;;
            --at)
                start_time="$2"
                shift 2
                ;;
            --no-audit-injection)
                disable_audit_injection=true
                shift
                ;;
            *)
                print_error "Unknown option for start: $1"
                return 1
                ;;
        esac
    done

    if [ -z "$project_name" ] || [ -z "$target_dir" ]; then
        print_error "--project and --target are required for starting a daemon."
        return 1
    fi

    local project_config_dir="$BASE_DIR/projects/$project_name"
    local task_file="$project_config_dir/task.md"
    local queue_file="$project_config_dir/task-queue.json"
    local pid_file="$BASE_DIR/logs/$project_name/claude-nights-watch-daemon.pid"
    local log_file="$BASE_DIR/logs/$project_name/claude-nights-watch-daemon.log"
    local start_time_file="$BASE_DIR/logs/$project_name/claude-nights-watch-start-time"

    mkdir -p "$(dirname "$pid_file")"

    # Pre-flight check: Ensure a task file or queue exists, or inject audit task
    if [ ! -f "$task_file" ] && [ ! -f "$queue_file" ]; then
        # Try to inject audit task (unless disabled)
        if [ "$disable_audit_injection" = false ] && [ "$ENABLE_AUDIT_INJECTION" = "true" ]; then
            inject_audit_task "$project_name" "$target_dir"
        fi

        # Check again after injection
        if [ ! -f "$task_file" ] && [ ! -f "$queue_file" ]; then
            print_warning "No task file (task.md) or task queue (task-queue.json) found for project '$project_name'."
            if [ "$disable_audit_injection" = true ] || [ "$ENABLE_AUDIT_INJECTION" != "true" ]; then
                print_warning "Audit task injection is disabled. Create a task file to proceed."
            else
                print_warning "Audit task injection failed. Create a task file to proceed."
            fi
            return 1
        fi
    fi

    # Handle start time if provided
    if [ -n "$start_time" ]; then
        if [[ "$start_time" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
            start_time="$(date '+%Y-%m-%d') $start_time:00"
        fi
        local start_epoch=$(date -d "$start_time" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$start_time" +%s 2>/dev/null)
        if [ $? -ne 0 ]; then
            print_error "Invalid time format for project $project_name. Use 'HH:MM' or 'YYYY-MM-DD HH:MM'"
            return 1
        fi
        echo "$start_epoch" > "$start_time_file"
        print_status "Daemon for $project_name will start monitoring at: $(date -d "@$start_epoch" 2>/dev/null || date -r "$start_epoch")"
    else
        rm -f "$start_time_file" 2>/dev/null
    fi

    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            print_error "Daemon for $project_name is already running with PID $pid"
            return 1
        fi
    fi

    print_status "Starting Claude Nights Watch daemon..."
    print_status "Project: $project_name"
    print_status "Target directory: $target_dir"

    export CLAUDE_NIGHTS_WATCH_PROJECT="$project_name"
    export CLAUDE_NIGHTS_WATCH_TARGET_DIR="$target_dir"
    nohup "$DAEMON_SCRIPT" > "$BASE_DIR/logs/${project_name}_daemon_startup.log" 2>&1 &

    for i in {1..5}; do
        sleep 1
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                print_status "Daemon for $project_name started successfully with PID $pid"
                return 0
            fi
        fi
    done

    print_error "Failed to start daemon for project $project_name"
    return 1
}

stop_daemon() {
    # If no project is specified, stop all daemons
    if [[ ! "$*" =~ "--project" ]]; then
        print_status "No project specified, attempting to stop all daemons..."
        if [ ! -d "$BASE_DIR/logs" ]; then
            print_warning "No logs directory found. Cannot stop any daemons."
            return 1
        fi
        for project_log_dir in "$BASE_DIR/logs"/*; do
            if [ -d "$project_log_dir" ]; then
                local project_name=$(basename "$project_log_dir")
                print_status "--- Stopping daemon for project: $project_name ---"
                # Call stop_daemon with the required parameters
                stop_daemon stop --project "$project_name"
            fi
        done
        return 0
    fi

    local project_name=""
    shift # remove 'stop'
    while [ $# -gt 0 ]; do
        case "$1" in
            --project)
                project_name="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option for stop: $1"
                return 1
                ;;
        esac
    done

    if [ -z "$project_name" ]; then
        print_error "--project is required for stopping a daemon."
        return 1
    fi

    local pid_file="$BASE_DIR/logs/$project_name/claude-nights-watch-daemon.pid"

    if [ ! -f "$pid_file" ]; then
        print_warning "Daemon for $project_name is not running (no PID file found)"
        return 1
    fi

    local pid=$(cat "$pid_file")

    if ! kill -0 "$pid" 2>/dev/null; then
        print_warning "Daemon for $project_name is not running (process $pid not found)"
        rm -f "$pid_file"
        return 1
    fi

    print_status "Stopping daemon for $project_name with PID $pid..."
    kill "$pid"

    for i in {1..10}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            print_status "Daemon for $project_name stopped successfully"
            rm -f "$pid_file"
            return 0
        fi
        sleep 1
    done

    print_warning "Daemon for $project_name did not stop gracefully, forcing..."
    kill -9 "$pid" 2>/dev/null
    rm -f "$pid_file"
    print_status "Daemon for $project_name stopped"
}

show_project_status() {
    local project_name="$1"

    local pid_file="$BASE_DIR/logs/$project_name/claude-nights-watch-daemon.pid"
    local log_file="$BASE_DIR/logs/$project_name/claude-nights-watch-daemon.log"
    local start_time_file="$BASE_DIR/logs/$project_name/claude-nights-watch-start-time"
    local task_file="$BASE_DIR/projects/$project_name/task.md"
    local rules_file="$BASE_DIR/projects/$project_name/rules.md"

    if [ ! -f "$pid_file" ]; then
        print_status "Daemon for $project_name is not running"
        return 1
    fi

    local pid=$(cat "$pid_file")

    if kill -0 "$pid" 2>/dev/null; then
        print_status "Daemon for $project_name is running with PID $pid"

        if [ -f "$start_time_file" ]; then
            local start_epoch=$(cat "$start_time_file")
            local current_epoch=$(date +%s)

            if [ "$current_epoch" -ge "$start_epoch" ]; then
                print_status "Status: ✅ ACTIVE - Task execution monitoring enabled"
            else
                local time_until_start=$((start_epoch - current_epoch))
                local hours=$((time_until_start / 3600))
                local minutes=$(((time_until_start % 3600) / 60))
                print_status "Status: ⏰ WAITING - Will activate in ${hours}h ${minutes}m"
                print_status "Start time: $(date -d "@$start_epoch" 2>/dev/null || date -r "$start_epoch")"
            fi
        else
            print_status "Status: ✅ ACTIVE - Task execution monitoring enabled"
        fi

        echo ""
        if [ -f "$task_file" ]; then
            print_task "Task file: $task_file ($(wc -l < "$task_file") lines)"
        else
            print_warning "Task file not found at $task_file"
        fi

        if [ -f "$rules_file" ]; then
            print_task "Rules file: $rules_file ($(wc -l < "$rules_file") lines)"
        else
            print_status "No rules file (consider creating $rules_file for safety)"
        fi

        if [ -f "$log_file" ]; then
            echo ""
            print_status "Recent activity:"
            tail -5 "$log_file" | sed 's/^/  /'
        fi

        return 0
    else
        print_warning "Daemon for $project_name is not running (process $pid not found)"
        rm -f "$pid_file"
        return 1
    fi
}

status_daemon() {
    local project_name=""
    shift # remove 'status'
    while [ $# -gt 0 ]; do
        case "$1" in
            --project)
                project_name="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option for status: $1"
                return 1
                ;;
        esac
    done

    # If no project specified, show status for all projects
    if [ -z "$project_name" ]; then
        print_status "Claude Nights Watch - Global Status"
        echo "=================================="
        echo ""

        if [ ! -d "$BASE_DIR/projects" ]; then
            print_warning "No projects directory found"
            return 1
        fi

        local any_running=false
        local project_count=0

        for project_dir in "$BASE_DIR/projects"/*; do
            if [ -d "$project_dir" ]; then
                local proj_name=$(basename "$project_dir")
                project_count=$((project_count + 1))

                echo "📁 Project: $proj_name"
                echo "----------------------------------------"

                if show_project_status "$proj_name" 2>/dev/null; then
                    any_running=true
                fi
                echo ""
            fi
        done

        if [ $project_count -eq 0 ]; then
            print_warning "No projects configured"
            return 1
        fi

        echo "=================================="
        if [ "$any_running" = true ]; then
            print_status "Summary: $project_count projects configured, some daemons running"
        else
            print_status "Summary: $project_count projects configured, no daemons running"
        fi

        return 0
    else
        # Show status for specific project
        show_project_status "$project_name"
    fi
}

restart_daemon() {
    print_status "Restarting daemon..."
    stop_daemon
    sleep 2
    start_daemon "$@"
}

show_logs() {
    local project_name=""
    local follow=false
    shift # remove 'logs'
    while [ $# -gt 0 ]; do
        case "$1" in
            --project)
                project_name="$2"
                shift 2
                ;;
            -f)
                follow=true
                shift
                ;;
            *)
                print_error "Unknown option for logs: $1"
                return 1
                ;;
        esac
    done

    if [ -z "$project_name" ]; then
        print_error "--project is required for showing logs."
        return 1
    fi

    local log_file="$BASE_DIR/logs/$project_name/claude-nights-watch-daemon.log"

    if [ ! -f "$log_file" ]; then
        print_error "No log file found for project $project_name"
        return 1
    fi

    if [ "$follow" = true ]; then
        tail -f "$log_file"
    else
        tail -50 "$log_file"
    fi
}

show_task() {
    local project_name=""
    shift # remove 'task'
    while [ $# -gt 0 ]; do
        case "$1" in
            --project)
                project_name="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option for task: $1"
                return 1
                ;;
        esac
    done

    if [ -z "$project_name" ]; then
        print_error "--project is required for showing the task."
        return 1
    fi

    local task_file="$BASE_DIR/projects/$project_name/task.md"
    local rules_file="$BASE_DIR/projects/$project_name/rules.md"

    if [ ! -f "$task_file" ]; then
        print_error "No task file found for project $project_name at $task_file"
        return 1
    fi

    echo ""
    print_task "Current task for project $project_name ($task_file):"
    echo "============================================"
    cat "$task_file"
    echo "============================================"

    if [ -f "$rules_file" ]; then
        echo ""
        print_task "Current rules for project $project_name ($rules_file):"
        echo "============================================"
        cat "$rules_file"
        echo "============================================"
    fi
}

# Main command handling
case "$1" in
    start)
        start_daemon "$@"
        ;;
    stop)
        stop_daemon "$@"
        ;;
    restart)
        stop_daemon "$@"
        sleep 2
        start_daemon "$@"
        ;;
    status)
        status_daemon "$@"
        ;;
    logs)
        show_logs "$@"
        ;;
    task)
        show_task "$@"
        ;;
    audit-all)
        audit_all_projects
        ;;
    *)
        echo "Claude Nights Watch - Autonomous Task Execution Daemon"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|task|audit-all} --project PROJECT_NAME [options]"
        echo ""
        echo "Commands:"
        echo "  start --project NAME --target DIR [--no-audit-injection] - Start the daemon for specified project"
        echo "  start --at TIME                      - Start daemon but begin monitoring at specified time"
        echo "  stop --project NAME                  - Stop the daemon for specified project"
        echo "  restart --project NAME --target DIR  - Restart the daemon"
        echo "  status [--project NAME]              - Show daemon status (all projects or specified project)"
        echo "  logs --project NAME [-f]             - Show recent logs (use -f to follow)"
        echo "  task --project NAME                  - Display current task and rules for project"
        echo "  audit-all                            - Inject audit tasks for all projects without existing tasks"
        echo ""
        echo "Required Parameters:"
        echo "  --project NAME   - Name of the project configuration (e.g., 'my-project')"
        echo "  --target DIR     - Path to the target project directory"
        echo ""
        echo "Optional Parameters:"
        echo "  --no-audit-injection - Disable automatic audit task injection for empty projects"
        echo ""
        echo "Environment Variables:"
        echo "  CLAUDE_NIGHTS_WATCH_ENABLE_AUDIT_INJECTION - Enable/disable audit injection (default: true)"
        ;;
esac
