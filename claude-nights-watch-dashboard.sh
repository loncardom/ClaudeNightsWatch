#!/bin/bash

# Claude Nights Watch Dashboard - Visual Monitoring Interface
# Shows running daemons with tetris-block style terminal interface

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Terminal colors and styling
export TERM=xterm-256color
GREEN='\033[1;32m'
BRIGHT_GREEN='\033[1;92m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# Box drawing characters for tetris-like blocks
BOX_TOP_LEFT='┌'
BOX_TOP_RIGHT='┐'
BOX_BOTTOM_LEFT='└'
BOX_BOTTOM_RIGHT='┘'
BOX_HORIZONTAL='─'
BOX_VERTICAL='│'
BOX_CROSS='┼'
BOX_T_DOWN='┬'
BOX_T_UP='┴'
BOX_T_RIGHT='├'
BOX_T_LEFT='┤'

# Block characters for progress bars
BLOCK_FULL='█'
BLOCK_THREE_QUARTERS='▉'
BLOCK_HALF='▌'
BLOCK_QUARTER='▎'
EMPTY=' '

# Cache for ccusage command
CCUSAGE_CMD_CACHE=""
CCUSAGE_CMD_CACHED=false

# Terminal dimensions
TERM_WIDTH=80
TERM_HEIGHT=24
MIN_WIDTH=60

# Function to detect terminal dimensions
detect_terminal_size() {
    if command -v tput >/dev/null 2>&1; then
        TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
        TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)
    else
        # Fallback using stty if available
        if command -v stty >/dev/null 2>&1; then
            local size=$(stty size 2>/dev/null)
            if [ -n "$size" ]; then
                TERM_HEIGHT=${size% *}
                TERM_WIDTH=${size#* }
            fi
        fi
    fi

    # Ensure minimum width
    if [ "$TERM_WIDTH" -lt "$MIN_WIDTH" ]; then
        TERM_WIDTH=$MIN_WIDTH
    fi
}

# Function to get responsive width
get_display_width() {
    echo $((TERM_WIDTH - 4))  # Leave margin for borders
}

# Function to get ccusage command with caching
get_ccusage_cmd() {
    if [ "$CCUSAGE_CMD_CACHED" = true ]; then
        if [ -n "$CCUSAGE_CMD_CACHE" ]; then
            echo "$CCUSAGE_CMD_CACHE"
            return 0
        else
            return 1
        fi
    fi

    if command -v ccusage &> /dev/null; then
        CCUSAGE_CMD_CACHE="ccusage"
    elif command -v bunx &> /dev/null; then
        CCUSAGE_CMD_CACHE="bunx ccusage"
    elif command -v npx &> /dev/null; then
        CCUSAGE_CMD_CACHE="npx ccusage@latest"
    else
        CCUSAGE_CMD_CACHE=""
    fi

    CCUSAGE_CMD_CACHED=true

    if [ -n "$CCUSAGE_CMD_CACHE" ]; then
        echo "$CCUSAGE_CMD_CACHE"
        return 0
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
    elif end_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$end_time" +%s 2>/dev/null); then
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

# Function to create progress bar
create_progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-40}
    local color=${4:-$GREEN}

    if [ "$total" -eq 0 ]; then
        total=1
    fi

    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    local bar=""
    for i in $(seq 1 $filled); do
        bar="${bar}${BLOCK_FULL}"
    done
    for i in $(seq 1 $empty); do
        bar="${bar}${EMPTY}"
    done

    printf "${color}[%s]${RESET} %3d%%" "$bar" "$percentage"
}

# Function to create time display
format_time_remaining() {
    local minutes=$1

    if [ -z "$minutes" ] || [ "$minutes" -eq 0 ]; then
        echo "${RED}●${RESET} ${DIM}No active window${RESET}"
        return
    fi

    local hours=$((minutes / 60))
    local mins=$((minutes % 60))

    local color=$GREEN
    if [ "$minutes" -lt 30 ]; then
        color=$YELLOW
    fi
    if [ "$minutes" -lt 10 ]; then
        color=$RED
    fi

    printf "${color}●${RESET} %02d:%02d remaining" "$hours" "$mins"
}

# Function to get task queue info
get_task_queue_info() {
    local project=$1
    local queue_file="$BASE_DIR/projects/$project/task-queue.json"

    if [ ! -f "$queue_file" ]; then
        echo "NO_QUEUE|0|0|0|0|0"
        return
    fi

    # Parse task queue JSON using basic text processing
    local total_tasks=$(grep -o '"total_tasks": *[0-9]*' "$queue_file" 2>/dev/null | grep -o '[0-9]*' || echo "0")
    local pending_tasks=$(grep -o '"pending_tasks": *[0-9]*' "$queue_file" 2>/dev/null | grep -o '[0-9]*' || echo "0")
    local in_progress_tasks=$(grep -o '"in_progress_tasks": *[0-9]*' "$queue_file" 2>/dev/null | grep -o '[0-9]*' || echo "0")
    local completed_tasks=$(grep -o '"completed_tasks": *[0-9]*' "$queue_file" 2>/dev/null | grep -o '[0-9]*' || echo "0")
    local failed_tasks=$(grep -o '"failed_tasks": *[0-9]*' "$queue_file" 2>/dev/null | grep -o '[0-9]*' || echo "0")

    # Count issues by category (simple text parsing)
    local bugs=$(grep -c '"title": *"Fix [0-9]* bugs issues' "$queue_file" 2>/dev/null || echo "0")
    local security=$(grep -c '"title": *"Fix [0-9]* security issues' "$queue_file" 2>/dev/null || echo "0")
    local style=$(grep -c '"title": *"Fix [0-9]* style issues' "$queue_file" 2>/dev/null || echo "0")
    local complexity=$(grep -c '"title": *"Fix [0-9]* complexity issues' "$queue_file" 2>/dev/null || echo "0")
    local type_issues=$(grep -c '"title": *"Fix [0-9]* type_issues issues' "$queue_file" 2>/dev/null || echo "0")

    echo "QUEUE_EXISTS|$total_tasks|$pending_tasks|$in_progress_tasks|$completed_tasks|$failed_tasks|$bugs|$security|$style|$complexity|$type_issues"
}

# Function to get daemon info
get_daemon_info() {
    local project=$1
    local log_dir="$BASE_DIR/logs/$project"
    local pid_file="$log_dir/claude-nights-watch-daemon.pid"
    local log_file="$log_dir/claude-nights-watch-daemon.log"

    if [ ! -f "$pid_file" ]; then
        echo "STOPPED|0|No PID file"
        return
    fi

    local pid=$(cat "$pid_file" 2>/dev/null)
    if [ -z "$pid" ]; then
        echo "STOPPED|0|Invalid PID"
        return
    fi

    if ! kill -0 "$pid" 2>/dev/null; then
        echo "STOPPED|0|Process not running"
        return
    fi

    # Get last log entry timestamp
    local last_activity="Unknown"
    if [ -f "$log_file" ]; then
        last_activity=$(tail -1 "$log_file" 2>/dev/null | grep -o '\[.*\]' | head -1 | tr -d '[]' || echo "Unknown")
    fi

    echo "RUNNING|$pid|$last_activity"
}

# Function to get audit manager info
get_audit_manager_info() {
    local audit_pid_file="$BASE_DIR/logs/audit-manager.pid"
    local audit_log_file="$BASE_DIR/logs/audit-manager.log"

    if [ ! -f "$audit_pid_file" ]; then
        echo "STOPPED|0|No audit manager running|0|0"
        return
    fi

    local pid=$(cat "$audit_pid_file" 2>/dev/null)
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        echo "STOPPED|0|Audit manager not running|0|0"
        return
    fi

    # Get last activity and audit counts
    local last_activity="Unknown"
    local audits_today=0
    local total_audits=0

    if [ -f "$audit_log_file" ]; then
        last_activity=$(tail -1 "$audit_log_file" 2>/dev/null | grep -o '\[.*\]' | head -1 | tr -d '[]' || echo "Unknown")

        # Count audits completed today
        local today=$(date '+%Y-%m-%d')
        audits_today=$(grep -c "Audit completed successfully" "$audit_log_file" 2>/dev/null | head -1 || echo "0")

        # Count total audits
        total_audits=$(grep -c "Starting audit for task" "$audit_log_file" 2>/dev/null | head -1 || echo "0")
    fi

    echo "RUNNING|$pid|$last_activity|$audits_today|$total_audits"
}

# Function to clear screen and reset cursor
clear_screen() {
    printf '\033[2J\033[H'
}

# Function to draw header
draw_header() {
    local width=$(get_display_width)
    local title="CLAUDE NIGHTS WATCH DASHBOARD"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # Calculate padding for centered title
    local title_len=${#title}
    local timestamp_len=${#timestamp}
    local title_padding=$(((width - title_len - 2) / 2))
    local timestamp_padding=$(((width - timestamp_len - 2) / 2))

    echo -e "${BRIGHT_GREEN}${BOX_TOP_LEFT}$(printf "%*s" $((width-2)) | tr ' ' "$BOX_HORIZONTAL")${BOX_TOP_RIGHT}${RESET}"

    # Title line with proper centering
    printf "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
    printf "%*s" $title_padding
    printf "${CYAN}${BOLD}%s${RESET}" "$title"
    printf "%*s" $((width - title_len - title_padding - 2))
    printf "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}\n"

    # Timestamp line with proper centering
    printf "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
    printf "%*s" $timestamp_padding
    printf "${DIM}%s${RESET}" "$timestamp"
    printf "%*s" $((width - timestamp_len - timestamp_padding - 2))
    printf "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}\n"

    echo -e "${BRIGHT_GREEN}${BOX_T_RIGHT}$(printf "%*s" $((width-2)) | tr ' ' "$BOX_HORIZONTAL")${BOX_T_LEFT}${RESET}"
}

# Function to draw usage window status
draw_usage_status() {
    local width=$(get_display_width)
    local minutes_remaining=$(get_minutes_until_reset)

    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET} ${BOLD}CLAUDE USAGE WINDOW${RESET}$(printf "%*s" $((width-23)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}$(printf "%*s" $((width-2)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"

    local status_line
    if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ]; then
        local used_time=$((300 - minutes_remaining))  # 5 hours = 300 minutes
        status_line="  $(format_time_remaining "$minutes_remaining")  |  $(create_progress_bar "$used_time" 300 30)"
    else
        status_line="  ${RED}●${RESET} ${DIM}Checking usage status...${RESET}"
    fi

    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}${status_line}$(printf "%*s" $((width - 2 - ${#status_line} + 30)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
    echo -e "${BRIGHT_GREEN}${BOX_T_RIGHT}$(printf "%*s" $((width-2)) | tr ' ' "$BOX_HORIZONTAL")${BOX_T_LEFT}${RESET}"
}

# Function to draw task queue status
draw_task_queue_status() {
    local width=$(get_display_width)

    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET} ${BOLD}TASK QUEUE STATUS${RESET}$(printf "%*s" $((width-21)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}$(printf "%*s" $((width-2)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"

    local projects_dir="$BASE_DIR/projects"
    local total_pending=0
    local has_queues=false

    if [ -d "$projects_dir" ]; then
        for project_dir in "$projects_dir"/*; do
            if [ -d "$project_dir" ]; then
                local project=$(basename "$project_dir")
                local queue_info=$(get_task_queue_info "$project")

                if [ "$(echo "$queue_info" | cut -d'|' -f1)" = "QUEUE_EXISTS" ]; then
                    has_queues=true
                    local total_tasks=$(echo "$queue_info" | cut -d'|' -f2)
                    local pending_tasks=$(echo "$queue_info" | cut -d'|' -f3)
                    local in_progress_tasks=$(echo "$queue_info" | cut -d'|' -f4)
                    local completed_tasks=$(echo "$queue_info" | cut -d'|' -f5)
                    local failed_tasks=$(echo "$queue_info" | cut -d'|' -f6)
                    local bugs=$(echo "$queue_info" | cut -d'|' -f7)
                    local security=$(echo "$queue_info" | cut -d'|' -f8)
                    local style=$(echo "$queue_info" | cut -d'|' -f9)
                    local complexity=$(echo "$queue_info" | cut -d'|' -f10)
                    local type_issues=$(echo "$queue_info" | cut -d'|' -f11)

                    total_pending=$((total_pending + pending_tasks))

                    # Project header
                    local queue_icon="${CYAN}◉${RESET}"
                    if [ "$pending_tasks" -gt 0 ]; then
                        queue_icon="${YELLOW}◉${RESET}"
                    fi
                    if [ "$in_progress_tasks" -gt 0 ]; then
                        queue_icon="${GREEN}◉${RESET}"
                    fi

                    local project_line="  $queue_icon ${BOLD}$project${RESET} - ${total_tasks} tasks"
                    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}${project_line}$(printf "%*s" $((width - 2 - ${#project_line} + 20)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"

                    # Task status breakdown
                    local status_line="    ${GREEN}✓${RESET}${completed_tasks} ${YELLOW}⚡${RESET}${in_progress_tasks} ${BLUE}○${RESET}${pending_tasks}"
                    if [ "$failed_tasks" -gt 0 ]; then
                        status_line="$status_line ${RED}✗${RESET}${failed_tasks}"
                    fi
                    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}${status_line}$(printf "%*s" $((width - 2 - ${#status_line} + 30)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"

                    # Categories breakdown if there are any issues
                    local total_issues=$((bugs + security + style + complexity + type_issues))
                    if [ "$total_issues" -gt 0 ]; then
                        local categories=""
                        [ "$bugs" -gt 0 ] && categories="${categories}bugs(${bugs}) "
                        [ "$security" -gt 0 ] && categories="${categories}${RED}security(${security})${RESET} "
                        [ "$style" -gt 0 ] && categories="${categories}style(${style}) "
                        [ "$complexity" -gt 0 ] && categories="${categories}complexity(${complexity}) "
                        [ "$type_issues" -gt 0 ] && categories="${categories}types(${type_issues}) "

                        local category_line="    ${DIM}Categories: ${categories}${RESET}"
                        echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}${category_line}$(printf "%*s" $((width - 2 - ${#category_line} + 30)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
                    fi

                    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}$(printf "%*s" $((width-2)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
                fi
            fi
        done
    fi

    if [ "$has_queues" = false ]; then
        echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}  ${DIM}No task queues found${RESET}$(printf "%*s" $((width-26)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
        echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}$(printf "%*s" $((width-2)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
    fi

    echo -e "${BRIGHT_GREEN}${BOX_T_RIGHT}$(printf "%*s" $((width-2)) | tr ' ' "$BOX_HORIZONTAL")${BOX_T_LEFT}${RESET}"
}

# Function to draw daemon status
draw_daemon_status() {
    local width=$(get_display_width)

    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET} ${BOLD}ACTIVE DAEMONS${RESET}$(printf "%*s" $((width-18)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}$(printf "%*s" $((width-2)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"

    local daemon_count=0
    local projects_dir="$BASE_DIR/projects"
    local minutes_remaining=$(get_minutes_until_reset)

    if [ -d "$projects_dir" ]; then
        for project_dir in "$projects_dir"/*; do
            if [ -d "$project_dir" ]; then
                local project=$(basename "$project_dir")
                local daemon_info=$(get_daemon_info "$project")
                local status=$(echo "$daemon_info" | cut -d'|' -f1)
                local pid=$(echo "$daemon_info" | cut -d'|' -f2)
                local last_activity=$(echo "$daemon_info" | cut -d'|' -f3)

                local status_icon
                local status_color
                case "$status" in
                    "RUNNING")
                        status_icon="${GREEN}●${RESET}"
                        status_color=$GREEN
                        daemon_count=$((daemon_count + 1))
                        ;;
                    *)
                        status_icon="${RED}●${RESET}"
                        status_color=$RED
                        ;;
                esac

                local project_line="  $status_icon ${BOLD}$project${RESET}"
                local pid_info=""
                if [ "$pid" != "0" ]; then
                    pid_info=" ${DIM}(PID: $pid)${RESET}"
                fi

                local full_line="$project_line$pid_info"
                echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}${full_line}$(printf "%*s" $((width - 2 - ${#project_line} - ${#pid_info} + 20)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"

                # Show execution status
                if [ "$status" = "RUNNING" ]; then
                    local exec_status="    ${DIM}Status: "
                    if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ]; then
                        if [ "$minutes_remaining" -le 2 ]; then
                            exec_status="${exec_status}${GREEN}Executing tasks${RESET}"
                        else
                            exec_status="${exec_status}Monitoring (${minutes_remaining} min remaining)${RESET}"
                        fi
                    else
                        exec_status="${exec_status}Checking usage status${RESET}"
                    fi
                    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}${exec_status}$(printf "%*s" $((width - 2 - ${#exec_status} + 30)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"

                    # Show last activity on next line
                    if [ "$last_activity" != "Unknown" ]; then
                        local activity_line="    ${DIM}Last: $last_activity${RESET}"
                        echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}${activity_line}$(printf "%*s" $((width - 2 - ${#activity_line} + 10)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
                    fi
                fi
            fi
        done
    fi

    if [ "$daemon_count" -eq 0 ]; then
        echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}  ${DIM}No active daemons${RESET}$(printf "%*s" $((width-21)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
    fi

    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}$(printf "%*s" $((width-2)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET} ${BOLD}TOTAL ACTIVE: ${daemon_count}${RESET}$(printf "%*s" $((width-20)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
}

# Function to draw audit manager status
draw_audit_status() {
    local width=$(get_display_width)

    echo -e "${BRIGHT_GREEN}${BOX_T_RIGHT}$(printf "%*s" $((width-2)) | tr ' ' "$BOX_HORIZONTAL")${BOX_T_LEFT}${RESET}"
    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET} ${BOLD}AUDIT MANAGER${RESET}$(printf "%*s" $((width-17)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}$(printf "%*s" $((width-2)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"

    local audit_info=$(get_audit_manager_info)
    local audit_status=$(echo "$audit_info" | cut -d'|' -f1)
    local audit_pid=$(echo "$audit_info" | cut -d'|' -f2)
    local audit_last_activity=$(echo "$audit_info" | cut -d'|' -f3)
    local audits_today=$(echo "$audit_info" | cut -d'|' -f4)
    local total_audits=$(echo "$audit_info" | cut -d'|' -f5)

    local status_icon
    case "$audit_status" in
        "RUNNING")
            status_icon="${GREEN}●${RESET}"
            ;;
        *)
            status_icon="${RED}●${RESET}"
            ;;
    esac

    local audit_line="  $status_icon ${BOLD}Audit Manager${RESET}"
    local pid_info=""
    if [ "$audit_pid" != "0" ]; then
        pid_info=" ${DIM}(PID: $audit_pid)${RESET}"
    fi

    local full_line="$audit_line$pid_info"
    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}${full_line}$(printf "%*s" $((width - 2 - ${#audit_line} - ${#pid_info} + 20)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"

    if [ "$audit_status" = "RUNNING" ]; then
        local stats_line="    ${DIM}Audits today: $audits_today | Total: $total_audits${RESET}"
        echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}${stats_line}$(printf "%*s" $((width - 2 - ${#stats_line} + 20)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"

        if [ "$audit_last_activity" != "Unknown" ]; then
            local activity_line="    ${DIM}Last: $audit_last_activity${RESET}"
            echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}${activity_line}$(printf "%*s" $((width - 2 - ${#activity_line} + 10)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
        fi

        local heartbeat_line="    ${DIM}Status: ${GREEN}Active - 5min audit cycles${RESET}"
        echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}${heartbeat_line}$(printf "%*s" $((width - 2 - ${#heartbeat_line} + 30)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
    else
        local stopped_line="    ${DIM}Status: ${RED}Not running - no quality assurance${RESET}"
        echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}${stopped_line}$(printf "%*s" $((width - 2 - ${#stopped_line} + 30)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
    fi
}

# Function to draw footer
draw_footer() {
    local width=$(get_display_width)

    echo -e "${BRIGHT_GREEN}${BOX_T_RIGHT}$(printf "%*s" $((width-2)) | tr ' ' "$BOX_HORIZONTAL")${BOX_T_LEFT}${RESET}"
    echo -e "${BRIGHT_GREEN}${BOX_VERTICAL}${RESET} ${DIM}Press Ctrl+C to exit${RESET}$(printf "%*s" $((width-23)) | tr ' ' ' ')${BRIGHT_GREEN}${BOX_VERTICAL}${RESET}"
    echo -e "${BRIGHT_GREEN}${BOX_BOTTOM_LEFT}$(printf "%*s" $((width-2)) | tr ' ' "$BOX_HORIZONTAL")${BOX_BOTTOM_RIGHT}${RESET}"
}

# Function to draw complete dashboard
draw_dashboard() {
    detect_terminal_size  # Update terminal dimensions
    clear_screen
    draw_header
    draw_usage_status
    draw_task_queue_status
    draw_daemon_status
    draw_audit_status
    draw_footer
}

# Signal handler for clean exit
cleanup() {
    clear_screen
    echo -e "${GREEN}Dashboard stopped.${RESET}"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Main dashboard loop
main() {
    echo -e "${GREEN}Starting Claude Nights Watch Dashboard...${RESET}"
    detect_terminal_size  # Initial terminal size detection

    # Auto-start audit manager when dashboard starts
    local audit_pid_file="$BASE_DIR/logs/audit-manager.pid"
    if [ ! -f "$audit_pid_file" ] || ! kill -0 "$(cat "$audit_pid_file" 2>/dev/null)" 2>/dev/null; then
        echo -e "${GREEN}Starting audit manager for quality assurance...${RESET}"
        nohup "$BASE_DIR/claude-nights-watch-audit-manager.sh" daemon > /dev/null 2>&1 &
        sleep 1
    fi

    sleep 1

    while true; do
        draw_dashboard
        sleep 5  # Update every 5 seconds
    done
}

# Start the dashboard
main
