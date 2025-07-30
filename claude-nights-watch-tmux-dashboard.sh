#!/bin/bash

# Claude Nights Watch Tmux Dashboard - 4-Pane Dynamic Monitoring Interface
# Automatically starts/stops with daemon management

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSION_NAME="claude-nights-watch"
DASHBOARD_PID_FILE="$BASE_DIR/logs/dashboard.pid"

# Ensure logs directory exists
mkdir -p "$BASE_DIR/logs"

# Colors
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

# ASCII Art for pane 4
ASCII_ART='..............................,,,,,,,,,******************,,,,,,,,,,,,,,,.....,,,
................................................................................
................................................................................
................................................................................
.....,*&&@@@/***,,,,,,,,,,,,,,,.................................................
,,,,,,,/&@@@*,**,,,,,,,******///*************,,,,,,,,,,,,............,..........
,,,,,,,,/&@@/**//******//////////*********,,*,,,,,,,/,,,..........*%,.,...******
.......,,(&@//*//****///(((/////////*********,,,,,*/#,*.....................**//
,,......,,&%#*******(((((((***,,*,*////*/***,,,,,,,(#,,,*,,............,/%(/////
****,....%#*(#(///*((##((///*/*,,,,/(((//**,,,,,****#,*,../.........../%&&&%((((
/*****,.##(((%###//(####((/(/*/****/#((/**,,/,,**,**#/*/..,*........./%&&&&&%((/
*******,#(/(#///##(#########(((///(#(((/***********/#/,/..,/........../%&&&&#,..
******,(((/*##%#/%/##%%%%####((((#%###%#/(*/////////#//*..,*...........,(%&%@@&/
**,,,,,(((*//*(%%##(%##%%%########%%##%#(//////////(#*....,*..............*/(/**
,.,,.,#((////,*,.*%%%%%%%%%%%%####%%%%%%###/((((/(((#.....,*,............,,,*,..
.....##((///*/,,,.&%&&&&&&%%%%%##%%%%##(/*///(((/((#*......,,...........,,,,,,,,
....*((////*,*....&&&&&&&&&%%%%%######((((/////((((/.,.....,,......,,,,,,,,,,,,*
....((///*/,,.....(@@&&@@&&&%%%#(##/////*****//(((/....,...,,,,,,,,,,,,,,,,,,,,*
...,(///,.,,,.....*%%%%@@@@&&%%%%%%%##((/((/(((((/......,*##*,,*****************
****/*,,,,,,,,.....#%%%%#@@@%%%%#%###((((/((((//*.........,(#/%(%#/////////////*
***,,%*.,,,,,......*(%%%%%###%#%%%%%%%%##((((//*............*(/(((%%%#//////////
(**,,,,,&/.,,.....,.*/##%%####((%%%%%##(#((///*...............*######%%(/(/(((#/
(((,,,***@&,.,,....,,*//((#######(///*//***//*,.................,(##(/((/(((#(#*
%%%**((((/#@@*,,,.,,,,*/((((((((((((((//////*,,,,,.......,*,,,,,,,,*///##%%###((
&&&%(####/&%&@&%.,.,,,.*/(((((((((((((((((,.,**,,,.......,.,*,*,*,,**%@(//*/&%/*
&&&&&&&%/##&%%&@@&*..,,,,//((((((((((((*,*,,*,...*,.......,///#@(*#&@@%//((&&&//
&&%&&&&(#%#&@@&&@&@%,..,..*//((((((((*...........*...*((%&###%&/**//*/(**(/*#*/*
&&@&&&%%%%%&&&@&&&&@%#.....,/((///(*...,..........*/%/.*%&%%%&(/****///***/*/**,
&&&@&&%%%&&&@@@&&&&@&@%.,....,///*.,,.,,,,,,..,.//#(#*##%&%%&@@##(/.#(/***%#((**
&@&&&&&%%&&&&@&@&&@&@&@#.,,..,/**..,,,,,,,,,...(%#(###&&(****&#****./***,,,,*..,
@@@&&%&&%&%&@@&&@@&@@&@@%,(*,,*,...,,,,,,,...//%((((/////////*#**,,,.,,,.,......
@@&&&@&&&%%&@&@&&&@@@@@&@%.*.,*,.....,.,..../%%#(((/(((//**,,..,*/,,...,........
@@@&@&&@&&&@@@&@&&%%%%&&&&#,.,,,,,,,,,,,..,####((((//*,,...,*,,................,
@&@&@@%&&@@@@@@@&&@@&&&&&%&#.,,,,.,,,,,,#%##(///**,,../&&&#/(/*,,,*#%(*&%%&**...
@@&%%&(##&&&@@@@@&&&&&@&%%&&#..,*,,,///*,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
@@@@%%&%%&&&&&&&&&@@@@@&&&%%&(.../(((//****,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
@@@&%%&%%&&&&&&&&&@@@@@&&&%%&(.../(((//****,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,'

# Function to check if tmux session exists
session_exists() {
    tmux has-session -t "$SESSION_NAME" 2>/dev/null
}

# Function to kill existing session
kill_session() {
    if session_exists; then
        echo -e "${YELLOW}Stopping existing tmux dashboard session...${RESET}"
        tmux kill-session -t "$SESSION_NAME" 2>/dev/null
        sleep 1
    fi
}

# Function to create daemon status pane script
create_daemon_status_pane() {
    cat > "$BASE_DIR/pane-daemon-status.sh" << 'EOF'
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
EOF
    chmod +x "$BASE_DIR/pane-daemon-status.sh"
}

# Function to create consolidated log tailing pane script
create_log_tail_pane() {
    cat > "$BASE_DIR/pane-log-tail.sh" << 'EOF'
#!/bin/bash
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BOLD='\033[1m'
RESET='\033[0m'

clear
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}║        CONSOLIDATED LOGS             ║${RESET}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${RESET}"
echo

# Find all log files and tail them
if [ -d "$BASE_DIR/logs" ]; then
    find "$BASE_DIR/logs" -name "claude-nights-watch-daemon.log" -type f | while read logfile; do
        project=$(basename "$(dirname "$logfile")")
        echo -e "${GREEN}=== $project ===${RESET}"
    done

    # Use multitail if available, otherwise tail -f
    if command -v multitail >/dev/null 2>&1; then
        log_files=($(find "$BASE_DIR/logs" -name "claude-nights-watch-daemon.log" -type f))
        if [ ${#log_files[@]} -gt 0 ]; then
            multitail "${log_files[@]}"
        else
            echo -e "${YELLOW}No log files found${RESET}"
            sleep infinity
        fi
    else
        # Fallback to regular tail
        log_files=($(find "$BASE_DIR/logs" -name "claude-nights-watch-daemon.log" -type f))
        if [ ${#log_files[@]} -gt 0 ]; then
            tail -f "${log_files[@]}"
        else
            echo -e "${YELLOW}No log files found. Waiting for daemon activity...${RESET}"
            while true; do
                sleep 5
                log_files=($(find "$BASE_DIR/logs" -name "claude-nights-watch-daemon.log" -type f))
                if [ ${#log_files[@]} -gt 0 ]; then
                    exec tail -f "${log_files[@]}"
                fi
            done
        fi
    fi
else
    echo -e "${YELLOW}Logs directory not found${RESET}"
    sleep infinity
fi
EOF
    chmod +x "$BASE_DIR/pane-log-tail.sh"
}

# Function to create audit manager pane script
create_audit_manager_pane() {
    cat > "$BASE_DIR/pane-audit-manager.sh" << 'EOF'
#!/bin/bash
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
RESET='\033[0m'

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

while true; do
    clear
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║          AUDIT MANAGER               ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${RESET}"
    echo

    current_time=$(date '+%H:%M:%S')
    audit_info=$(get_audit_manager_info)
    audit_status=$(echo "$audit_info" | cut -d'|' -f1)
    audit_pid=$(echo "$audit_info" | cut -d'|' -f2)
    audit_last_activity=$(echo "$audit_info" | cut -d'|' -f3)
    audits_today=$(echo "$audit_info" | cut -d'|' -f4)
    total_audits=$(echo "$audit_info" | cut -d'|' -f5)

    if [ "$audit_status" = "RUNNING" ]; then
        echo -e "${GREEN}● Audit Manager: Running${RESET}"
        echo -e "${GREEN}● PID: $audit_pid${RESET}"
        echo -e "${GREEN}● Audits Today: $audits_today${RESET}"
        echo -e "${GREEN}● Total Audits: $total_audits${RESET}"

        if [ "$audit_last_activity" != "Unknown" ]; then
            echo -e "${GREEN}● Last Activity: $audit_last_activity${RESET}"
        fi

        echo
        echo -e "${CYAN}Quality Assurance Status:${RESET}"
        echo "────────────────────────────────────────"
        echo -e "${GREEN}● Heartbeat: Active (5min cycles)${RESET}"
        echo -e "${GREEN}● Task Oversight: Enabled${RESET}"
        echo -e "${GREEN}● Audit Results: /audit-results/${RESET}"

        # Show recent audit activity if available
        if [ -f "$BASE_DIR/logs/audit-manager.log" ]; then
            echo
            echo -e "${CYAN}Recent Activity:${RESET}"
            echo "────────────────────────────────────────"
            tail -3 "$BASE_DIR/logs/audit-manager.log" 2>/dev/null | while read line; do
                echo -e "${YELLOW}$line${RESET}"
            done
        fi

    else
        echo -e "${RED}● Audit Manager: Stopped${RESET}"
        echo -e "${RED}● Quality Assurance: Disabled${RESET}"
        echo -e "${YELLOW}● Task Oversight: No audit coverage${RESET}"
        echo
        echo -e "${CYAN}Status: ${RED}No quality assurance active${RESET}"
    fi

    echo
    echo -e "${CYAN}Updated: $current_time${RESET}"

    sleep 5
done
EOF
    chmod +x "$BASE_DIR/pane-audit-manager.sh"
}

# Function to create keep-alive observer pane script
create_keepalive_pane() {
    cat > "$BASE_DIR/pane-keepalive.sh" << 'EOF'
#!/bin/bash
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
RESET='\033[0m'

ping_count=0
last_ping_time=""

ping_claude() {
    # Simple keep-alive by checking Claude CLI availability
    if command -v claude >/dev/null 2>&1; then
        if timeout 10 claude --version >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

while true; do
    clear
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║        KEEP-ALIVE OBSERVER           ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${RESET}"
    echo

    current_time=$(date '+%H:%M:%S')

    if ping_claude; then
        ping_count=$((ping_count + 1))
        last_ping_time="$current_time"
        echo -e "${GREEN}● Claude CLI: Available${RESET}"
        echo -e "${GREEN}● Ping Count: $ping_count${RESET}"
        echo -e "${GREEN}● Last Successful Ping: $last_ping_time${RESET}"
    else
        echo -e "${RED}● Claude CLI: Unavailable${RESET}"
        echo -e "${YELLOW}● Ping Count: $ping_count${RESET}"
        echo -e "${YELLOW}● Last Successful Ping: ${last_ping_time:-Never}${RESET}"
    fi

    echo
    echo -e "${CYAN}Keep-alive Status:${RESET}"
    echo "────────────────────────────────────────"

    # Check daemon processes
    active_daemons=0
    if [ -d "$BASE_DIR/logs" ]; then
        for pid_file in "$BASE_DIR/logs"/*/claude-nights-watch-daemon.pid; do
            if [ -f "$pid_file" ]; then
                pid=$(cat "$pid_file" 2>/dev/null)
                if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                    active_daemons=$((active_daemons + 1))
                fi
            fi
        done
    fi

    if [ "$active_daemons" -gt 0 ]; then
        echo -e "${GREEN}● Daemons Active: $active_daemons${RESET}"
        echo -e "${GREEN}● System Status: Healthy${RESET}"
    else
        echo -e "${YELLOW}● Daemons Active: 0${RESET}"
        echo -e "${YELLOW}● System Status: Standby${RESET}"
    fi

    echo
    echo -e "${CYAN}Next ping in 30 seconds...${RESET}"

    sleep 30
done
EOF
    chmod +x "$BASE_DIR/pane-keepalive.sh"
}

# Function to create ASCII art pane script
create_ascii_pane() {
    cat > "$BASE_DIR/pane-ascii.sh" << EOF
#!/bin/bash

# Colors
GREEN='\033[1;32m'
CYAN='\033[1;36m'
BOLD='\033[1m'
RESET='\033[0m'

clear
echo -e "\${CYAN}\${BOLD}╔══════════════════════════════════════╗\${RESET}"
echo -e "\${CYAN}\${BOLD}║            CLAUDE VISION             ║\${RESET}"
echo -e "\${CYAN}\${BOLD}╚══════════════════════════════════════╝\${RESET}"
echo

# Display ASCII art with green color
echo -e "\${GREEN}"
cat << 'ASCIIART'
$ASCII_ART
ASCIIART
echo -e "\${RESET}"

echo
echo -e "\${CYAN}Claude Nights Watch - Autonomous Task Execution\${RESET}"
echo -e "\${CYAN}Monitoring active across all configured projects\${RESET}"

# Keep the pane alive
sleep infinity
EOF
    chmod +x "$BASE_DIR/pane-ascii.sh"
}

# Function to get a list of active daemon project names
get_active_daemons() {
    local active_daemons=()
    if [ -d "$BASE_DIR/projects" ]; then
        for project_dir in "$BASE_DIR/projects"/*; do
            if [ -d "$project_dir" ]; then
                local project=$(basename "$project_dir")
                local pid_file="$BASE_DIR/logs/$project/claude-nights-watch-daemon.pid"
                if [ -f "$pid_file" ]; then
                    local pid=$(cat "$pid_file" 2>/dev/null)
                    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                        active_daemons+=("$project")
                    fi
                fi
            fi
        done
    fi
    echo "${active_daemons[@]}"
}

# Function to start tmux dashboard
start_dashboard() {
    echo -e "${GREEN}Starting Claude Nights Watch Tmux Dashboard...${RESET}"

    kill_session

    echo "Creating pane scripts..."
    create_daemon_status_pane
    create_log_tail_pane
    create_audit_manager_pane
    create_keepalive_pane
    create_ascii_pane

    # Auto-start audit manager when tmux dashboard starts
    echo "Starting audit manager for quality assurance..."
    local audit_pid_file="$BASE_DIR/logs/audit-manager.pid"
    if [ ! -f "$audit_pid_file" ] || ! kill -0 "$(cat "$audit_pid_file" 2>/dev/null)" 2>/dev/null; then
        nohup "$BASE_DIR/claude-nights-watch-audit-manager.sh" daemon > /dev/null 2>&1 &
        sleep 1
    fi

    # Get active daemons
    local active_daemons_str
    active_daemons_str=$(get_active_daemons)
    read -ra active_daemons <<< "$active_daemons_str"
    local num_active_daemons=${#active_daemons[@]}

    echo "Creating tmux session..."
    tmux new-session -d -s "$SESSION_NAME" -x 140 -y 60

    # --- Layout (5 Panes) ---

    # Split main window horizontally: top (60%) and bottom (40%)
    tmux split-window -v -p 40 # Panes: 0.0 (top), 0.1 (bottom)

    # --- Top Row (3 Panes) ---
    # Split the top pane into a left (33%) and a right (67%) section
    tmux split-window -h -t "$SESSION_NAME:0.0" -p 67 # Panes: 0.0 (left), 0.2 (right)
    # Split the new right section in half for the middle and right panes
    tmux split-window -h -t "$SESSION_NAME:0.2" -p 50 # Panes: 0.2 (middle), 0.3 (right)

    # --- Bottom Row (3 Panes) ---
    tmux split-window -h -t "$SESSION_NAME:0.1" -p 67 # Panes: 0.1 (left), 0.4 (right)
    # Split the right bottom section for audit manager and keep-alive
    tmux split-window -h -t "$SESSION_NAME:0.4" -p 50 # Panes: 0.4 (audit), 0.5 (keep-alive)

    # --- Pane Content ---
    # Top Row
    tmux send-keys -t "$SESSION_NAME:0.0" "$BASE_DIR/pane-ascii.sh" Enter
    tmux select-pane -t "$SESSION_NAME:0.0" -T "Claude Vision"

    tmux send-keys -t "$SESSION_NAME:0.2" "$BASE_DIR/pane-combined-status.sh" Enter
    tmux select-pane -t "$SESSION_NAME:0.2" -T "System Status"

    # Bottom Row
    tmux send-keys -t "$SESSION_NAME:0.1" "$BASE_DIR/pane-log-tail.sh" Enter
    tmux select-pane -t "$SESSION_NAME:0.1" -T "Execution Logs"

    tmux send-keys -t "$SESSION_NAME:0.4" "$BASE_DIR/pane-audit-manager.sh" Enter
    tmux select-pane -t "$SESSION_NAME:0.4" -T "Audit Manager"

    tmux send-keys -t "$SESSION_NAME:0.5" "$BASE_DIR/pane-keepalive.sh" Enter
    tmux select-pane -t "$SESSION_NAME:0.5" -T "Keep-Alive Observer"

    # --- Dynamic Task Panes (Top Right) ---
    if [ "$num_active_daemons" -eq 0 ]; then
        # No active daemons, display a status message in the tasks pane
        tmux send-keys -t "$SESSION_NAME:0.3" "while true; do clear; tput cup 5; echo 'No active daemons...'; sleep 5; done" Enter
        tmux select-pane -t "$SESSION_NAME:0.3" -T "No Active Projects"
    else
        # Active daemons exist, create a tiled layout for them
        local task_pane_target="$SESSION_NAME:0.3"
        tmux select-pane -t "$task_pane_target"

        # Create a pane for each active daemon
        tmux send-keys -t "$task_pane_target" "$BASE_DIR/pane-dynamic-tasks.sh 1" Enter
        tmux select-pane -t "$task_pane_target" -T "Tasks: ${active_daemons[0]}"

        for (( i=1; i < num_active_daemons; i++ )); do
            tmux split-window -h -t "$task_pane_target"
            local new_pane_id=$(tmux display-message -p '#{pane_id}')
            tmux send-keys -t "$new_pane_id" "$BASE_DIR/pane-dynamic-tasks.sh $((i+1))" Enter
            tmux select-pane -t "$new_pane_id" -T "Tasks: ${active_daemons[$i]}"
        done

        tmux select-layout -t "$task_pane_target" tiled
    fi

    # --- Finalization ---
    # Save dashboard PID
    echo $ > "$DASHBOARD_PID_FILE"

    echo -e "${GREEN}Dashboard started! Attaching to tmux session...${RESET}"
    echo -e "${CYAN}Use Ctrl+B then D to detach, or Ctrl+C to stop dashboard${RESET}"

    # Attach to session
    tmux attach-session -t "$SESSION_NAME"
}

# Function to stop dashboard
stop_dashboard() {
    echo -e "${YELLOW}Stopping Claude Nights Watch Dashboard...${RESET}"
    kill_session

    # Stop audit manager when dashboard stops (if no daemons are running)
    active_daemons=0
    if [ -d "$BASE_DIR/logs" ]; then
        for pid_file in "$BASE_DIR/logs"/*/claude-nights-watch-daemon.pid; do
            if [ -f "$pid_file" ]; then
                pid=$(cat "$pid_file" 2>/dev/null)
                if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                    active_daemons=$((active_daemons + 1))
                fi
            fi
        done
    fi

    if [ "$active_daemons" -eq 0 ]; then
        local audit_pid_file="$BASE_DIR/logs/audit-manager.pid"
        if [ -f "$audit_pid_file" ]; then
            local audit_pid=$(cat "$audit_pid_file" 2>/dev/null)
            if [ -n "$audit_pid" ] && kill -0 "$audit_pid" 2>/dev/null; then
                echo -e "${YELLOW}No active daemons, stopping audit manager...${RESET}"
                "$BASE_DIR/claude-nights-watch-audit-manager.sh" stop >/dev/null 2>&1
            fi
        fi
    fi

    # Clean up temporary pane scripts (keep permanent ones)
    # Note: pane-dynamic-tasks.sh, pane-live-queue.sh, and other enhanced scripts are permanent files
    rm -f "$BASE_DIR/pane-log-tail.sh.tmp"
    rm -f "$BASE_DIR/pane-keepalive.sh.tmp"
    rm -f "$BASE_DIR/pane-ascii.sh.tmp"
    rm -f "$DASHBOARD_PID_FILE"

    echo -e "${GREEN}Dashboard stopped.${RESET}"
}

# Signal handler
cleanup() {
    stop_dashboard
    exit 0
}

trap cleanup SIGTERM SIGINT

# Main command handling
case "$1" in
    start)
        start_dashboard
        ;;
    stop)
        stop_dashboard
        ;;
    status)
        if session_exists; then
            echo -e "${GREEN}Dashboard is running (tmux session: $SESSION_NAME)${RESET}"
            tmux list-sessions | grep "$SESSION_NAME"
        else
            echo -e "${RED}Dashboard is not running${RESET}"
        fi
        ;;
    attach)
        if session_exists; then
            echo -e "${GREEN}Attaching to dashboard...${RESET}"
            tmux attach-session -t "$SESSION_NAME"
        else
            echo -e "${RED}Dashboard is not running${RESET}"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|status|attach}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the 5-pane tmux dashboard with audit manager"
        echo "  stop    - Stop the dashboard and clean up"
        echo "  status  - Check if dashboard is running"
        echo "  attach  - Attach to existing dashboard session"
        exit 1
        ;;
esac
