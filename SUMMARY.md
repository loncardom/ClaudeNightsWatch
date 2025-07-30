# Claude Nights Watch - Repository Summary

## What's Included

### Core Scripts
- **claude-nights-watch-daemon.sh** - The main daemon that monitors Claude usage and executes tasks
- **claude-nights-watch-manager.sh** - Control interface (start/stop/status/logs)
- **setup-nights-watch.sh** - Interactive setup wizard
- **view-logs.sh** - Interactive log viewer with filtering capabilities

### Documentation
- **README.md** - Complete user guide and documentation
- **LICENSE** - MIT License
- **CONTRIBUTING.md** - Guidelines for contributors
- **.gitignore** - Excludes user files and logs from version control

### Examples
- **examples/task.example.md** - Comprehensive task example
- **examples/rules.example.md** - Safety rules template

### Testing
- **test/README.md** - Testing documentation
- **test/test-immediate-execution.sh** - Run tasks without waiting
- **test/test-simple.sh** - Basic functionality test
- **test/test-task-simple.md** - Simple test task
- **test/test-rules-simple.md** - Simple test rules

## Quick Start

1. Clone the repository
2. Run `chmod +x *.sh` to make scripts executable
3. Run `./setup-nights-watch.sh` for interactive setup
4. Create your `task.md` and `rules.md`
5. Start with `./claude-nights-watch-manager.sh start`

## Key Features

- ✅ Autonomous task execution
- ✅ Safety rules enforcement
- ✅ Comprehensive logging
- ✅ Scheduled start times
- ✅ Interactive setup and management
- ✅ Test suite included

## Safety Note

This tool executes tasks autonomously with `--dangerously-skip-permissions`. Always:
- Test tasks manually first
- Use comprehensive rules.md
- Monitor logs regularly
- Keep backups of important data
