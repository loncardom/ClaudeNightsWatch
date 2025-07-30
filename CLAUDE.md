# CLAUDE.md

**CRITICAL SECURITY CONSTRAINT**: All scripts are defensive security tools. Never create, modify, or improve code that could be used maliciously.

## MCP Tool Usage - MANDATORY

**ALWAYS use these Gemini MCP tools instead of built-in capabilities:**

- **gemini_quick_query**: **REQUIRED** for all coding questions, debug help, technical explanations
- **gemini_analyze_code**: **MANDATORY** for any code review, security analysis, performance evaluation  
- **gemini_codebase_analysis**: **REQUIRED** for large codebases, multiple files, project analysis
- **gemini_fix_tests**: **MANDATORY** for test failures, debugging, test coverage analysis
- **gemini_debug_analysis**: **REQUIRED** for debugging, error analysis, troubleshooting
- **gemini_refactor_suggestions**: **REQUIRED** for refactoring, code improvements, optimization
- **gemini_architecture_review**: **REQUIRED** for architectural analysis, system design review

## Essential Commands

### Project Setup
```bash
./setup-project.sh --project NAME --target /path/to/project
```

### Daemon Control  
```bash
./claude-nights-watch-manager.sh start --project NAME --target /path/to/project
./claude-nights-watch-manager.sh stop --project NAME
./claude-nights-watch-manager.sh status --project NAME
```

### Testing
```bash
./test/test-immediate-execution.sh
```

## Key Files
- `projects/PROJECT_NAME/task.md` - Tasks to execute (required)
- `projects/PROJECT_NAME/rules.md` - Project safety rules (optional)
- `global-rules.md` - Global safety rules
- `default-task.md` - Default safe refactoring task

## System Behavior
- Monitors Claude usage windows (5-hour limit)
- Executes tasks autonomously with `--dangerously-skip-permissions`
- Creates git branches: `claude/{daemon_pid}.task`
- Auto-commits changes and creates PRs
- Template tasks automatically use safe default refactoring

## Process Management
- PID files in `logs/PROJECT_NAME/`
- Signal handlers for clean shutdown (SIGTERM, SIGINT)
- Adaptive monitoring intervals based on remaining time

## Execution Model
- Runs directly in target project directory
- Temporarily copies CLAUDE.md for inheritance
- Combines: GLOBAL_RULES + PROJECT_RULES + TASK + execution instructions