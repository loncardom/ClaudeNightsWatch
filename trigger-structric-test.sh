#!/bin/bash

# Immediate execution of Structric task for testing

BASE_DIR="/home/faz/development/ClaudeNightsWatch"
PROJECT_NAME="structric"
TARGET_DIR="/home/faz/development/structric"

echo "=== Structric Immediate Test Execution ==="
echo "This will execute the Structric file existence check task immediately"
echo ""

cd "$BASE_DIR"

# Set up environment
export CLAUDE_NIGHTS_WATCH_PROJECT="$PROJECT_NAME"
export CLAUDE_NIGHTS_WATCH_TARGET_DIR="$TARGET_DIR"

# Build prompt like daemon would
GLOBAL_RULES=$(cat "global-rules.md")
PROJECT_RULES=$(cat "projects/$PROJECT_NAME/rules.md")
TASK_CONTENT=$(cat "projects/$PROJECT_NAME/task.md")

FULL_PROMPT="IMPORTANT GLOBAL RULES TO FOLLOW:

$GLOBAL_RULES

---END OF GLOBAL RULES---

PROJECT-SPECIFIC RULES TO FOLLOW:

$PROJECT_RULES

---END OF PROJECT RULES---

TASK TO EXECUTE:

$TASK_CONTENT

---END OF TASK---

Please read the above task, create a todo list from it, and then execute it step by step. IMPORTANT: This is an autonomous execution - do not ask for user confirmation or input.

IMPORTANT EXECUTION CONTEXT:
- You are running from the ClaudeNightsWatch directory but should work in: $TARGET_DIR
- Use 'cd $TARGET_DIR' at the start of your work
- The target project directory is accessible via --add-dir
- Always work within the target project directory for file operations
- Return to the target directory if you change directories during execution"

echo "Target directory: $TARGET_DIR"
echo "Expected output file: $TARGET_DIR/nights-watch-access-test.md"
echo ""

read -p "Execute Structric task immediately? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 Executing Structric task..."
    echo "==============================="

    echo "$FULL_PROMPT" | claude --dangerously-skip-permissions --add-dir "$TARGET_DIR"

    echo ""
    echo "==============================="
    echo "✅ Execution complete!"

    # Check for the expected output file
    if [ -f "$TARGET_DIR/nights-watch-access-test.md" ]; then
        echo ""
        echo "✅ SUCCESS: nights-watch-access-test.md was created!"
        echo ""
        echo "File content preview:"
        head -20 "$TARGET_DIR/nights-watch-access-test.md"
        echo ""
        echo "Full file location: $TARGET_DIR/nights-watch-access-test.md"
    else
        echo ""
        echo "❌ nights-watch-access-test.md was not created"
        echo "Files in target directory:"
        ls -la "$TARGET_DIR" | head -10
    fi
else
    echo "Test cancelled"
fi
