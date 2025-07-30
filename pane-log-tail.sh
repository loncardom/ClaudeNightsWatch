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
