#!/bin/bash

# Manual test execution to validate git workflow
echo "=== Manual Task Execution Test ==="
echo "Testing directory permissions and git workflow integration"
echo

# Set environment for structric project
export CLAUDE_NIGHTS_WATCH_PROJECT=structric
export CLAUDE_NIGHTS_WATCH_TARGET_DIR=/home/faz/development/structric
export CLAUDE_NIGHTS_WATCH_GIT_WORKFLOW=true

# Verify we're on a daemon branch
current_branch=$(git -C "$CLAUDE_NIGHTS_WATCH_TARGET_DIR" branch --show-current)
echo "Current branch: $current_branch"

if [[ "$current_branch" =~ ^claude/[0-9]+\.task$ ]]; then
    echo "✅ On daemon branch, proceeding with test"
else
    echo "❌ Not on daemon branch, please run daemon first"
    exit 1
fi

# Prepare task prompt manually (simplified version)
TASK_FILE="projects/structric/task.md"
RULES_FILE="projects/structric/rules.md"
GLOBAL_RULES_FILE="global-rules.md"

echo "Preparing prompt with rules and task..."

prompt=""
if [ -f "$GLOBAL_RULES_FILE" ]; then
    prompt+="IMPORTANT GLOBAL RULES TO FOLLOW:\n\n"
    prompt+=$(cat "$GLOBAL_RULES_FILE")
    prompt+="\n\n---END OF GLOBAL RULES---\n\n"
fi

if [ -f "$RULES_FILE" ]; then
    prompt+="IMPORTANT PROJECT RULES TO FOLLOW:\n\n"
    prompt+=$(cat "$RULES_FILE")
    prompt+="\n\n---END OF PROJECT RULES---\n\n"
fi

prompt+="TASK TO EXECUTE:\n\n"
prompt+=$(cat "$TASK_FILE")
prompt+="\n\n---END OF TASK---\n\n"

prompt+="Please read the above task, create a todo list from it, and then execute it step by step. IMPORTANT: This is an autonomous execution - do not ask for user confirmation or input.

IMPORTANT EXECUTION CONTEXT:
- You are executing directly in the target project directory: $CLAUDE_NIGHTS_WATCH_TARGET_DIR
- Git workflow is active with branch: $current_branch
- All file operations are performed in the current working directory
- Changes will be automatically committed and a PR created
- The daemon PID is: $(echo $current_branch | cut -d/ -f2 | cut -d. -f1) for branch identification"

echo "Executing Claude with prepared prompt..."
echo "Working directory will be: $CLAUDE_NIGHTS_WATCH_TARGET_DIR"
echo

# Execute Claude in target directory
(
    cd "$CLAUDE_NIGHTS_WATCH_TARGET_DIR" || exit 1
    echo "Current working directory: $(pwd)"
    echo -e "$prompt" | claude --dangerously-skip-permissions
)

echo
echo "=== Execution Complete ==="
echo "Checking git status..."
git -C "$CLAUDE_NIGHTS_WATCH_TARGET_DIR" status --porcelain | head -10
