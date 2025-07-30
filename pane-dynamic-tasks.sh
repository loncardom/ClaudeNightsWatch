#!/bin/bash
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Accept pane number as parameter (1 or 2)
PANE_NUM=${1:-1}

# Colors
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

get_active_daemon_projects() {
    if [ ! -d "$BASE_DIR/projects" ]; then
        return
    fi

    for project_dir in "$BASE_DIR/projects"/*; do
        if [ -d "$project_dir" ]; then
            project=$(basename "$project_dir")
            pid_file="$BASE_DIR/logs/$project/claude-nights-watch-daemon.pid"
            queue_file="$BASE_DIR/projects/$project/task-queue.json"

            # Check if daemon is running
            if [ -f "$pid_file" ]; then
                local pid=$(cat "$pid_file" 2>/dev/null)
                if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                    echo "$project"
                fi
            fi
        fi
    done
}

get_project_task_details() {
    local project=$1
    local queue_file="$BASE_DIR/projects/$project/task-queue.json"
    local max_tasks=${2:-8}

    if [ ! -f "$queue_file" ]; then
        return
    fi

    # Get task details with status priority
    jq -r --argjson max "$max_tasks" '
        .tasks |
        sort_by(
            if .status == "in_progress" then 1
            elif .status == "pending" then 2
            elif .status == "failed" then 3
            else 4 end
        ) |
        .[:$max] |
        .[] |
        "\(.id)|\(.title)|\(.status)|\(.priority)|\(.updated)|\(.estimated_duration_minutes // 0)|\(.actual_duration_minutes // 0)"
    ' "$queue_file" 2>/dev/null
}

get_project_queue_stats() {
    local project=$1
    local queue_file="$BASE_DIR/projects/$project/task-queue.json"

    if [ ! -f "$queue_file" ]; then
        echo "0|0|0|0"
        return
    fi

    local total=$(jq -r '.queue_metadata.total_tasks // 0' "$queue_file" 2>/dev/null || echo "0")
    local pending=$(jq -r '.queue_metadata.pending_tasks // 0' "$queue_file" 2>/dev/null || echo "0")
    local in_progress=$(jq -r '.queue_metadata.in_progress_tasks // 0' "$queue_file" 2>/dev/null || echo "0")
    local completed=$(jq -r '.queue_metadata.completed_tasks // 0' "$queue_file" 2>/dev/null || echo "0")

    echo "$total|$pending|$in_progress|$completed"
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
        local executing_task=$(tail -20 "$log_file" | grep "CLAUDE RESPONSE START" | tail -1 | sed 's/.*Task: \([^)]*\).*/\1/')
        echo "🚀 Executing: $executing_task"
    elif tail -5 "$log_file" | grep -q "🚀 EAGER EXECUTION"; then
        echo "⚡ Eager mode active"
    elif tail -3 "$log_file" | grep -q "Next check in"; then
        echo "📊 Monitoring"
    else
        echo "💤 Idle"
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
    echo -e "${BLUE}${BOLD}╔════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}${BOLD}║      ACTIVE PROJECT TASKS #${PANE_NUM}            ║${RESET}"
    echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════╝${RESET}"
    echo

    active_projects=($(get_active_daemon_projects))
    active_count=${#active_projects[@]}

    if [ "$active_count" -eq 0 ]; then
        echo -e "${DIM}No active daemon projects found${RESET}"
        echo
        echo -e "${CYAN}🔍 Waiting for active daemons...${RESET}"
        echo -e "${DIM}Start a daemon with:${RESET}"
        echo -e "${DIM}./claude-nights-watch-manager.sh start \\${RESET}"
        echo -e "${DIM}  --project PROJECT --target /path${RESET}"
    elif [ "$PANE_NUM" -gt "$active_count" ]; then
        # This pane number exceeds available projects
        if [ "$active_count" -eq 1 ]; then
            echo -e "${CYAN}${BOLD}📋 ${active_projects[0]} (continued)${RESET}"
            echo

            # Show additional tasks from the first project
            project="${active_projects[0]}"
            task_details=$(get_project_task_details "$project" 20)

            if [ -n "$task_details" ]; then
                echo -e "  ${BOLD}Additional Tasks:${RESET}"
                # Skip first 8 tasks (shown in pane 1) and show next 8
                echo "$task_details" | tail -n +9 | head -8 | while IFS='|' read -r id title status priority updated est_duration actual_duration; do
                    # Status icon
                    case "$status" in
                        "completed") status_icon="${GREEN}✓${RESET}" ;;
                        "in_progress") status_icon="${YELLOW}⚡${RESET}" ;;
                        "failed") status_icon="${RED}✗${RESET}" ;;
                        *) status_icon="${CYAN}○${RESET}" ;;
                    esac

                    # Priority color
                    case "$priority" in
                        "high") priority_color="${RED}HIGH${RESET}" ;;
                        "medium") priority_color="${YELLOW}MED${RESET}" ;;
                        *) priority_color="${DIM}LOW${RESET}" ;;
                    esac

                    # Truncate long titles
                    if [ ${#title} -gt 45 ]; then
                        title="${title:0:42}..."
                    fi

                    echo -e "    $status_icon ${BOLD}$id${RESET}: $title"
                    echo -e "      Priority: $priority_color | ${DIM}$(format_time_ago "$updated")${RESET}"
                    echo
                done
            else
                echo -e "  ${DIM}No additional tasks${RESET}"
            fi
        else
            echo -e "${DIM}Pane #${PANE_NUM} - No project assigned${RESET}"
            echo
            echo -e "${CYAN}Only ${active_count} active project(s):${RESET}"
            for i in "${!active_projects[@]}"; do
                echo -e "${DIM}  $((i+1)). ${active_projects[i]}${RESET}"
            done
        fi
    else
        # Show the project assigned to this pane
        project_index=$((PANE_NUM - 1))
        project="${active_projects[$project_index]}"

        echo -e "${CYAN}${BOLD}🚀 $project${RESET}"

        # Get execution status and stats
        exec_status=$(get_execution_status "$project")
        queue_stats=$(get_project_queue_stats "$project")
        total=$(echo "$queue_stats" | cut -d'|' -f1)
        pending=$(echo "$queue_stats" | cut -d'|' -f2)
        in_progress=$(echo "$queue_stats" | cut -d'|' -f3)
        completed=$(echo "$queue_stats" | cut -d'|' -f4)

        echo -e "  ${DIM}$exec_status${RESET}"
        echo -e "  ${BOLD}Queue:${RESET} ${total} tasks | ${GREEN}✓${completed} ${YELLOW}⚡${in_progress} ${CYAN}○${pending}${RESET}"
        echo

        # Get task details
        task_details=$(get_project_task_details "$project" 8)

        if [ -n "$task_details" ]; then
            echo -e "  ${BOLD}Priority Tasks:${RESET}"
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
                    "high") priority_color="${RED}HIGH${RESET}" ;;
                    "medium") priority_color="${YELLOW}MED${RESET}" ;;
                    *) priority_color="${DIM}LOW${RESET}" ;;
                esac

                # Truncate long titles
                if [ ${#title} -gt 45 ]; then
                    title="${title:0:42}..."
                fi

                echo -e "    $status_icon ${BOLD}$id${RESET}: $title"
                echo -e "      Priority: $priority_color | ${DIM}$(format_time_ago "$updated")${RESET}"

                if [ "$status" = "completed" ] && [ "$actual_duration" -gt 0 ]; then
                    echo -e "      Completed in: ${GREEN}$(format_duration "$actual_duration")${RESET}"
                elif [ "$status" = "in_progress" ]; then
                    echo -e "      ${YELLOW}Currently executing...${RESET}"
                elif [ "$est_duration" -gt 0 ]; then
                    echo -e "      Estimated: ${DIM}$(format_duration "$est_duration")${RESET}"
                fi
                echo
            done
        else
            echo -e "  ${DIM}No tasks found${RESET}"
        fi

        # Show other active projects if any
        if [ "$active_count" -gt 2 ]; then
            echo "────────────────────────────────────────────"
            other_projects=()
            for i in "${!active_projects[@]}"; do
                if [ "$i" -ne "$project_index" ] && [ "$i" -ne 0 ] && [ "$PANE_NUM" -eq 2 ]; then
                    other_projects+=("${active_projects[i]}")
                elif [ "$i" -ne "$project_index" ] && [ "$i" -ne 1 ] && [ "$PANE_NUM" -eq 1 ]; then
                    other_projects+=("${active_projects[i]}")
                fi
            done
            if [ ${#other_projects[@]} -gt 0 ]; then
                echo -e "${DIM}Other active: ${other_projects[*]}${RESET}"
            fi
        fi
    fi

    echo
    echo -e "${CYAN}Updated: $(date '+%H:%M:%S')${RESET}"
    echo -e "${DIM}Refreshing every 10 seconds...${RESET}"

    sleep 10
done
