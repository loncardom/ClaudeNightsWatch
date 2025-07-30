#!/bin/bash

# Claude Nights Watch Python Static Code Analyzer
# Integrates static analysis tools to identify and prioritize Python code improvements

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[PYTHON-ANALYZER]${NC} $1"
}

print_error() {
    echo -e "${RED}[PYTHON-ANALYZER ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[PYTHON-ANALYZER WARNING]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[PYTHON-ANALYZER INFO]${NC} $1"
}

# Python project detection logic
is_python_project() {
    local target_dir="$1"

    if [ ! -d "$target_dir" ]; then
        return 1
    fi

    # Check for common Python project indicators
    local python_indicators=(
        "setup.py"
        "pyproject.toml"
        "requirements.txt"
        "requirements/*.txt"
        "Pipfile"
        "poetry.lock"
        "setup.cfg"
        "tox.ini"
        "pytest.ini"
        ".python-version"
        "conda.yml"
        "environment.yml"
    )

    # Check for indicator files
    for indicator in "${python_indicators[@]}"; do
        if [[ "$indicator" == *"*"* ]]; then
            # Handle glob patterns
            if ls "$target_dir"/$indicator >/dev/null 2>&1; then
                return 0
            fi
        else
            if [ -f "$target_dir/$indicator" ]; then
                return 0
            fi
        fi
    done

    # Check for .py files in reasonable locations
    local python_file_count=0

    # Count .py files in common directories, limiting depth to avoid excessive scanning
    for search_dir in "$target_dir" "$target_dir/src" "$target_dir/lib" "$target_dir/app" "$target_dir"/*; do
        if [ -d "$search_dir" ]; then
            local py_files=$(find "$search_dir" -maxdepth 3 -name "*.py" -type f 2>/dev/null | head -20 | wc -l)
            python_file_count=$((python_file_count + py_files))

            # If we find enough Python files, it's likely a Python project
            if [ "$python_file_count" -ge 5 ]; then
                return 0
            fi
        fi
    done

    # Additional check: look for Python-specific directory structures
    if [ -d "$target_dir/tests" ] && find "$target_dir/tests" -name "*.py" -type f | head -1 | grep -q "\.py$"; then
        return 0
    fi

    return 1
}

# Get Python project details
get_python_project_info() {
    local target_dir="$1"
    local info_file="$2"

    cat > "$info_file" << EOF
{
  "is_python_project": true,
  "analyzed_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "target_directory": "$target_dir",
  "project_structure": {
EOF

    # Detect project type and structure
    if [ -f "$target_dir/setup.py" ]; then
        echo '    "type": "setuptools",' >> "$info_file"
        echo '    "config_files": ["setup.py"],' >> "$info_file"
    elif [ -f "$target_dir/pyproject.toml" ]; then
        echo '    "type": "pyproject",' >> "$info_file"
        echo '    "config_files": ["pyproject.toml"],' >> "$info_file"
    elif [ -f "$target_dir/Pipfile" ]; then
        echo '    "type": "pipenv",' >> "$info_file"
        echo '    "config_files": ["Pipfile"],' >> "$info_file"
    else
        echo '    "type": "generic",' >> "$info_file"
        echo '    "config_files": [],' >> "$info_file"
    fi

    # Count Python files
    local py_count=$(find "$target_dir" -name "*.py" -type f 2>/dev/null | wc -l)
    echo "    \"python_files_count\": $py_count," >> "$info_file"

    # Detect testing framework
    local test_framework="none"
    if find "$target_dir" -name "*test*.py" -o -name "test_*.py" | head -1 | grep -q "\.py$"; then
        if grep -r "import pytest\|from pytest" "$target_dir" >/dev/null 2>&1; then
            test_framework="pytest"
        elif grep -r "import unittest\|from unittest" "$target_dir" >/dev/null 2>&1; then
            test_framework="unittest"
        else
            test_framework="unknown"
        fi
    fi
    echo "    \"test_framework\": \"$test_framework\"," >> "$info_file"

    # Check for type hints usage
    local has_type_hints=false
    if grep -r "from typing import\|: List\|: Dict\|: Optional\|-> " "$target_dir" >/dev/null 2>&1; then
        has_type_hints=true
    fi
    echo "    \"has_type_hints\": $has_type_hints" >> "$info_file"

    cat >> "$info_file" << EOF
  },
  "analysis_tools": {
    "pylint": {
      "available": false,
      "version": null
    },
    "flake8": {
      "available": false,
      "version": null
    },
    "mypy": {
      "available": false,
      "version": null
    },
    "bandit": {
      "available": false,
      "version": null
    }
  },
  "analysis_results": {
    "total_issues": 0,
    "by_severity": {
      "critical": 0,
      "high": 0,
      "medium": 0,
      "low": 0,
      "info": 0
    },
    "by_category": {
      "style": 0,
      "security": 0,
      "bugs": 0,
      "complexity": 0,
      "type_issues": 0,
      "performance": 0
    }
  }
}
EOF
}

# Check if analysis tools are available
check_analysis_tools() {
    local info_file="$1"

    # Check pylint
    if command -v pylint >/dev/null 2>&1; then
        local pylint_version=$(pylint --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
        jq --arg version "$pylint_version" '.analysis_tools.pylint.available = true | .analysis_tools.pylint.version = $version' "$info_file" > "${info_file}.tmp" && mv "${info_file}.tmp" "$info_file"
    fi

    # Check flake8
    if command -v flake8 >/dev/null 2>&1; then
        local flake8_version=$(flake8 --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
        jq --arg version "$flake8_version" '.analysis_tools.flake8.available = true | .analysis_tools.flake8.version = $version' "$info_file" > "${info_file}.tmp" && mv "${info_file}.tmp" "$info_file"
    fi

    # Check mypy
    if command -v mypy >/dev/null 2>&1; then
        local mypy_version=$(mypy --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
        jq --arg version "$mypy_version" '.analysis_tools.mypy.available = true | .analysis_tools.mypy.version = $version' "$info_file" > "${info_file}.tmp" && mv "${info_file}.tmp" "$info_file"
    fi

    # Check bandit
    if command -v bandit >/dev/null 2>&1; then
        local bandit_version=$(bandit --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
        jq --arg version "$bandit_version" '.analysis_tools.bandit.available = true | .analysis_tools.bandit.version = $version' "$info_file" > "${info_file}.tmp" && mv "${info_file}.tmp" "$info_file"
    fi
}

# Install missing analysis tools
install_analysis_tools() {
    print_status "Installing Python static analysis tools..."

    # Try pip install
    if command -v pip >/dev/null 2>&1; then
        pip install --user pylint flake8 mypy bandit 2>/dev/null || {
            print_warning "Failed to install tools via pip"
        }
    elif command -v pip3 >/dev/null 2>&1; then
        pip3 install --user pylint flake8 mypy bandit 2>/dev/null || {
            print_warning "Failed to install tools via pip3"
        }
    else
        print_warning "pip not available - tools must be installed manually"
        return 1
    fi
}

# Run static analysis
run_static_analysis() {
    local target_dir="$1"
    local results_file="$2"
    local info_file="$3"

    print_status "Running static analysis on $target_dir"

    # Initialize results file
    cat > "$results_file" << 'EOF'
{
  "analysis_timestamp": "",
  "target_directory": "",
  "tools_executed": [],
  "issues": [],
  "summary": {
    "total_issues": 0,
    "by_severity": {
      "critical": 0,
      "high": 0,
      "medium": 0,
      "low": 0,
      "info": 0
    },
    "by_category": {
      "style": 0,
      "security": 0,
      "bugs": 0,
      "complexity": 0,
      "type_issues": 0,
      "performance": 0
    },
    "by_tool": {
      "pylint": 0,
      "flake8": 0,
      "mypy": 0,
      "bandit": 0
    }
  }
}
EOF

    # Update basic info
    jq --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg target "$target_dir" \
       '.analysis_timestamp = $timestamp | .target_directory = $target' "$results_file" > "${results_file}.tmp" && mv "${results_file}.tmp" "$results_file"

    local tools_executed=()

    # Run pylint if available
    if jq -r '.analysis_tools.pylint.available' "$info_file" | grep -q "true"; then
        print_info "Running pylint analysis..."
        run_pylint "$target_dir" "$results_file"
        tools_executed+=("pylint")
    fi

    # Run flake8 if available
    if jq -r '.analysis_tools.flake8.available' "$info_file" | grep -q "true"; then
        print_info "Running flake8 analysis..."
        run_flake8 "$target_dir" "$results_file"
        tools_executed+=("flake8")
    fi

    # Run mypy if available and project has type hints
    if jq -r '.analysis_tools.mypy.available' "$info_file" | grep -q "true" && \
       jq -r '.project_structure.has_type_hints' "$info_file" | grep -q "true"; then
        print_info "Running mypy analysis..."
        run_mypy "$target_dir" "$results_file"
        tools_executed+=("mypy")
    fi

    # Run bandit if available
    if jq -r '.analysis_tools.bandit.available' "$info_file" | grep -q "true"; then
        print_info "Running bandit security analysis..."
        run_bandit "$target_dir" "$results_file"
        tools_executed+=("bandit")
    fi

    # Update tools executed
    local tools_json=$(printf '%s\n' "${tools_executed[@]}" | jq -R . | jq -s .)
    jq --argjson tools "$tools_json" '.tools_executed = $tools' "$results_file" > "${results_file}.tmp" && mv "${results_file}.tmp" "$results_file"

    # Update summary counts
    calculate_summary_stats "$results_file"
}

# Run pylint analysis
run_pylint() {
    local target_dir="$1"
    local results_file="$2"

    # Create a temporary pylint config to avoid overly strict defaults
    local pylint_config=$(mktemp)
    cat > "$pylint_config" << 'EOF'
[MASTER]
disable=missing-docstring,too-few-public-methods,invalid-name,line-too-long

[FORMAT]
max-line-length=100

[DESIGN]
max-args=7
max-locals=20
max-branches=15
max-statements=60
EOF

    # Run pylint and parse results
    local pylint_output=$(mktemp)
    pylint --rcfile="$pylint_config" --output-format=json "$target_dir" 2>/dev/null | jq -c '.[]' > "$pylint_output" 2>/dev/null || true

    # Process pylint results
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local file_path=$(echo "$line" | jq -r '.path // ""')
            local line_num=$(echo "$line" | jq -r '.line // 0')
            local column=$(echo "$line" | jq -r '.column // 0')
            local message=$(echo "$line" | jq -r '.message // ""')
            local symbol=$(echo "$line" | jq -r '.symbol // ""')
            local msg_id=$(echo "$line" | jq -r '.message-id // ""')
            local type=$(echo "$line" | jq -r '.type // "info"')

            # Map pylint types to our severity system
            local severity="info"
            local category="style"
            case "$type" in
                "error"|"fatal") severity="high"; category="bugs" ;;
                "warning") severity="medium"; category="style" ;;
                "refactor") severity="low"; category="complexity" ;;
                "convention") severity="info"; category="style" ;;
            esac

            # Add issue to results
            local issue=$(jq -n \
                --arg tool "pylint" \
                --arg file "$file_path" \
                --arg line "$line_num" \
                --arg column "$column" \
                --arg severity "$severity" \
                --arg category "$category" \
                --arg message "$message" \
                --arg rule_id "$msg_id" \
                --arg rule_name "$symbol" \
                '{
                    tool: $tool,
                    file: $file,
                    line: ($line | tonumber),
                    column: ($column | tonumber),
                    severity: $severity,
                    category: $category,
                    message: $message,
                    rule_id: $rule_id,
                    rule_name: $rule_name
                }')

            # Append to results file
            jq --argjson issue "$issue" '.issues += [$issue]' "$results_file" > "${results_file}.tmp" && mv "${results_file}.tmp" "$results_file"
        fi
    done < "$pylint_output"

    rm -f "$pylint_config" "$pylint_output"
}

# Run flake8 analysis
run_flake8() {
    local target_dir="$1"
    local results_file="$2"

    # Run flake8 with reasonable settings
    local flake8_output=$(mktemp)
    flake8 --max-line-length=100 --extend-ignore=E203,W503 --format='%(path)s:%(row)d:%(col)d:%(code)s:%(text)s' "$target_dir" > "$flake8_output" 2>/dev/null || true

    # Process flake8 results
    while IFS=':' read -r file_path line_num column code message; do
        if [ -n "$file_path" ] && [ -n "$line_num" ]; then
            # Map flake8 codes to severity and category
            local severity="info"
            local category="style"

            case "${code:0:1}" in
                "E") severity="medium"; category="style" ;;
                "W") severity="low"; category="style" ;;
                "F") severity="high"; category="bugs" ;;
                "C") severity="medium"; category="complexity" ;;
                "N") severity="info"; category="style" ;;
            esac

            # Add issue to results
            local issue=$(jq -n \
                --arg tool "flake8" \
                --arg file "$file_path" \
                --arg line "$line_num" \
                --arg column "$column" \
                --arg severity "$severity" \
                --arg category "$category" \
                --arg message "$message" \
                --arg rule_id "$code" \
                --arg rule_name "$code" \
                '{
                    tool: $tool,
                    file: $file,
                    line: ($line | tonumber),
                    column: ($column | tonumber),
                    severity: $severity,
                    category: $category,
                    message: $message,
                    rule_id: $rule_id,
                    rule_name: $rule_name
                }')

            # Append to results file
            jq --argjson issue "$issue" '.issues += [$issue]' "$results_file" > "${results_file}.tmp" && mv "${results_file}.tmp" "$results_file"
        fi
    done < "$flake8_output"

    rm -f "$flake8_output"
}

# Run mypy analysis
run_mypy() {
    local target_dir="$1"
    local results_file="$2"

    # Run mypy with reasonable settings
    local mypy_output=$(mktemp)
    mypy --ignore-missing-imports --show-error-codes --no-error-summary "$target_dir" > "$mypy_output" 2>/dev/null || true

    # Process mypy results (format: file:line: severity: message [error-code])
    while IFS= read -r line; do
        if [[ "$line" =~ ^([^:]+):([0-9]+):\ (error|warning|note):\ (.+)\ \[([^\]]+)\]$ ]]; then
            local file_path="${BASH_REMATCH[1]}"
            local line_num="${BASH_REMATCH[2]}"
            local msg_type="${BASH_REMATCH[3]}"
            local message="${BASH_REMATCH[4]}"
            local error_code="${BASH_REMATCH[5]}"

            # Map mypy types to our severity system
            local severity="info"
            case "$msg_type" in
                "error") severity="high" ;;
                "warning") severity="medium" ;;
                "note") severity="info" ;;
            esac

            # Add issue to results
            local issue=$(jq -n \
                --arg tool "mypy" \
                --arg file "$file_path" \
                --arg line "$line_num" \
                --arg column "0" \
                --arg severity "$severity" \
                --arg category "type_issues" \
                --arg message "$message" \
                --arg rule_id "$error_code" \
                --arg rule_name "$error_code" \
                '{
                    tool: $tool,
                    file: $file,
                    line: ($line | tonumber),
                    column: ($column | tonumber),
                    severity: $severity,
                    category: $category,
                    message: $message,
                    rule_id: $rule_id,
                    rule_name: $rule_name
                }')

            # Append to results file
            jq --argjson issue "$issue" '.issues += [$issue]' "$results_file" > "${results_file}.tmp" && mv "${results_file}.tmp" "$results_file"
        fi
    done < "$mypy_output"

    rm -f "$mypy_output"
}

# Run bandit security analysis
run_bandit() {
    local target_dir="$1"
    local results_file="$2"

    # Run bandit with JSON output
    local bandit_output=$(mktemp)
    bandit -r "$target_dir" -f json -o "$bandit_output" 2>/dev/null || true

    # Process bandit results
    if [ -f "$bandit_output" ] && jq empty "$bandit_output" 2>/dev/null; then
        jq -r '.results[]? | [.filename, .line_number, .issue_severity, .issue_confidence, .issue_text, .test_id, .test_name] | @tsv' "$bandit_output" | \
        while IFS=$'\t' read -r file_path line_num severity confidence message test_id test_name; do
            # Map bandit severity to our system
            local our_severity="info"
            case "$severity" in
                "HIGH") our_severity="critical" ;;
                "MEDIUM") our_severity="high" ;;
                "LOW") our_severity="medium" ;;
            esac

            # Add issue to results
            local issue=$(jq -n \
                --arg tool "bandit" \
                --arg file "$file_path" \
                --arg line "$line_num" \
                --arg column "0" \
                --arg severity "$our_severity" \
                --arg category "security" \
                --arg message "$message" \
                --arg rule_id "$test_id" \
                --arg rule_name "$test_name" \
                '{
                    tool: $tool,
                    file: $file,
                    line: ($line | tonumber),
                    column: ($column | tonumber),
                    severity: $severity,
                    category: $category,
                    message: $message,
                    rule_id: $rule_id,
                    rule_name: $rule_name
                }')

            # Append to results file
            jq --argjson issue "$issue" '.issues += [$issue]' "$results_file" > "${results_file}.tmp" && mv "${results_file}.tmp" "$results_file"
        done
    fi

    rm -f "$bandit_output"
}

# Calculate summary statistics
calculate_summary_stats() {
    local results_file="$1"

    # Count issues by severity
    local critical=$(jq '[.issues[] | select(.severity == "critical")] | length' "$results_file")
    local high=$(jq '[.issues[] | select(.severity == "high")] | length' "$results_file")
    local medium=$(jq '[.issues[] | select(.severity == "medium")] | length' "$results_file")
    local low=$(jq '[.issues[] | select(.severity == "low")] | length' "$results_file")
    local info=$(jq '[.issues[] | select(.severity == "info")] | length' "$results_file")
    local total=$((critical + high + medium + low + info))

    # Count issues by category
    local style=$(jq '[.issues[] | select(.category == "style")] | length' "$results_file")
    local security=$(jq '[.issues[] | select(.category == "security")] | length' "$results_file")
    local bugs=$(jq '[.issues[] | select(.category == "bugs")] | length' "$results_file")
    local complexity=$(jq '[.issues[] | select(.category == "complexity")] | length' "$results_file")
    local type_issues=$(jq '[.issues[] | select(.category == "type_issues")] | length' "$results_file")
    local performance=$(jq '[.issues[] | select(.category == "performance")] | length' "$results_file")

    # Count issues by tool
    local pylint_count=$(jq '[.issues[] | select(.tool == "pylint")] | length' "$results_file")
    local flake8_count=$(jq '[.issues[] | select(.tool == "flake8")] | length' "$results_file")
    local mypy_count=$(jq '[.issues[] | select(.tool == "mypy")] | length' "$results_file")
    local bandit_count=$(jq '[.issues[] | select(.tool == "bandit")] | length' "$results_file")

    # Update summary
    jq --arg total "$total" \
       --arg critical "$critical" --arg high "$high" --arg medium "$medium" --arg low "$low" --arg info "$info" \
       --arg style "$style" --arg security "$security" --arg bugs "$bugs" --arg complexity "$complexity" --arg type_issues "$type_issues" --arg performance "$performance" \
       --arg pylint "$pylint_count" --arg flake8 "$flake8_count" --arg mypy "$mypy_count" --arg bandit "$bandit_count" \
       '.summary.total_issues = ($total | tonumber) |
        .summary.by_severity.critical = ($critical | tonumber) |
        .summary.by_severity.high = ($high | tonumber) |
        .summary.by_severity.medium = ($medium | tonumber) |
        .summary.by_severity.low = ($low | tonumber) |
        .summary.by_severity.info = ($info | tonumber) |
        .summary.by_category.style = ($style | tonumber) |
        .summary.by_category.security = ($security | tonumber) |
        .summary.by_category.bugs = ($bugs | tonumber) |
        .summary.by_category.complexity = ($complexity | tonumber) |
        .summary.by_category.type_issues = ($type_issues | tonumber) |
        .summary.by_category.performance = ($performance | tonumber) |
        .summary.by_tool.pylint = ($pylint | tonumber) |
        .summary.by_tool.flake8 = ($flake8 | tonumber) |
        .summary.by_tool.mypy = ($mypy | tonumber) |
        .summary.by_tool.bandit = ($bandit | tonumber)' "$results_file" > "${results_file}.tmp" && mv "${results_file}.tmp" "$results_file"
}

# Generate prioritized improvement recommendations
generate_recommendations() {
    local results_file="$1"
    local recommendations_file="$2"

    print_status "Generating prioritized improvement recommendations..."

    # Initialize recommendations file
    cat > "$recommendations_file" << 'EOF'
{
  "generated_at": "",
  "source_analysis": "",
  "recommendations": [],
  "summary": {
    "total_recommendations": 0,
    "by_priority": {
      "critical": 0,
      "high": 0,
      "medium": 0,
      "low": 0
    },
    "estimated_total_effort_minutes": 0
  }
}
EOF

    # Update basic info
    jq --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg source "$results_file" \
       '.generated_at = $timestamp | .source_analysis = $source' "$recommendations_file" > "${recommendations_file}.tmp" && mv "${recommendations_file}.tmp" "$recommendations_file"

    # Group issues by file and category for better recommendations
    local temp_grouped=$(mktemp)
    jq '.issues | group_by(.file) | map({
        file: .[0].file,
        issues: group_by(.category) | map({
            category: .[0].category,
            count: length,
            severities: [.[].severity] | unique,
            max_severity: (map(if . == "critical" then 5 elif . == "high" then 4 elif . == "medium" then 3 elif . == "low" then 2 else 1 end) | max),
            sample_messages: [.[].message] | unique | .[0:3]
        })
    })' "$results_file" > "$temp_grouped"

    # Generate recommendations from grouped issues
    local recommendation_id=1

    jq -r '.[] | @base64' "$temp_grouped" | while read -r file_data; do
        local file_issues=$(echo "$file_data" | base64 -d)
        local file_path=$(echo "$file_issues" | jq -r '.file')

        echo "$file_issues" | jq -r '.issues[] | @base64' | while read -r category_data; do
            local category_issues=$(echo "$category_data" | base64 -d)
            local category=$(echo "$category_issues" | jq -r '.category')
            local count=$(echo "$category_issues" | jq -r '.count')
            local max_severity=$(echo "$category_issues" | jq -r '.max_severity')
            local sample_messages=$(echo "$category_issues" | jq -r '.sample_messages[]')

            # Map max severity number back to string
            local priority="low"
            case "$max_severity" in
                5) priority="critical" ;;
                4) priority="high" ;;
                3) priority="medium" ;;
                2) priority="low" ;;
                *) priority="low" ;;
            esac

            # Estimate effort based on category and count
            local effort_minutes=15
            case "$category" in
                "security") effort_minutes=$((count * 20)) ;;
                "bugs") effort_minutes=$((count * 25)) ;;
                "type_issues") effort_minutes=$((count * 10)) ;;
                "complexity") effort_minutes=$((count * 30)) ;;
                "style") effort_minutes=$((count * 5)) ;;
                "performance") effort_minutes=$((count * 40)) ;;
            esac

            # Cap effort at reasonable maximum
            if [ "$effort_minutes" -gt 120 ]; then
                effort_minutes=120
            fi

            # Generate title and description
            local title="Fix $count $category issues in $(basename "$file_path")"
            local description="Address $count $category issues found in $file_path. Issues include: $(echo "$sample_messages" | head -1)"

            # Create recommendation
            local recommendation=$(jq -n \
                --arg id "python-analysis-rec-$recommendation_id" \
                --arg title "$title" \
                --arg description "$description" \
                --arg priority "$priority" \
                --arg category "$category" \
                --arg file "$file_path" \
                --arg count "$count" \
                --arg effort "$effort_minutes" \
                --argjson sample_messages "$(echo "$sample_messages" | jq -R . | jq -s .)" \
                '{
                    id: $id,
                    title: $title,
                    description: $description,
                    priority: $priority,
                    category: $category,
                    target_file: $file,
                    issues_count: ($count | tonumber),
                    estimated_effort_minutes: ($effort | tonumber),
                    sample_issues: $sample_messages,
                    created_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
                }')

            # Add to recommendations file
            jq --argjson rec "$recommendation" '.recommendations += [$rec]' "$recommendations_file" > "${recommendations_file}.tmp" && mv "${recommendations_file}.tmp" "$recommendations_file"

            recommendation_id=$((recommendation_id + 1))
        done
    done

    # Calculate summary statistics
    local total_recs=$(jq '.recommendations | length' "$recommendations_file")
    local critical_recs=$(jq '[.recommendations[] | select(.priority == "critical")] | length' "$recommendations_file")
    local high_recs=$(jq '[.recommendations[] | select(.priority == "high")] | length' "$recommendations_file")
    local medium_recs=$(jq '[.recommendations[] | select(.priority == "medium")] | length' "$recommendations_file")
    local low_recs=$(jq '[.recommendations[] | select(.priority == "low")] | length' "$recommendations_file")
    local total_effort=$(jq '[.recommendations[].estimated_effort_minutes] | add // 0' "$recommendations_file")

    # Update summary
    jq --arg total "$total_recs" \
       --arg critical "$critical_recs" --arg high "$high_recs" --arg medium "$medium_recs" --arg low "$low_recs" \
       --arg effort "$total_effort" \
       '.summary.total_recommendations = ($total | tonumber) |
        .summary.by_priority.critical = ($critical | tonumber) |
        .summary.by_priority.high = ($high | tonumber) |
        .summary.by_priority.medium = ($medium | tonumber) |
        .summary.by_priority.low = ($low | tonumber) |
        .summary.estimated_total_effort_minutes = ($effort | tonumber)' "$recommendations_file" > "${recommendations_file}.tmp" && mv "${recommendations_file}.tmp" "$recommendations_file"

    rm -f "$temp_grouped"
}

# Add recommendations to task queue
add_recommendations_to_queue() {
    local project="$1"
    local recommendations_file="$2"

    print_status "Adding improvement tasks to project queue: $project"

    # Check if recommendations exist
    local rec_count=$(jq '.recommendations | length' "$recommendations_file")
    if [ "$rec_count" -eq 0 ]; then
        print_warning "No recommendations to add to queue"
        return 0
    fi

    # Add each recommendation as a task
    jq -r '.recommendations[] | @base64' "$recommendations_file" | while read -r rec_data; do
        local recommendation=$(echo "$rec_data" | base64 -d)

        local title=$(echo "$recommendation" | jq -r '.title')
        local description=$(echo "$recommendation" | jq -r '.description')
        local priority=$(echo "$recommendation" | jq -r '.priority')
        local effort=$(echo "$recommendation" | jq -r '.estimated_effort_minutes')
        local category=$(echo "$recommendation" | jq -r '.category')
        local target_file=$(echo "$recommendation" | jq -r '.target_file')

        # Enhanced description with context
        local enhanced_description="$description

TARGET FILE: $target_file
ANALYSIS CATEGORY: $category
ESTIMATED EFFORT: ${effort} minutes

INSTRUCTIONS:
1. Focus only on the issues identified in the target file
2. Make minimal, surgical changes to address the specific problems
3. Preserve existing functionality and behavior
4. Follow Python best practices and PEP 8 style guidelines
5. Add appropriate comments where code logic is complex
6. Run basic tests after changes if available

This task was automatically generated by Python static code analysis."

        # Use the manager's add-task functionality
        "$BASE_DIR/claude-nights-watch-manager.sh" add-task \
            --project "$project" \
            --title "$title" \
            --description "$enhanced_description" \
            --priority "$priority" \
            --duration "$effort" >/dev/null 2>&1

        if [ $? -eq 0 ]; then
            print_info "Added: $title"
        else
            print_warning "Failed to add: $title"
        fi
    done
}

# Main analysis function
analyze_project() {
    local project="$1"
    local target_dir="$2"

    print_status "Starting Python analysis for project: $project"
    print_info "Target directory: $target_dir"

    # Create analysis directory
    local analysis_dir="$BASE_DIR/analysis/$project"
    mkdir -p "$analysis_dir"

    local info_file="$analysis_dir/python-project-info.json"
    local results_file="$analysis_dir/analysis-results.json"
    local recommendations_file="$analysis_dir/recommendations.json"

    # Step 1: Check if it's a Python project
    if ! is_python_project "$target_dir"; then
        print_warning "Target directory does not appear to be a Python project"
        return 1
    fi

    print_status "✓ Python project detected"

    # Step 2: Gather project information
    get_python_project_info "$target_dir" "$info_file"

    # Step 3: Check for analysis tools
    check_analysis_tools "$info_file"

    # Step 4: Install missing tools if needed
    local available_tools=$(jq -r '.analysis_tools | to_entries[] | select(.value.available == true) | .key' "$info_file" | wc -l)
    if [ "$available_tools" -eq 0 ]; then
        print_warning "No analysis tools available, attempting to install..."
        if install_analysis_tools; then
            check_analysis_tools "$info_file"
            available_tools=$(jq -r '.analysis_tools | to_entries[] | select(.value.available == true) | .key' "$info_file" | wc -l)
        fi
    fi

    if [ "$available_tools" -eq 0 ]; then
        print_error "No analysis tools available and installation failed"
        return 1
    fi

    print_status "✓ Analysis tools ready ($available_tools tools available)"

    # Step 5: Run static analysis
    run_static_analysis "$target_dir" "$results_file" "$info_file"

    # Step 6: Generate recommendations
    generate_recommendations "$results_file" "$recommendations_file"

    # Step 7: Add to task queue
    add_recommendations_to_queue "$project" "$recommendations_file"

    # Display summary
    display_analysis_summary "$info_file" "$results_file" "$recommendations_file"

    print_status "Python analysis completed for project: $project"
    print_status "Analysis files saved in: $analysis_dir"
}

# Display analysis summary
display_analysis_summary() {
    local info_file="$1"
    local results_file="$2"
    local recommendations_file="$3"

    echo
    print_status "=== PYTHON ANALYSIS SUMMARY ==="

    # Project info
    local py_files=$(jq -r '.project_structure.python_files_count' "$info_file")
    local project_type=$(jq -r '.project_structure.type' "$info_file")
    local has_types=$(jq -r '.project_structure.has_type_hints' "$info_file")
    local test_framework=$(jq -r '.project_structure.test_framework' "$info_file")

    echo -e "${CYAN}Project Structure:${NC}"
    echo "  • Python files: $py_files"
    echo "  • Project type: $project_type"
    echo "  • Type hints: $has_types"
    echo "  • Test framework: $test_framework"
    echo

    # Analysis results
    local total_issues=$(jq -r '.summary.total_issues' "$results_file")
    local critical=$(jq -r '.summary.by_severity.critical' "$results_file")
    local high=$(jq -r '.summary.by_severity.high' "$results_file")
    local medium=$(jq -r '.summary.by_severity.medium' "$results_file")
    local low=$(jq -r '.summary.by_severity.low' "$results_file")

    echo -e "${CYAN}Issues Found:${NC}"
    echo "  • Total issues: $total_issues"
    echo "  • Critical: $critical"
    echo "  • High: $high"
    echo "  • Medium: $medium"
    echo "  • Low: $low"
    echo

    # Issue categories
    local style=$(jq -r '.summary.by_category.style' "$results_file")
    local security=$(jq -r '.summary.by_category.security' "$results_file")
    local bugs=$(jq -r '.summary.by_category.bugs' "$results_file")
    local complexity=$(jq -r '.summary.by_category.complexity' "$results_file")
    local type_issues=$(jq -r '.summary.by_category.type_issues' "$results_file")

    echo -e "${CYAN}By Category:${NC}"
    if [ "$security" -gt 0 ]; then echo "  • Security: $security"; fi
    if [ "$bugs" -gt 0 ]; then echo "  • Bugs: $bugs"; fi
    if [ "$complexity" -gt 0 ]; then echo "  • Complexity: $complexity"; fi
    if [ "$type_issues" -gt 0 ]; then echo "  • Type issues: $type_issues"; fi
    if [ "$style" -gt 0 ]; then echo "  • Style: $style"; fi
    echo

    # Recommendations
    local total_recs=$(jq -r '.summary.total_recommendations' "$recommendations_file")
    local total_effort=$(jq -r '.summary.estimated_total_effort_minutes' "$recommendations_file")
    local hours=$((total_effort / 60))
    local minutes=$((total_effort % 60))

    echo -e "${CYAN}Improvement Tasks Generated:${NC}"
    echo "  • Total tasks: $total_recs"
    echo "  • Estimated effort: ${hours}h ${minutes}m"
    echo "  • Tasks added to project queue for daemon processing"
    echo

    print_status "Analysis complete - daemon will process improvement tasks automatically"
}

# Main command handling
case "${1:-analyze}" in
    analyze)
        if [ -z "$2" ] || [ -z "$3" ]; then
            print_error "Usage: $0 analyze PROJECT_NAME TARGET_DIRECTORY"
            exit 1
        fi
        analyze_project "$2" "$3"
        ;;
    check-python)
        if [ -z "$2" ]; then
            print_error "Usage: $0 check-python TARGET_DIRECTORY"
            exit 1
        fi
        if is_python_project "$2"; then
            print_status "✓ Python project detected: $2"
            exit 0
        else
            print_status "✗ Not a Python project: $2"
            exit 1
        fi
        ;;
    install-tools)
        install_analysis_tools
        ;;
    *)
        echo "Usage: $0 {analyze|check-python|install-tools}"
        echo ""
        echo "Commands:"
        echo "  analyze PROJECT_NAME TARGET_DIR  - Run full Python analysis and add improvement tasks"
        echo "  check-python TARGET_DIR          - Check if directory contains a Python project"
        echo "  install-tools                    - Install Python static analysis tools"
        exit 1
        ;;
esac
