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
