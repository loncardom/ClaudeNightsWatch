#!/bin/bash

# Claude Nights Watch - Project Setup Helper
# Creates a new project configuration directory with template files

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME=""
TARGET_DIR=""

print_usage() {
    echo "Claude Nights Watch - Project Setup Helper"
    echo ""
    echo "Usage: $0 --project PROJECT_NAME --target /path/to/target/project"
    echo ""
    echo "This script creates a new project configuration in projects/PROJECT_NAME/"
    echo "with template task.md and rules.md files."
    echo ""
    echo "Parameters:"
    echo "  --project NAME  - Name for the new project configuration"
    echo "  --target DIR    - Path to the target project directory"
    echo ""
    echo "Example:"
    echo "  $0 --project myapp --target /home/user/projects/myapp"
}

# Parse parameters
while [ $# -gt 0 ]; do
    case "$1" in
        --project)
            if [ -n "$2" ]; then
                PROJECT_NAME="$2"
                shift 2
            else
                echo "ERROR: Missing project name for --project parameter"
                exit 1
            fi
            ;;
        --target)
            if [ -n "$2" ]; then
                TARGET_DIR="$2"
                shift 2
            else
                echo "ERROR: Missing target directory for --target parameter"
                exit 1
            fi
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown parameter: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validate parameters
if [ -z "$PROJECT_NAME" ]; then
    echo "ERROR: Project name is required"
    print_usage
    exit 1
fi

if [ -z "$TARGET_DIR" ]; then
    echo "ERROR: Target directory is required"
    print_usage
    exit 1
fi

# Validate target directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "ERROR: Target directory does not exist: $TARGET_DIR"
    exit 1
fi

# Create project configuration directory
PROJECT_CONFIG_DIR="$BASE_DIR/projects/$PROJECT_NAME"

if [ -d "$PROJECT_CONFIG_DIR" ]; then
    echo "ERROR: Project '$PROJECT_NAME' already exists at $PROJECT_CONFIG_DIR"
    exit 1
fi

echo "Creating project configuration for '$PROJECT_NAME'..."
mkdir -p "$PROJECT_CONFIG_DIR"

# Create template task.md
cat > "$PROJECT_CONFIG_DIR/task.md" << 'EOF'
# Project Tasks

Define your autonomous tasks here. These will be executed by Claude when the 5-hour usage window is about to expire.

## Example Tasks

1. **Status Check**
   - Check git status
   - Review recent changes
   - Ensure working directory is clean

2. **Maintenance Tasks**
   - Run tests if available
   - Check for dependency updates
   - Generate status reports

## Important Notes

- Tasks should be safe for autonomous execution
- Avoid destructive operations
- Focus on maintenance, monitoring, and status tasks
- Test your tasks manually before deploying

## Default Task Behavior

If you don't replace this template with actual project tasks, Claude Nights Watch will automatically use the default "Do No Harm, Clean Things Up" refactoring task. This default task performs safe, language-agnostic cleanup operations using git branches for safety.

Replace this template with your actual project tasks to override the default behavior.
EOF

# Create template rules.md
cat > "$PROJECT_CONFIG_DIR/rules.md" << EOF
# Project-Specific Rules for $PROJECT_NAME

These rules supplement the global safety rules and are specific to this project.

## Project Context

**Project Name:** $PROJECT_NAME
**Target Directory:** $TARGET_DIR
**Risk Level:** [Low/Medium/High - update as appropriate]

## Project-Specific Constraints

**File Operations:**
- [Define which files can be modified]
- [Specify any off-limits directories]
- [List backup requirements]

**Commands Allowed:**
- [List safe commands for this project]
- [Specify any project-specific tools]

**Reporting Requirements:**
- [Define what information to log]
- [Specify status reporting format]

## Project Notes

- [Add any project-specific context]
- [Document project structure if relevant]
- [Include contact information if needed]

Remember: These rules work alongside the global rules. Global rules always take precedence.
EOF

# Create project-specific log directory
mkdir -p "$BASE_DIR/logs/$PROJECT_NAME"

echo "✅ Project '$PROJECT_NAME' created successfully!"
echo ""
echo "Configuration created at: $PROJECT_CONFIG_DIR"
echo "Target directory: $TARGET_DIR"
echo "Logs will be stored in: $BASE_DIR/logs/$PROJECT_NAME"
echo ""
echo "Default Task Behavior:"
echo "📋 If you leave the template task.md unchanged, Claude will automatically use"
echo "   the default 'Do No Harm, Clean Things Up' refactoring task which performs"
echo "   safe, language-agnostic cleanup operations using git branches."
echo ""
echo "Next steps:"
echo "1. Edit $PROJECT_CONFIG_DIR/task.md with your actual tasks (or leave as-is for default behavior)"
echo "2. Customize $PROJECT_CONFIG_DIR/rules.md for your project"
echo "3. Test your configuration with:"
echo "   $BASE_DIR/claude-nights-watch-manager.sh start --project $PROJECT_NAME --target $TARGET_DIR"
echo ""
echo "Useful commands:"
echo "- View task: $BASE_DIR/claude-nights-watch-manager.sh task --project $PROJECT_NAME"
echo "- Check status: $BASE_DIR/claude-nights-watch-manager.sh status --project $PROJECT_NAME"
echo "- View logs: $BASE_DIR/claude-nights-watch-manager.sh logs --project $PROJECT_NAME"
