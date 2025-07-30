# Task: Create a Simple Todo List Application

## Objective
Build a basic command-line todo list application in Python with the following features:

## Requirements

### 1. Create Project Structure
- Create a directory called `simple-todo-app`
- Create the main Python file: `todo.py`
- Create a README.md with usage instructions

### 2. Implement Core Features
The todo app should support these commands:
- `add "task description"` - Add a new todo item
- `list` - Display all todo items with their IDs
- `done <id>` - Mark a todo item as completed
- `delete <id>` - Remove a todo item
- `help` - Show available commands

### 3. Data Storage
- Store todos in a JSON file called `todos.json`
- Each todo should have: id, description, completed status, created_at timestamp

### 4. Code Quality
- Add proper error handling for file operations
- Include input validation
- Add helpful error messages

### 5. Testing
- Create a test file `test_todo.py` with at least 5 test cases
- Test adding, listing, completing, and deleting todos
- Test error cases (invalid IDs, empty inputs)

### 6. Documentation
- Add docstrings to all functions
- Create clear usage examples in README.md
- Include installation instructions

## Deliverables
1. Working todo.py application
2. test_todo.py with passing tests
3. README.md with complete documentation
4. todos.json sample file
5. Create a summary report of what was implemented

Please implement this step by step, testing each feature as you go.
