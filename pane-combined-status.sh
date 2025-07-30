#!/bin/bash
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
RESET='\033[0m'

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

get_minutes_until_reset() {
    local ccusage_cmd=$(get_ccusage_cmd)
    if [ $? -ne 0 ]; then
        return 1
    fi

    local json_output=$($ccusage_cmd blocks --json --active 2>/dev/null)
    if [ -z "$json_output" ] || ! echo "$json_output" | grep -q '"endTime"'; then
        return 1
    fi

    local end_time=$(echo "$json_output" | grep '"endTime"' | head -1 | sed 's/.*"endTime": *"\([^"]*\)".*/\1/')
    if [ -z "$end_time" ]; then
        return 1
    fi

    local end_epoch
    if end_epoch=$(date -d "$end_time" +%s 2>/dev/null); then
        :
    elif end_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S.000Z" "$end_time" +%s 2>/dev/null); then
        :
    else
        return 1
    fi

    local current_epoch=$(date +%s)
    local time_diff=$((end_epoch - current_epoch))
    local remaining_minutes=$((time_diff / 60))

    if [ "$remaining_minutes" -gt 0 ]; then
        echo $remaining_minutes
    else
        echo "0"
    fi
}

get_daemon_info() {
    local project=$1
    local log_dir="$BASE_DIR/logs/$project"
    local pid_file="$log_dir/claude-nights-watch-daemon.pid"

    if [ ! -f "$pid_file" ]; then
        echo "STOPPED|0"
        return
    fi

    local pid=$(cat "$pid_file" 2>/dev/null)
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        echo "STOPPED|0"
        return
    fi

    echo "RUNNING|$pid"
}

get_task_queue_info() {
    local project=$1
    local queue_file="$BASE_DIR/projects/$project/task-queue.json"

    if [ ! -f "$queue_file" ] || ! jq empty "$queue_file" 2>/dev/null; then
        echo "NO_QUEUE|0|0|0|0|0"
        return
    fi

    local total_tasks=$(jq -r '.queue_metadata.total_tasks // 0' "$queue_file" 2>/dev/null || echo "0")
    local pending_tasks=$(jq -r '.queue_metadata.pending_tasks // 0' "$queue_file" 2>/dev/null || echo "0")
    local in_progress_tasks=$(jq -r '.queue_metadata.in_progress_tasks // 0' "$queue_file" 2>/dev/null || echo "0")
    local completed_tasks=$(jq -r '.queue_metadata.completed_tasks // 0' "$queue_file" 2>/dev/null || echo "0")
    local failed_tasks=$(jq -r '.queue_metadata.failed_tasks // 0' "$queue_file" 2>/dev/null || echo "0")

    echo "QUEUE_EXISTS|$total_tasks|$pending_tasks|$in_progress_tasks|$completed_tasks|$failed_tasks"
}

get_task_categories() {
    local project=$1
    local queue_file="$BASE_DIR/projects/$project/task-queue.json"

    if [ ! -f "$queue_file" ]; then
        return
    fi

    local bugs=$(jq '[.tasks[] | select(.title | contains("bugs issues"))] | length' "$queue_file" 2>/dev/null || echo "0")
    local security=$(jq '[.tasks[] | select(.title | contains("security issues"))] | length' "$queue_file" 2>/dev/null || echo "0")
    local style=$(jq '[.tasks[] | select(.title | contains("style issues"))] | length' "$queue_file" 2>/dev/null || echo "0")
    local complexity=$(jq '[.tasks[] | select(.title | contains("complexity issues"))] | length' "$queue_file" 2>/dev/null || echo "0")
    local type_issues=$(jq '[.tasks[] | select(.title | contains("type_issues issues"))] | length' "$queue_file" 2>/dev/null || echo "0")

    local categories=""
    [ "$bugs" -gt 0 ] && categories="${categories}🐛${bugs} "
    [ "$security" -gt 0 ] && categories="${categories}🔒${security} "
    [ "$style" -gt 0 ] && categories="${categories}🎨${style} "
    [ "$complexity" -gt 0 ] && categories="${categories}🔄${complexity} "
    [ "$type_issues" -gt 0 ] && categories="${categories}📝${type_issues}"

    if [ -n "$categories" ]; then
        echo "$categories"
    fi
}

while true; do
    clear
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║          SYSTEM STATUS               ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${RESET}"
    echo

    # --- DAEMON STATUS ---
    minutes_remaining=$(get_minutes_until_reset)
    if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ]; then
        hours=$((minutes_remaining / 60))
        mins=$((minutes_remaining % 60))
        if [ "$minutes_remaining" -lt 30 ]; then
            color=$YELLOW
        else
            color=$GREEN
        fi
        echo -e "${color}● Usage Window: ${hours}h ${mins}m remaining${RESET}"
    else
        echo -e "${RED}● Usage Window: No active window${RESET}"
    fi
    echo

    echo -e "${BOLD}Active Daemons:${RESET}"
    echo "────────────────────────────────────────"

    daemon_count=0
    if [ -d "$BASE_DIR/projects" ]; then
        for project_dir in "$BASE_DIR/projects"/*; do
            if [ -d "$project_dir" ]; then
                project=$(basename "$project_dir")
                daemon_info=$(get_daemon_info "$project")
                status=$(echo "$daemon_info" | cut -d'|' -f1)
                pid=$(echo "$daemon_info" | cut -d'|' -f2)

                if [ "$status" = "RUNNING" ]; then
                    echo -e "${GREEN}● $project${RESET} (PID: $pid)"
                    daemon_count=$((daemon_count + 1))
                else
                    echo -e "${RED}○ $project${RESET} (stopped)"
                fi
            fi
        done
    fi

    echo "────────────────────────────────────────"
    echo -e "${BOLD}Total Active: $daemon_count${RESET}"
    echo

    # --- LIVE TASK QUEUE ---
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║       LIVE TASK QUEUE STATUS         ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${RESET}"
    echo

    total_pending=0
    total_in_progress=0
    total_completed=0
    active_projects=0

    if [ -d "$BASE_DIR/projects" ]; then
        for project_dir in "$BASE_DIR/projects"/*; do
            if [ -d "$project_dir" ]; then
                project=$(basename "$project_dir")
                queue_info=$(get_task_queue_info "$project")
                has_queue=$(echo "$queue_info" | cut -d'|' -f1)

                if [ "$has_queue" = "QUEUE_EXISTS" ]; then
                    active_projects=$((active_projects + 1))
                    total=$(echo "$queue_info" | cut -d'|' -f2)
                    pending=$(echo "$queue_info" | cut -d'|' -f3)
                    in_progress=$(echo "$queue_info" | cut -d'|' -f4)
                    completed=$(echo "$queue_info" | cut -d'|' -f5)
                    failed=$(echo "$queue_info" | cut -d'|' -f6)

                    total_pending=$((total_pending + pending))
                    total_in_progress=$((total_in_progress + in_progress))
                    total_completed=$((total_completed + completed))

                    project_icon="${CYAN}◉${RESET}"
                    if [ "$pending" -gt 0 ]; then
                        project_icon="${YELLOW}◉${RESET}"
                    fi
                    if [ "$in_progress" -gt 0 ]; then
                        project_icon="${GREEN}◉${RESET}"
                    fi

                    echo -e "$project_icon ${BOLD}$project${RESET}"
                    echo -e "  Tasks: ${total} | ${GREEN}✓${completed} ${YELLOW}⚡${in_progress} ${CYAN}○${pending}${RESET}$([ "$failed" -gt 0 ] && echo " ${RED}✗${failed}${RESET}")"

                    categories=$(get_task_categories "$project")
                    if [ -n "$categories" ]; then
                        echo -e "  Issues: $categories"
                    fi

                    if [ "$pending" -gt 0 ]; then
                        echo -e "  ${GREEN}Mode: EAGER (executing immediately)${RESET}"
                    else
                        echo -e "  Mode: Monitoring"
                    fi

                    echo
                fi
            fi
        done
    fi

    if [ "$active_projects" -eq 0 ]; then
        echo -e "${CYAN}No projects with task queues found${RESET}"
    fi

    echo "────────────────────────────────────────"
    echo -e "${BOLD}Global Summary:${RESET}"
    echo -e "  ${BLUE}📋 Projects: $active_projects${RESET}"
    echo -e "  ${YELLOW}⚡ In Progress: $total_in_progress${RESET}"
    echo -e "  ${CYAN}○ Pending: $total_pending${RESET}"
    echo -e "  ${GREEN}✓ Completed: $total_completed${RESET}"
    echo

    if [ "$total_pending" -gt 0 ]; then
        echo -e "  ${GREEN}${BOLD}🚀 EAGER MODE ACTIVE${RESET}"
    else
        echo -e "  ${CYAN}📊 Monitoring Mode${RESET}"
    fi

    echo
    echo -e "${CYAN}Live Update: $(date '+%H:%M:%S')${RESET}"

    sleep 10
done
