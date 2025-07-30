#!/bin/bash

# Performance Benchmark Suite for ClaudeNightsWatch
# Measures key functions and operations to establish baseline

BENCHMARK_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_FILE="$BENCHMARK_DIR/benchmark-results.txt"
DAEMON_SCRIPT="$BENCHMARK_DIR/claude-nights-watch-daemon.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_result() {
    echo -e "${GREEN}[RESULT]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# High-precision timing function
time_function() {
    local func_name="$1"
    local iterations="${2:-100}"
    local cmd="$3"

    print_header "Benchmarking: $func_name ($iterations iterations)"

    local start_ns=$(date +%s%N)

    for i in $(seq 1 $iterations); do
        eval "$cmd" >/dev/null 2>&1
    done

    local end_ns=$(date +%s%N)
    local total_ns=$((end_ns - start_ns))
    local avg_ns=$((total_ns / iterations))
    local avg_ms=$(echo "scale=3; $avg_ns / 1000000" | bc -l 2>/dev/null || echo "$(($avg_ns / 1000000))")

    print_result "$func_name: ${avg_ms}ms avg (${iterations} iterations, ${total_ns}ns total)"
    echo "$func_name,$iterations,$avg_ns,$avg_ms" >> "$RESULTS_FILE"
}

# Memory measurement function
measure_memory() {
    local func_name="$1"
    local cmd="$2"

    print_header "Memory usage: $func_name"

    # Use time command to measure memory if available
    if command -v /usr/bin/time >/dev/null 2>&1; then
        local mem_output=$(/usr/bin/time -v bash -c "$cmd" 2>&1 | grep "Maximum resident set size")
        if [ -n "$mem_output" ]; then
            local max_mem=$(echo "$mem_output" | awk '{print $6}')
            print_result "$func_name memory: ${max_mem}KB peak"
            echo "$func_name,memory,${max_mem}KB" >> "$RESULTS_FILE"
        fi
    else
        print_warning "GNU time not available, skipping memory measurement"
    fi
}

# Create test files for benchmarking
setup_test_files() {
    print_header "Setting up test files"

    # Create test task file
    cat > test-task.md << 'EOF'
# Test Task for Benchmarking
This is a test task with multiple lines of content.
It includes various types of content to simulate real usage.

## Section 1
Some content here with commands and text.

## Section 2
More content to make the file realistic size.
EOF

    # Create test rules file
    cat > test-rules.md << 'EOF'
# Test Rules
- Rule 1: Safety first
- Rule 2: No destructive operations
- Rule 3: Log everything
EOF

    # Create large test files for I/O benchmarking
    for size in 1k 10k 100k; do
        dd if=/dev/zero of="test-large-${size}.txt" bs=1024 count=${size%k} 2>/dev/null
    done

    print_result "Test files created"
}

# Source the daemon script to access functions
source_daemon_functions() {
    # Extract and source individual functions for testing
    # We'll create a minimal version to avoid running the main daemon

    cat > benchmark-functions.sh << 'EOF'
#!/bin/bash

# Minimal function definitions for benchmarking
TASK_DIR="."
TASK_FILE="test-task.md"
RULES_FILE="test-rules.md"
LOG_FILE="/tmp/benchmark.log"
LAST_ACTIVITY_FILE="/tmp/benchmark-activity"

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

prepare_task_prompt() {
    local prompt=""

    if [ ! -d "$TASK_DIR" ]; then
        return 1
    fi

    if [ -f "$TASK_DIR/$RULES_FILE" ]; then
        if [ -r "$TASK_DIR/$RULES_FILE" ] && [ -s "$TASK_DIR/$RULES_FILE" ]; then
            prompt="IMPORTANT RULES TO FOLLOW:\n\n"
            prompt+=$(cat "$TASK_DIR/$RULES_FILE" | head -1000)
            prompt+="\n\n---END OF RULES---\n\n"
        fi
    fi

    if [ ! -f "$TASK_DIR/$TASK_FILE" ] || [ ! -r "$TASK_DIR/$TASK_FILE" ] || [ ! -s "$TASK_DIR/$TASK_FILE" ]; then
        return 1
    fi

    local task_size=$(wc -c < "$TASK_DIR/$TASK_FILE" 2>/dev/null || echo "0")
    if [ "$task_size" -gt 100000 ]; then
        prompt+="TASK TO EXECUTE:\n\n"
        prompt+=$(head -c 100000 "$TASK_DIR/$TASK_FILE")
        prompt+="\n\n[... TASK TRUNCATED DUE TO SIZE ...]\n\n"
    else
        prompt+="TASK TO EXECUTE:\n\n"
        prompt+=$(cat "$TASK_DIR/$TASK_FILE")
        prompt+="\n\n"
    fi

    prompt+="---END OF TASK---\n\n"
    prompt+="Please read the above task, create a todo list from it, and then execute it step by step. "
    prompt+="IMPORTANT: This is an autonomous execution - do not ask for user confirmation or input."

    if [ -z "$prompt" ]; then
        return 1
    fi

    echo -e "$prompt"
}

calculate_sleep_duration() {
    if [ -f "$LAST_ACTIVITY_FILE" ]; then
        local last_activity=$(cat "$LAST_ACTIVITY_FILE")
        local current_time=$(date +%s)
        local time_diff=$((current_time - last_activity))
        local remaining=$((18000 - time_diff))

        if [ "$remaining" -le 300 ]; then
            echo 30
        elif [ "$remaining" -le 1800 ]; then
            echo 120
        else
            echo 600
        fi
    else
        echo 300
    fi
}
EOF

    source benchmark-functions.sh
}

# Run all benchmarks
run_benchmarks() {
    print_header "Starting Performance Benchmark Suite"
    echo "Timestamp: $(date)" > "$RESULTS_FILE"
    echo "System: $(uname -a)" >> "$RESULTS_FILE"
    echo "Function,Iterations,AvgNanoseconds,AvgMilliseconds" >> "$RESULTS_FILE"

    setup_test_files
    source_daemon_functions

    # Benchmark core functions
    time_function "prepare_task_prompt" 1000 "prepare_task_prompt"
    time_function "calculate_sleep_duration" 1000 "echo \$(date +%s) > $LAST_ACTIVITY_FILE; calculate_sleep_duration"
    time_function "get_ccusage_cmd" 100 "get_ccusage_cmd"

    # Benchmark file operations
    time_function "file_read_small" 1000 "cat test-task.md"
    time_function "file_read_1k" 100 "cat test-large-1k.txt"
    time_function "file_read_10k" 100 "cat test-large-10k.txt"
    time_function "file_read_100k" 10 "cat test-large-100k.txt"

    # Benchmark common operations
    time_function "date_operations" 1000 "date +%s"
    time_function "wc_operations" 1000 "wc -l test-task.md"
    time_function "grep_operations" 1000 "grep -q 'Test' test-task.md"

    # Benchmark string operations
    time_function "string_concatenation" 1000 'result=""; for i in {1..10}; do result+="test"; done'
    time_function "command_substitution" 1000 'result=$(echo "test")'

    # Memory measurements
    measure_memory "prepare_task_prompt" "prepare_task_prompt"
    measure_memory "large_file_read" "cat test-large-100k.txt"

    print_header "Benchmark Results Summary"
    echo ""
    cat "$RESULTS_FILE"

    # Cleanup
    rm -f test-*.md test-large-*.txt benchmark-functions.sh
    rm -f /tmp/benchmark.log /tmp/benchmark-activity
}

# System information
print_system_info() {
    print_header "System Information"
    echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
    echo "Shell: $BASH_VERSION"
    echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || uname -o)"
}

# Main execution
main() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "Usage: $0 [--system-info]"
        echo "  --system-info  Show only system information"
        exit 0
    fi

    if [ "$1" = "--system-info" ]; then
        print_system_info
        exit 0
    fi

    print_system_info
    echo ""
    run_benchmarks
}

main "$@"
