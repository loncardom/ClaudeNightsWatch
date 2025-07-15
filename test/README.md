# Testing Claude Nights Watch

This directory contains test scripts and sample files for testing Claude Nights Watch functionality.

## Test Files

### Scripts
- `test-immediate-execution.sh` - Run a single task immediately without waiting for the 5-hour window
- `test-simple.sh` - Quick test with a simple task to verify basic functionality

### Sample Tasks
- `test-task-simple.md` - Simple file creation task for basic testing
- `test-rules-simple.md` - Minimal safety rules for the simple test

## Running Tests

### 1. Basic Functionality Test

From the test directory:
```bash
./test-simple.sh
```

This will:
- Copy test task/rules to the main directory
- Execute the task immediately
- Clean up after completion
- Show you where to find the logs

### 2. Manual Test Execution

To test with your own task:
```bash
cd ..  # Go to main directory
cp test/test-immediate-execution.sh .
./test-immediate-execution.sh
```

### 3. Testing the Daemon

To test the full daemon workflow:
```bash
cd ..  # Go to main directory
# Create your task.md and rules.md
./claude-nights-watch-manager.sh start
# Monitor with: ./claude-nights-watch-manager.sh status
```

## Test Safety

The test scripts include safety features:
- Preview prompts before execution
- Ask for confirmation
- Log everything to `logs/` directory
- Use restricted test rules to prevent unwanted actions

## Troubleshooting Tests

If tests fail:
1. Check logs in `../logs/claude-nights-watch-test.log`
2. Verify Claude CLI is installed: `which claude`
3. Ensure you have active Claude usage: `ccusage blocks`
4. Check file permissions: all `.sh` files should be executable

## Creating Your Own Tests

1. Create a new task file: `my-test-task.md`
2. Create corresponding rules: `my-test-rules.md`
3. Copy and modify `test-simple.sh` to use your files
4. Run and check logs for results