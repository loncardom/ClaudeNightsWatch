#!/bin/bash

# Claude Nights Watch Log Viewer

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TASK_DIR="${CLAUDE_NIGHTS_WATCH_DIR:-$(pwd)}"
LOG_DIR="$TASK_DIR/logs"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

show_menu() {
    echo -e "${BLUE}=== Claude Nights Watch Logs ===${NC}"
    echo ""
    echo "Available log files:"
    echo ""
    
    if [ -d "$LOG_DIR" ]; then
        local i=1
        for log in "$LOG_DIR"/*.log; do
            if [ -f "$log" ]; then
                local basename=$(basename "$log")
                local size=$(du -h "$log" | cut -f1)
                local lines=$(wc -l < "$log")
                echo "  $i) $basename (${size}, ${lines} lines)"
                ((i++))
            fi
        done
    else
        echo "  No logs found in $LOG_DIR"
        exit 1
    fi
    
    echo ""
    echo "Options:"
    echo "  f) Follow latest log (tail -f)"
    echo "  a) Show all logs concatenated"
    echo "  p) Show only prompts sent to Claude"
    echo "  r) Show only Claude responses"
    echo "  e) Show only errors"
    echo "  q) Quit"
    echo ""
}

view_log() {
    local log_file="$1"
    local mode="$2"
    
    case "$mode" in
        "full")
            less "$log_file"
            ;;
        "tail")
            tail -50 "$log_file"
            ;;
        "follow")
            tail -f "$log_file"
            ;;
        "prompts")
            awk '/=== PROMPT SENT TO CLAUDE ===/,/=== END OF PROMPT ===/' "$log_file" | less
            ;;
        "responses")
            awk '/=== CLAUDE RESPONSE START ===/,/=== CLAUDE RESPONSE END ===/' "$log_file" | less
            ;;
        "errors")
            grep -E "(ERROR|FAILED|Failed)" "$log_file" | less
            ;;
    esac
}

# Main loop
while true; do
    clear
    show_menu
    
    read -p "Select option: " choice
    
    case "$choice" in
        [0-9]*)
            # Numeric selection - view specific log
            log_files=("$LOG_DIR"/*.log)
            selected_log="${log_files[$((choice-1))]}"
            if [ -f "$selected_log" ]; then
                echo ""
                echo "1) View full log"
                echo "2) View last 50 lines"
                echo "3) View only prompts"
                echo "4) View only responses"
                echo "5) View only errors"
                read -p "Select view mode: " view_mode
                
                case "$view_mode" in
                    1) view_log "$selected_log" "full" ;;
                    2) view_log "$selected_log" "tail" ;;
                    3) view_log "$selected_log" "prompts" ;;
                    4) view_log "$selected_log" "responses" ;;
                    5) view_log "$selected_log" "errors" ;;
                esac
            fi
            ;;
        f|F)
            # Follow latest log
            latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
            if [ -f "$latest_log" ]; then
                echo "Following $(basename "$latest_log")... (Ctrl+C to stop)"
                view_log "$latest_log" "follow"
            fi
            ;;
        a|A)
            # Show all logs
            cat "$LOG_DIR"/*.log | less
            ;;
        p|P)
            # Show all prompts
            cat "$LOG_DIR"/*.log | awk '/=== PROMPT SENT TO CLAUDE ===/,/=== END OF PROMPT ===/' | less
            ;;
        r|R)
            # Show all responses
            cat "$LOG_DIR"/*.log | awk '/=== CLAUDE RESPONSE START ===/,/=== CLAUDE RESPONSE END ===/' | less
            ;;
        e|E)
            # Show all errors
            grep -h -E "(ERROR|FAILED|Failed)" "$LOG_DIR"/*.log | less
            ;;
        q|Q)
            echo "Goodbye!"
            exit 0
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done