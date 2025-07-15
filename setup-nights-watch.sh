#!/bin/bash

# Claude Nights Watch Setup Script
# Interactive setup for autonomous task execution

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MANAGER_SCRIPT="$(cd "$(dirname "$0")" && pwd)/claude-nights-watch-manager.sh"
TASK_FILE="task.md"
RULES_FILE="rules.md"

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}Claude Nights Watch Setup${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

check_claude() {
    if command -v claude &> /dev/null; then
        print_success "Claude CLI found"
        return 0
    else
        print_error "Claude CLI not found"
        echo "Please install Claude CLI first: https://docs.anthropic.com/en/docs/claude-code/quickstart"
        return 1
    fi
}

check_ccusage() {
    if command -v ccusage &> /dev/null || command -v bunx &> /dev/null || command -v npx &> /dev/null; then
        print_success "ccusage available (for accurate timing)"
        return 0
    else
        print_warning "ccusage not found (will use time-based checking)"
        echo "To install ccusage: npm install -g ccusage"
        return 0  # Not a fatal error
    fi
}

create_task_file() {
    if [ -f "$TASK_FILE" ]; then
        print_warning "task.md already exists"
        read -p "Do you want to view/edit it? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${EDITOR:-nano} "$TASK_FILE"
        fi
    else
        echo ""
        echo "Creating task.md file..."
        echo "Enter your task (press Ctrl+D when done):"
        echo ""
        cat > "$TASK_FILE"
        print_success "Created task.md"
    fi
}

create_rules_file() {
    if [ -f "$RULES_FILE" ]; then
        print_warning "rules.md already exists"
        read -p "Do you want to view/edit it? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${EDITOR:-nano} "$RULES_FILE"
        fi
    else
        echo ""
        read -p "Do you want to create safety rules? (recommended) (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cat > "$RULES_FILE" << 'EOF'
# Safety Rules for Claude Nights Watch

## CRITICAL RULES - NEVER VIOLATE THESE:

1. **NO DESTRUCTIVE COMMANDS**: Never run commands that could delete or damage files:
   - No `rm -rf` commands
   - No deletion of system files
   - No modifications to system configurations

2. **NO SENSITIVE DATA**: Never:
   - Access or expose passwords, API keys, or secrets
   - Commit sensitive information to repositories
   - Log sensitive data

3. **NO NETWORK ATTACKS**: Never perform:
   - Port scanning
   - DDoS attempts
   - Unauthorized access attempts

4. **STAY IN PROJECT SCOPE**: 
   - Only work within the designated project directory
   - Do not access or modify files outside the project

5. **GIT SAFETY**:
   - Never force push to main/master branches
   - Always create feature branches for changes
   - Never rewrite published history

## BEST PRACTICES:

1. **TEST BEFORE PRODUCTION**: Always test changes in a safe environment
2. **BACKUP IMPORTANT DATA**: Create backups before major changes
3. **DOCUMENT CHANGES**: Keep clear records of what was modified
4. **RESPECT RATE LIMITS**: Don't overwhelm external services
5. **ERROR HANDLING**: Implement proper error handling and logging

## ALLOWED ACTIONS:

- Create and modify project files
- Run tests and builds
- Create git commits on feature branches
- Install project dependencies
- Generate documentation
- Refactor code
- Fix bugs
- Add new features as specified
EOF
            print_success "Created rules.md with default safety rules"
            echo ""
            read -p "Do you want to edit the rules? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                ${EDITOR:-nano} "$RULES_FILE"
            fi
        fi
    fi
}

setup_daemon() {
    echo ""
    echo "=== Daemon Configuration ==="
    echo ""
    
    read -p "Do you want to start the daemon after setup? (y/n) " -n 1 -r
    echo
    START_NOW=$REPLY
    
    if [[ $START_NOW =~ ^[Yy]$ ]]; then
        read -p "Do you want to schedule a start time? (y/n) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Enter start time (HH:MM for today, or YYYY-MM-DD HH:MM):"
            read START_TIME
            START_ARGS="--at $START_TIME"
        else
            START_ARGS=""
        fi
    fi
}

main() {
    print_header
    
    # Check prerequisites
    echo "Checking prerequisites..."
    check_claude || exit 1
    check_ccusage
    echo ""
    
    # Create/edit task file
    echo "=== Task Configuration ==="
    create_task_file
    echo ""
    
    # Create/edit rules file
    echo "=== Safety Rules Configuration ==="
    create_rules_file
    echo ""
    
    # Setup daemon
    setup_daemon
    
    # Summary
    echo ""
    echo "=== Setup Complete ==="
    print_success "Task file: $(pwd)/$TASK_FILE"
    if [ -f "$RULES_FILE" ]; then
        print_success "Rules file: $(pwd)/$RULES_FILE"
    fi
    print_success "Manager: $MANAGER_SCRIPT"
    echo ""
    
    # Show available commands
    echo "Available commands:"
    echo "  ./claude-nights-watch-manager.sh start    - Start the daemon"
    echo "  ./claude-nights-watch-manager.sh stop     - Stop the daemon"
    echo "  ./claude-nights-watch-manager.sh status   - Check daemon status"
    echo "  ./claude-nights-watch-manager.sh logs     - View logs"
    echo "  ./claude-nights-watch-manager.sh task     - View current task"
    echo ""
    
    # Start daemon if requested
    if [[ $START_NOW =~ ^[Yy]$ ]]; then
        echo "Starting daemon..."
        "$MANAGER_SCRIPT" start $START_ARGS
    else
        echo "To start the daemon later, run:"
        echo "  ./claude-nights-watch-manager.sh start"
    fi
    
    echo ""
    print_warning "Remember: The daemon will execute tasks autonomously!"
    print_warning "Always review your task.md and rules.md files carefully."
}

# Run main function
main