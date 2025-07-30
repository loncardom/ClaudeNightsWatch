#!/bin/bash

# ClaudeNightsWatch JSON Validation Library
# Provides comprehensive JSON validation with graceful error handling

# Global validation settings
JSON_VALIDATION_LOG="${JSON_VALIDATION_LOG:-/tmp/claude-nights-watch-json-validation.log}"
JSON_VALIDATION_STRICT="${JSON_VALIDATION_STRICT:-true}"

# Initialize validation logging
init_json_validation_logging() {
    touch "$JSON_VALIDATION_LOG" 2>/dev/null || {
        JSON_VALIDATION_LOG="/tmp/json-validation-$$.log"
        touch "$JSON_VALIDATION_LOG"
    }
}

# Log validation events
log_validation_event() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$JSON_VALIDATION_LOG" 2>/dev/null
}

# Basic JSON syntax validation
validate_json_syntax() {
    local file_path="$1"
    local context="${2:-unknown}"

    if [ ! -f "$file_path" ]; then
        log_validation_event "ERROR" "JSON file not found: $file_path (context: $context)"
        echo "ERROR: JSON file not found: $file_path"
        return 1
    fi

    if [ ! -r "$file_path" ]; then
        log_validation_event "ERROR" "JSON file not readable: $file_path (context: $context)"
        echo "ERROR: JSON file not readable: $file_path"
        return 1
    fi

    local json_error
    json_error=$(jq empty "$file_path" 2>&1)
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        log_validation_event "ERROR" "Invalid JSON syntax in $file_path: $json_error (context: $context)"
        echo "ERROR: Invalid JSON syntax in $file_path"
        echo "Details: $json_error"
        return 1
    fi

    log_validation_event "INFO" "JSON syntax validation passed for $file_path (context: $context)"
    return 0
}

# Task queue schema validation
validate_task_queue_schema() {
    local file_path="$1"
    local context="${2:-task_queue}"

    # First validate basic JSON syntax
    if ! validate_json_syntax "$file_path" "$context"; then
        return 1
    fi

    local errors=()

    # Check required top-level fields
    local required_fields=("version" "project" "tasks" "queue_metadata")
    for field in "${required_fields[@]}"; do
        if ! jq -e "has(\"$field\")" "$file_path" >/dev/null 2>&1; then
            errors+=("Missing required field: $field")
        fi
    done

    # Validate version format
    local version
    version=$(jq -r '.version // ""' "$file_path" 2>/dev/null)
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
        errors+=("Invalid version format: '$version' (expected: X.Y)")
    fi

    # Validate project name
    local project
    project=$(jq -r '.project // ""' "$file_path" 2>/dev/null)
    if [[ -z "$project" || ! "$project" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        errors+=("Invalid project name: '$project' (must be non-empty alphanumeric with _ or -)")
    fi

    # Validate tasks array
    if ! jq -e '.tasks | type == "array"' "$file_path" >/dev/null 2>&1; then
        errors+=("Field 'tasks' must be an array")
    else
        # Validate individual tasks
        local task_count
        task_count=$(jq '.tasks | length' "$file_path" 2>/dev/null)
        for ((i=0; i<task_count; i++)); do
            local task_errors
            task_errors=$(validate_task_object "$file_path" "$i")
            if [ -n "$task_errors" ]; then
                errors+=("Task[$i]: $task_errors")
            fi
        done
    fi

    # Validate queue_metadata
    if ! validate_queue_metadata "$file_path"; then
        errors+=("Invalid queue_metadata structure")
    fi

    # Report errors
    if [ ${#errors[@]} -gt 0 ]; then
        log_validation_event "ERROR" "Schema validation failed for $file_path (context: $context)"
        echo "ERROR: Task queue schema validation failed:"
        for error in "${errors[@]}"; do
            echo "  - $error"
            log_validation_event "ERROR" "Schema error: $error (file: $file_path)"
        done
        return 1
    fi

    log_validation_event "INFO" "Schema validation passed for $file_path (context: $context)"
    return 0
}

# Validate individual task object
validate_task_object() {
    local file_path="$1"
    local task_index="$2"
    local errors=()

    local task_selector=".tasks[$task_index]"

    # Required task fields
    local required_task_fields=("id" "title" "description" "priority" "status")
    for field in "${required_task_fields[@]}"; do
        if ! jq -e "$task_selector | has(\"$field\")" "$file_path" >/dev/null 2>&1; then
            errors+=("Missing required field: $field")
        fi
    done

    # Validate task ID format
    local task_id
    task_id=$(jq -r "$task_selector.id // \"\"" "$file_path" 2>/dev/null)
    if [[ ! "$task_id" =~ ^task-[0-9]{3}$ ]]; then
        errors+=("Invalid task ID format: '$task_id' (expected: task-XXX)")
    fi

    # Validate priority
    local priority
    priority=$(jq -r "$task_selector.priority // \"\"" "$file_path" 2>/dev/null)
    if [[ ! "$priority" =~ ^(low|medium|high)$ ]]; then
        errors+=("Invalid priority: '$priority' (must be: low, medium, or high)")
    fi

    # Validate status
    local status
    status=$(jq -r "$task_selector.status // \"\"" "$file_path" 2>/dev/null)
    if [[ ! "$status" =~ ^(pending|in_progress|completed|failed)$ ]]; then
        errors+=("Invalid status: '$status' (must be: pending, in_progress, completed, or failed)")
    fi

    # Validate execution_context if present
    if jq -e "$task_selector | has(\"execution_context\")" "$file_path" >/dev/null 2>&1; then
        if ! validate_execution_context "$file_path" "$task_index"; then
            errors+=("Invalid execution_context")
        fi
    fi

    if [ ${#errors[@]} -gt 0 ]; then
        echo "${errors[*]}"
        return 1
    fi

    return 0
}

# Validate execution context
validate_execution_context() {
    local file_path="$1"
    local task_index="$2"
    local context_selector=".tasks[$task_index].execution_context"

    # Check if arrays are actually arrays
    if jq -e "$context_selector | has(\"safety_constraints\")" "$file_path" >/dev/null 2>&1; then
        if ! jq -e "$context_selector.safety_constraints | type == \"array\"" "$file_path" >/dev/null 2>&1; then
            return 1
        fi
    fi

    if jq -e "$context_selector | has(\"success_criteria\")" "$file_path" >/dev/null 2>&1; then
        if ! jq -e "$context_selector.success_criteria | type == \"array\"" "$file_path" >/dev/null 2>&1; then
            return 1
        fi
    fi

    return 0
}

# Validate queue metadata
validate_queue_metadata() {
    local file_path="$1"
    local metadata_selector=".queue_metadata"

    local required_metadata_fields=("total_tasks" "pending_tasks" "in_progress_tasks" "completed_tasks" "failed_tasks")
    for field in "${required_metadata_fields[@]}"; do
        if ! jq -e "$metadata_selector | has(\"$field\")" "$file_path" >/dev/null 2>&1; then
            return 1
        fi

        # Validate that counts are non-negative integers
        local count
        count=$(jq -r "$metadata_selector.$field // -1" "$file_path" 2>/dev/null)
        if [[ ! "$count" =~ ^[0-9]+$ ]]; then
            return 1
        fi
    done

    return 0
}

# Safe JSON extraction with validation
safe_json_extract() {
    local file_path="$1"
    local jq_filter="$2"
    local default_value="${3:-}"
    local context="${4:-extraction}"

    # Validate file exists and is readable
    if [ ! -f "$file_path" ] || [ ! -r "$file_path" ]; then
        log_validation_event "ERROR" "Cannot read file for extraction: $file_path (context: $context)"
        echo "$default_value"
        return 1
    fi

    # Validate JSON syntax first
    if ! jq empty "$file_path" 2>/dev/null; then
        log_validation_event "ERROR" "Invalid JSON in file during extraction: $file_path (context: $context)"
        echo "$default_value"
        return 1
    fi

    # Perform extraction with error handling
    local result
    result=$(jq -r "$jq_filter" "$file_path" 2>/dev/null)
    local exit_code=$?

    if [ $exit_code -ne 0 ] || [ "$result" = "null" ]; then
        log_validation_event "WARN" "JSON extraction failed or returned null: filter='$jq_filter' file='$file_path' (context: $context)"
        echo "$default_value"
        return 1
    fi

    echo "$result"
    return 0
}

# Validate and update JSON file atomically
safe_json_update() {
    local file_path="$1"
    local jq_script="$2"
    local context="${3:-update}"
    shift 3
    local jq_args=("$@")

    # Validate input file
    if ! validate_json_syntax "$file_path" "$context"; then
        return 1
    fi

    # Create temporary file
    local temp_file
    temp_file=$(mktemp "${file_path}.tmp.XXXXXX") || {
        log_validation_event "ERROR" "Failed to create temp file for update: $file_path (context: $context)"
        return 1
    }

    # Perform update to temp file
    if ! jq "${jq_args[@]}" "$jq_script" "$file_path" > "$temp_file" 2>/dev/null; then
        log_validation_event "ERROR" "JSON update operation failed: $file_path (context: $context)"
        rm -f "$temp_file"
        return 1
    fi

    # Validate updated JSON
    if ! validate_json_syntax "$temp_file" "$context-updated"; then
        log_validation_event "ERROR" "Updated JSON is invalid: $file_path (context: $context)"
        rm -f "$temp_file"
        return 1
    fi

    # Atomic replace
    if ! mv "$temp_file" "$file_path"; then
        log_validation_event "ERROR" "Failed to replace file atomically: $file_path (context: $context)"
        rm -f "$temp_file"
        return 1
    fi

    log_validation_event "INFO" "JSON file updated successfully: $file_path (context: $context)"
    return 0
}

# Get validation status summary
get_validation_summary() {
    local recent_logs
    recent_logs=$(tail -20 "$JSON_VALIDATION_LOG" 2>/dev/null || echo "No validation logs available")

    echo "=== JSON Validation Summary ==="
    echo "Log file: $JSON_VALIDATION_LOG"
    echo "Recent events:"
    echo "$recent_logs"
}

# Initialize logging when script is sourced
init_json_validation_logging
