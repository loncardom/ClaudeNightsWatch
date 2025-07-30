#!/bin/bash
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
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

while true; do
    clear
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║          DAEMON STATUS               ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${RESET}"
    echo

    # Claude usage window
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

    # Active daemons
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
    echo -e "${CYAN}Updated: $(date '+%H:%M:%S')${RESET}"

    sleep 3
done
