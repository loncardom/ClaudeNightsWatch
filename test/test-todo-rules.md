  # Safety Rules for Todo App Test

## CRITICAL SAFETY RULES:

### 1. Directory Restrictions
- **ONLY** create files within the `simple-todo-app` subdirectory
- **NEVER** modify files outside of this project directory
- **NEVER** access parent directories or system files

### 2. File Operations
- **ONLY** create these specific files:
  - `simple-todo-app/todo.py`
  - `simple-todo-app/test_todo.py`
  - `simple-todo-app/README.md`
  - `simple-todo-app/todos.json`
  - `simple-todo-app/IMPLEMENTATION_REPORT.md`
- **NEVER** delete any existing files
- **ALWAYS** use safe file operations with proper error handling

### 3. Command Restrictions
- **NEVER** use `sudo` or administrative commands
- **NEVER** install global packages
- **ONLY** use Python standard library (no pip installs)
- **NEVER** modify system Python or environment

### 4. Testing Rules
- **ALWAYS** run tests in isolated manner
- **NEVER** leave test artifacts outside the project directory
- **CLEAN UP** any temporary files after testing

### 5. Git Rules (if needed)
- **DO NOT** initialize git repositories
- **DO NOT** make any commits
- **ONLY** work with local files

## ALLOWED ACTIONS:

1. Create the `simple-todo-app` directory
2. Write Python code using only standard library
3. Create and modify files within the project directory
4. Run Python scripts for testing
5. Read and write JSON files
6. Generate documentation

## EXECUTION GUIDELINES:

1. Start by creating the project directory
2. Implement features incrementally
3. Test each feature after implementation
4. Document all functions properly
5. Create a comprehensive implementation report

## OUTPUT REQUIREMENTS:

At the end of execution, ensure these files exist:
- `simple-todo-app/todo.py` - Main application
- `simple-todo-app/test_todo.py` - Test suite
- `simple-todo-app/README.md` - Documentation
- `simple-todo-app/todos.json` - Sample data file
- `simple-todo-app/IMPLEMENTATION_REPORT.md` - Summary of what was done

## LOGGING:

- Log each major step completed
- Report any errors encountered
- Summarize the final state of the project
