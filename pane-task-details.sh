#!/bin/bash
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

get_active_projects() {
    if [ ! -d "$BASE_DIR/projects" ]; then
        return
    fi

    for project_dir in "$BASE_DIR/projects"/*; do
        if [ -d "$project_dir" ]; then
            project=$(basename "$project_dir")
            queue_file="$BASE_DIR/projects/$project/task-queue.json"

            if [ -f "$queue_file" ] && jq empty "$queue_file" 2>/dev/null; then
                echo "$project"
            fi
        fi
    done
}

get_task_details() {
    local project=$1
    local queue_file="$BASE_DIR/projects/$project/task-queue.json"
    local max_tasks=${2:-5}

    if [ ! -f "$queue_file" ]; then
        return
    fi

    # Get recent tasks with more details
    jq -r --argjson max "$max_tasks" '
        .tasks |
        sort_by(.updated) |
        reverse |
        .[:$max] |
        .[] |
        "\(.id)|\(.title)|\(.status)|\(.priority)|\(.updated)|\(.estimated_duration_minutes // 0)|\(.actual_duration_minutes // 0)"
    ' "$queue_file" 2>/dev/null
}

get_execution_status() {
    local project=$1
    local log_file="$BASE_DIR/logs/$project/claude-nights-watch-daemon.log"

    if [ ! -f "$log_file" ]; then
        echo "No activity"
        return
    fi

    # Check if daemon is currently executing a task
    if tail -10 "$log_file" | grep -q "CLAUDE RESPONSE START" && ! tail -10 "$log_file" | grep -q "CLAUDE RESPONSE END"; then
        # Get the task ID being executed
        local executing_task=$(tail -20 "$log_file" | grep "CLAUDE RESPONSE START" | tail -1 | sed 's/.*Task: \([^)]*\).*/\1/')
        echo "Executing: $executing_task"
    elif tail -5 "$log_file" | grep -q "🚀 EAGER EXECUTION"; then
        echo "Eager mode active"
    elif tail -5 "$log_file" | grep -q "Next check in"; then
        local next_check=$(tail -5 "$log_file" | grep "Next check in" | tail -1 | sed 's/.*Next check in \([^)]*\).*/\1/')
        echo "Monitoring ($next_check)"
    else
        echo "Idle"
    fi
}

format_duration() {
    local minutes=$1
    if [ "$minutes" -eq 0 ] || [ -z "$minutes" ]; then
        echo "N/A"
    elif [ "$minutes" -lt 60 ]; then
        echo "${minutes}m"
    else
        local hours=$((minutes / 60))
        local mins=$((minutes % 60))
        echo "${hours}h ${mins}m"
    fi
}

format_time_ago() {
    local timestamp=$1
    if [ "$timestamp" = "unknown" ] || [ -z "$timestamp" ]; then
        echo "N/A"
        return
    fi

    local updated_epoch=$(date -d "$timestamp" +%s 2>/dev/null || echo "0")
    if [ "$updated_epoch" -eq 0 ]; then
        echo "N/A"
        return
    fi

    local current_epoch=$(date +%s)
    local diff_seconds=$((current_epoch - updated_epoch))

    if [ "$diff_seconds" -lt 60 ]; then
        echo "${diff_seconds}s ago"
    elif [ "$diff_seconds" -lt 3600 ]; then
        local mins=$((diff_seconds / 60))
        echo "${mins}m ago"
    else
        local hours=$((diff_seconds / 3600))
        echo "${hours}h ago"
    fi
}

while true; do
    clear
    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}${BOLD}║        LIVE TASK DETAILS             ║${RESET}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════╝${RESET}"
    echo

    projects=($(get_active_projects))

    if [ ${#projects[@]} -eq 0 ]; then
        echo -e "${DIM}No projects with task queues found${RESET}"
        echo
        echo -e "${CYAN}Waiting for task queues...${RESET}"
    else
        for project in "${projects[@]}"; do
            echo -e "${CYAN}${BOLD}● $project${RESET}"

            # Get execution status
            exec_status=$(get_execution_status "$project")
            echo -e "  ${DIM}Status: $exec_status${RESET}"

            # Get task details
            task_details=$(get_task_details "$project" 4)

            if [ -n "$task_details" ]; then
                echo -e "  ${BOLD}Recent Tasks:${RESET}"
                echo "$task_details" | while IFS='|' read -r id title status priority updated est_duration actual_duration; do
                    # Status icon
                    case "$status" in
                        "completed") status_icon="${GREEN}✓${RESET}" ;;
                        "in_progress") status_icon="${YELLOW}⚡${RESET}" ;;
                        "failed") status_icon="${RED}✗${RESET}" ;;
                        *) status_icon="${CYAN}○${RESET}" ;;
                    esac

                    # Priority color
                    case "$priority" in
                        "high") priority_color="${RED}$priority${RESET}" ;;
                        "medium") priority_color="${YELLOW}$priority${RESET}" ;;
                        *) priority_color="${CYAN}$priority${RESET}" ;;
                    esac

                    # Truncate long titles
                    if [ ${#title} -gt 35 ]; then
                        title="${title:0:32}..."
                    fi

                    echo -e "    $status_icon ${BOLD}$id${RESET}: $title"
                    echo -e "      Priority: $priority_color | Updated: ${DIM}$(format_time_ago "$updated")${RESET}"

                    if [ "$status" = "completed" ] && [ "$actual_duration" -gt 0 ]; then
                        echo -e "      Duration: ${GREEN}$(format_duration "$actual_duration")${RESET}"
                    elif [ "$est_duration" -gt 0 ]; then
                        echo -e "      Estimated: ${DIM}$(format_duration "$est_duration")${RESET}"
                    fi
                    echo
                done
            else
                echo -e "  ${DIM}No tasks found${RESET}"
                echo
            fi

            echo "────────────────────────────────────────"
        done
    fi

    echo -e "${CYAN}Updated: $(date '+%H:%M:%S')${RESET}"
    echo -e "${DIM}Refreshing every 10 seconds...${RESET}"

    sleep 10
done
