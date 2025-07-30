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
