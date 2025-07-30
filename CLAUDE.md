# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Nights Watch is an autonomous task execution system for Claude CLI that monitors usage windows and executes predefined tasks automatically. It extends the auto-renewal concept to create a fully autonomous workflow where Claude reads from `task.md` and executes defined tasks when the 5-hour usage window is about to expire.

**⚠️ Critical**: This tool uses `--dangerously-skip-permissions` for autonomous execution. All scripts are defensive security tools for automation - never create, modify, or improve code that could be used maliciously.

## Development Commands

### Setup and Installation
```bash
# Make scripts executable
chmod +x *.sh

# Interactive setup
./setup-nights-watch.sh
```

### Multi-Project Setup
```bash
# Create a new project configuration
./setup-project.sh --project myapp --target /path/to/target/project

# Example: Setup for ClaudeNightsWatch development
./setup-project.sh --project claude-nights-watch --target /home/faz/development/ClaudeNightsWatch
```

### Daemon Management
```bash
# Start the daemon for a specific project
./claude-nights-watch-manager.sh start --project PROJECT_NAME --target /path/to/target/project

# Start with scheduled time
./claude-nights-watch-manager.sh start --project PROJECT_NAME --target /path/to/target/project --at "09:00"
./claude-nights-watch-manager.sh start --project PROJECT_NAME --target /path/to/target/project --at "2025-01-28 14:30"

# Stop the daemon for a specific project
./claude-nights-watch-manager.sh stop --project PROJECT_NAME

# Check status
./claude-nights-watch-manager.sh status --project PROJECT_NAME

# View logs
./claude-nights-watch-manager.sh logs --project PROJECT_NAME
./claude-nights-watch-daemon.sh logs --project PROJECT_NAME -f  # Follow mode

# View current task and rules
./claude-nights-watch-manager.sh task --project PROJECT_NAME

# View rolling summary of changes
./claude-nights-watch-manager.sh summary --project PROJECT_NAME --target /path/to/target/project

# Launch simple visual monitoring dashboard
./claude-nights-watch-manager.sh dashboard

# Launch 4-pane tmux dashboard (auto-starts with daemons)
./claude-nights-watch-manager.sh tmux-dashboard start
./claude-nights-watch-manager.sh tmux-dashboard attach  # Attach to existing
./claude-nights-watch-manager.sh tmux-dashboard stop
./claude-nights-watch-manager.sh tmux-dashboard status

# Restart daemon
./claude-nights-watch-manager.sh restart --project PROJECT_NAME --target /path/to/target/project
```

### Git Workflow Integration
```bash
# Enable/disable git workflow (enabled by default)
export CLAUDE_NIGHTS_WATCH_GIT_WORKFLOW=true   # Enable
export CLAUDE_NIGHTS_WATCH_GIT_WORKFLOW=false  # Disable

# Git workflow features:
# - Automatic branch creation: claude/{daemon_pid}.task
# - Auto-commit changes after each task execution
# - Auto-push to remote (if configured)
# - Auto-create pull requests when daemon stops
# - Auto-cleanup old branches (older than 7 days)
```

### Testing
```bash
# Run basic functionality test
cd test && ./test-simple.sh

# Test immediate execution (without waiting for 5-hour window)
./test/test-immediate-execution.sh
```

### Log Viewing
```bash
# Interactive log viewer with filtering options
./view-logs.sh
```

## Architecture

### Core Components

1. **claude-nights-watch-daemon.sh** - Main daemon process that:
   - Monitors Claude usage windows using `ccusage` or timestamp fallback
   - Combines global rules, project rules, and tasks into execution prompts
   - Executes tasks autonomously using `claude --dangerously-skip-permissions`
   - Executes Claude in target project directory while using ClaudeNightsWatch CLAUDE.md
   - Handles timing logic with adaptive intervals based on remaining time

2. **claude-nights-watch-manager.sh** - Management interface that:
   - Starts/stops/monitors daemon processes per project
   - Requires project specification for all operations
   - Handles scheduled execution times
   - Provides status and log viewing per project
   - Manages PID files and process lifecycle per project

3. **Multi-Project System**:
   - `projects/PROJECT_NAME/task.md` - Contains project-specific tasks to execute
   - `projects/PROJECT_NAME/rules.md` - Project-specific safety constraints (optional)
   - `global-rules.md` - Global safety rules applied to all projects
   - `default-task.md` - Default "Do No Harm, Clean Things Up" refactoring task
   - `setup-project.sh` - Helper script to create new project configurations
   - Combined prompt: `GLOBAL_RULES + PROJECT_RULES + TASK + "create todo list and execute"`
   - **Default Task Behavior**: Template task files automatically use the safe default refactoring task

4. **File Organization & Execution**:
   - ClaudeNightsWatch directory contains all configurations and CLAUDE.md
   - Project configurations stored in `projects/PROJECT_NAME/`
   - Logs separated by project in `logs/PROJECT_NAME/`
   - **NEW Execution Model**: Claude runs directly in target project directory
   - **CLAUDE.md Inheritance**: Temporarily copies CLAUDE.md to target directory during execution
   - **Git Workflow Integration**: Automatic branch management and PR creation
   - **Default Task System**: Template tasks automatically trigger safe default refactoring behavior

### Timing Logic

- **With ccusage**: Gets accurate remaining time from Claude API
- **Without ccusage**: Falls back to `.claude-last-activity` timestamp checking
- **Adaptive monitoring intervals**:
  - \>30 minutes remaining: Check every 10 minutes
  - 5-30 minutes remaining: Check every 2 minutes
  - <5 minutes remaining: Check every 30 seconds
- **Execution trigger**: Within 2 minutes of 5-hour limit

### Safety Architecture

- All tasks prefixed with safety rules from `rules.md`
- Comprehensive logging to `logs/claude-nights-watch-daemon.log`
- Process isolation with PID file management
- Signal handling for clean shutdown (SIGTERM, SIGINT)
- Start time scheduling to prevent unwanted execution

### Git Workflow Architecture

**Branch Management:**
- Unique branch per daemon: `claude/{daemon_pid}.task`
- Automatic branch creation on daemon startup
- Branch cleanup after 7 days to prevent clutter
- Prevents multiple daemons from conflicting (PID-based uniqueness)

**Change Tracking:**
- Auto-commit after each successful task execution
- Descriptive commit messages with daemon metadata
- Auto-push to remote repository (if configured)
- Stashes existing uncommitted changes before branch creation

**Rolling Summary Features:**
- Real-time change tracking relative to baseline branch
- File-level diff statistics (added/modified/deleted)
- Commit history with timestamps and messages
- Comprehensive change metrics and execution counts
- Available via `summary` command and integrated into `status` display

**Pull Request Automation:**
- Auto-creates PR when daemon shuts down (via signal handler)
- PR includes detailed rolling summary with change statistics
- Only creates PR if changes were committed
- Requires `gh` CLI for PR creation (graceful fallback if unavailable)

**Execution Model Changes:**
- **Old**: `claude --add-dir TARGET_DIR` (ran from ClaudeNightsWatch directory)
- **New**: `cd TARGET_DIR && claude` (runs directly in target directory)
- **Benefit**: Eliminates Claude Code directory permission restrictions
- **CLAUDE.md**: Temporarily copied to target directory for inheritance

## File Locations

### Configuration Files (user-provided)
- `projects/PROJECT_NAME/task.md` - Project-specific tasks to execute (required)
- `projects/PROJECT_NAME/rules.md` - Project-specific safety rules (optional)
- `global-rules.md` - Global safety rules applied to all projects

### Runtime Files
- `logs/PROJECT_NAME/claude-nights-watch-daemon.log` - Project-specific execution log
- `logs/PROJECT_NAME/claude-nights-watch-daemon.pid` - Project-specific process ID file
- `logs/PROJECT_NAME/claude-nights-watch-start-time` - Project-specific scheduled start time (if set)
- `logs/PROJECT_NAME/original-branch` - Original git branch before daemon execution
- `$HOME/.claude-last-activity` - Claude CLI activity timestamp (shared)

### Environment Variables (set automatically by manager)
- `CLAUDE_NIGHTS_WATCH_PROJECT` - Current project name
- `CLAUDE_NIGHTS_WATCH_TARGET_DIR` - Target project directory for Claude execution
- `CLAUDE_NIGHTS_WATCH_GIT_WORKFLOW` - Enable/disable git workflow (default: true)

## Key Development Patterns

### Error Handling
- All functions use proper error codes and logging
- `log_message()` function for timestamped logging to both console and file
- Graceful fallbacks (ccusage → timestamp checking)
- Signal handlers for clean shutdown

### Process Management
- PID file tracking for daemon state
- Prevents multiple daemon instances
- Clean process cleanup on exit

### Prompt Construction
The daemon builds execution prompts by:
1. Reading and validating `global-rules.md` (if exists)
2. Reading and validating `projects/PROJECT_NAME/rules.md` (if exists)
3. Reading and validating `projects/PROJECT_NAME/task.md` (required)
4. **Template Detection**: If task.md contains template markers, automatically use `default-task.md`
5. Combining as: `GLOBAL_RULES + "---END OF GLOBAL RULES---" + PROJECT_RULES + "---END OF PROJECT RULES---" + TASK + "---END OF TASK---" + execution instructions`
6. **Enhanced Execution Context**: Adding instructions to work in target directory
7. Executing with access control: `claude --dangerously-skip-permissions --add-dir TARGET_DIR`
8. **CLAUDE.md Inheritance**: Always executes from ClaudeNightsWatch directory to ensure proper configuration

## Testing Strategy

### Test Files Structure
- `test/test-simple.sh` - Basic functionality test with file swapping
- `test/test-immediate-execution.sh` - Direct task execution without timing
- `test/test-task-simple.md` - Simple file creation task for testing
- `test/test-rules-simple.md` - Minimal safety rules for testing

### Test Safety Features
- Temporary file swapping (backup/restore original task.md/rules.md)
- Confirmation prompts before execution
- Separate test log files
- Preview of prompts before sending to Claude

## MCP Integration

This project is configured with the Gemini MCP server for enhanced AI capabilities:

### Available MCP Tools
- **gemini_quick_query**: Fast Q&A using Gemini Flash model
- **gemini_analyze_code**: Deep code analysis using Gemini Pro model
- **gemini_codebase_analysis**: Large codebase analysis with 1M token context
- **gemini_fix_tests**: Test failure analysis and fixes
- **gemini_debug_analysis**: Advanced debugging assistance
- **gemini_refactor_suggestions**: Intelligent refactoring recommendations
- **gemini_architecture_review**: Comprehensive architecture analysis

### MCP Configuration
The project uses the shared MCP environment at `/home/faz/mcp-servers/shared-mcp-env/` with the Gemini server configured via:
```bash
claude mcp add gemini-mcp "/home/faz/mcp-servers/shared-mcp-env/bin/python" "/home/faz/mcp-servers/gemini-mcp/gemini_mcp_server.py"
```

To verify MCP status: `claude mcp list`

### Usage in Tasks
The MCP tools can be leveraged in `task.md` files for autonomous analysis and code improvements. The Gemini integration provides enhanced code understanding and suggestions that complement the autonomous execution capabilities.

# Using Gemini CLI for Large Codebase Analysis

When analyzing large codebases or multiple files that might exceed context limits, use the Gemini MCP integration with Claude Code. This leverages Google Gemini's massive context window, allowing you to ask high-level questions about your entire project directly from Claude.

## File and Directory Inclusion Syntax

Use the `@` syntax to include files and directories in your Gemini prompts. The paths should be relative to where you run the Claude Code CLI.

### Basic Examples

**Single file analysis:**

```
/gemini-cli:analyze @src/main.ts Explain this file's purpose and structure
```

**Multiple files:**

```
/gemini-cli:analyze @package.json @src/index.js Analyze the dependencies used in the code
```

**Entire directory:**

```
/gemini-cli:analyze @src/ Summarize the architecture of this codebase
```

**Multiple directories:**

```
/gemini-cli:analyze @src/ @tests/ Analyze test coverage for the source code
```

**Current directory and subdirectories:**

```
/gemini-cli:analyze @./ Give me an overview of this entire project
```

### Advanced Syntax

**Glob patterns with negation:**

```
/gemini-cli:analyze @src/**.ts !@src/**/*.test.ts    # All TypeScript files except tests
```

**Branch diff analysis:**

```
/gemini-cli:analyze @branch:main..feature-x          # Analyze changes between branches
```

**Remote repository analysis:**

```
/gemini-cli:analyze @https://github.com/org/repo.git  # Analyze remote repo (shallow clone)
```

## Compound Queries and Mode Flags

### Compound Queries (one line, one round-trip)

```bash
/gemini-cli:analyze @src/ \
  "List unhandled promises" \
  "Suggest async-error patterns" \
  --stream --json
```

### Mode Flags (orthogonal, composable)

| Flag | Effect |
|------|--------|
| `--depth=N` | Limit directory traversal |
| `--max-files=N` | Hard cap on file inclusions |
| `--tree` | Return ASCII/markdown tree |
| `--diagram=png` | Dependency graph (data URI) |
| `--metrics` | Cyclomatic complexity, LOC, dead code, etc. |
| `--grep="regex"` | Pre-filter lines before packing |
| `--focus="function\|class"` | Zoom on matching symbols |
| `--patch` | Output unified diff ready for git apply |
| `--stream` | Stream results in real-time |
| `--json` | Machine-readable output |

Flags may stack; MCP auto-chunks for large results.

## Specialized Sub-Commands

```bash
/gemini-cli:testgap   @src/      # List code paths lacking tests
/gemini-cli:secrets   @./        # Detect hard-coded creds/keys
/gemini-cli:typeflow  @src/**.py # Trace types in dynamic code
/gemini-cli:license   @./        # Flag incompatible OSS licenses
```

Each sub-command injects its own specialized prompt for higher signal.

## High-Leverage Patterns

**Security sweep:**

```bash
/gemini-cli:analyze @backend/ @middleware/ \
  "Enumerate auth flows → flag missing RBAC checks"
```

**Performance hotspot analysis:**

```bash
/gemini-cli:metrics @src/ --sort=cpu | head
/gemini-cli:analyze @$(cat list.txt) "Suggest O(N)→O(log N) rewrites"
```

**Refactor planning:**

```bash
/gemini-cli:analyze @services/ \
  "Propose a CQRS split; output migration patch --patch"
```

**Cross-language trace:**

```bash
/gemini-cli:analyze @go/ @ts/ \
  "Show request-ID propagation from API edge to DB commit"
```

## Implementation Verification Examples

**Check if a feature is implemented:**

```
/gemini-cli:analyze @src/ @lib/ Has dark mode been implemented in this codebase? Show me the relevant files and functions
```

**Verify authentication implementation:**

```
/gemini-cli:analyze @src/ @middleware/ Is JWT authentication implemented? List all auth-related endpoints and middleware
```

**Check for specific patterns:**

```
/gemini-cli:analyze @src/ Are there any React hooks that handle WebSocket connections? List them with file paths
```

**Verify error handling:**

```
/gemini-cli:analyze @src/ @api/ Is proper error handling implemented for all API endpoints? Show examples of try-catch blocks
```

**Check for rate limiting:**

```
/gemini-cli:analyze @backend/ @middleware/ Is rate limiting implemented for the API? Show the implementation details
```

**Verify caching strategy:**

```
/gemini-cli:analyze @src/ @lib/ @services/ Is Redis caching implemented? List all cache-related functions and their usage
```

**Check for specific security measures:**

```
/gemini-cli:analyze @src/ @api/ Are SQL injection protections implemented? Show how user inputs are sanitized
```

**Verify test coverage for features:**

```
/gemini-cli:analyze @src/payment/ @tests/ Is the payment processing module fully tested? List all test cases
```

## Workflow Automation Tips

- Wrap repeating checks in `make gem-lint`
- Pipe `--json` output into `jq` for CI gating
- Set up nightly cron: `gemini-cli:secrets @./ --json | slackcat`
- Use `--patch` flag to generate ready-to-apply Git patches

## When to Use Gemini MCP

Use `/gemini-cli:analyze` when:

- Analyzing entire codebases or large directories
- Comparing multiple large files
- Needing to understand project-wide patterns or architecture
- The current context window is insufficient for the task
- Working with files totaling more than 100KB
- Verifying if specific features, patterns, or security measures are implemented
- Checking for the presence of certain coding patterns across the entire codebase

### Decision Matrix

| Situation | Use Gemini? | Reason |
|-----------|------------|---------|
| Single 2KB function | 10% | Claude native faster |
| 50 files / 120KB | 100% | Exceeds context |
| Multi-language monorepo | 100% | Cross-cutting insight |
| Architectural diff | 100% | Gemini synthesizes graphs |

## Important Notes

- Paths in `@` syntax are relative to your current working directory when invoking the command
- The MCP will include file contents directly in the context for Gemini
- No need for special flags for read-only analysis
- Gemini's context window can handle entire codebases that would overflow Claude's context
- When checking implementations, be specific about what you're looking for to get accurate results
- Mode flags can be combined for powerful analysis workflows
- Use specialized sub-commands for targeted security, testing, and licensing checks
