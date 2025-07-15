# Claude Nights Watch 🌙

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Language-Shell-green.svg)](https://www.gnu.org/software/bash/)
[![GitHub stars](https://img.shields.io/github/stars/aniketkarne/ClaudeNightsWatch.svg?style=social&label=Star)](https://github.com/aniketkarne/ClaudeNightsWatch)

Autonomous task execution system for Claude CLI that monitors your usage windows and executes predefined tasks automatically. Built on top of the claude-auto-renew concept but instead of simple renewals, it executes complex tasks from a task.md file.

**⚠️ Warning**: This tool uses `--dangerously-skip-permissions` for autonomous execution. Use with caution!

## 🎯 Overview

Claude Nights Watch extends the auto-renewal concept to create a fully autonomous task execution system. When your Claude usage window is about to expire, instead of just saying "hi", it reads your `task.md` file and executes the defined tasks autonomously.

### Key Features

- 🤖 **Autonomous Execution**: Runs tasks without manual intervention
- 📋 **Task-Based Workflow**: Define tasks in a simple markdown file
- 🛡️ **Safety Rules**: Configure safety constraints in `rules.md`
- ⏰ **Smart Timing**: Uses ccusage for accurate timing or falls back to time-based checking
- 📅 **Scheduled Start**: Can be configured to start at a specific time
- 📊 **Comprehensive Logging**: Track all activities and executions
- 🔄 **Based on Proven Code**: Built on the reliable claude-auto-renew daemon

## 🚀 Quick Start

### Prerequisites

1. [Claude CLI](https://docs.anthropic.com/en/docs/claude-code/quickstart) installed and configured
2. (Optional) [ccusage](https://www.npmjs.com/package/ccusage) for accurate timing:
   ```bash
   npm install -g ccusage
   ```

### Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/aniketkarne/ClaudeNightsWatch.git
   cd ClaudeNightsWatch
   ```

2. Make scripts executable:
   ```bash
   chmod +x *.sh
   ```

3. Run the interactive setup:
   ```bash
   ./setup-nights-watch.sh
   ```

### Basic Usage

1. **Create your task file** (`task.md`):
   ```markdown
   # Daily Development Tasks
   
   1. Run linting on all source files
   2. Update dependencies to latest versions
   3. Run the test suite
   4. Generate coverage report
   5. Create a summary of changes
   ```

2. **Create safety rules** (`rules.md`):
   ```markdown
   # Safety Rules
   
   - Never delete files without backing up
   - Only work within the project directory
   - Always create feature branches for changes
   - Never commit sensitive information
   ```

3. **Start the daemon**:
   ```bash
   ./claude-nights-watch-manager.sh start
   ```

## 📝 Configuration

### Task File (task.md)

The task file contains the instructions that Claude will execute. It should be clear, specific, and well-structured. See `examples/task.example.md` for a comprehensive example.

### Rules File (rules.md)

The rules file defines safety constraints and best practices. It's prepended to every task execution to ensure safe autonomous operation. See `examples/rules.example.md` for recommended rules.

### Environment Variables

- `CLAUDE_NIGHTS_WATCH_DIR`: Set the directory containing task.md and rules.md (default: current directory)

## 🎮 Commands

### Manager Commands

```bash
# Start the daemon
./claude-nights-watch-manager.sh start

# Start with scheduled time
./claude-nights-watch-manager.sh start --at "09:00"
./claude-nights-watch-manager.sh start --at "2025-01-28 14:30"

# Stop the daemon
./claude-nights-watch-manager.sh stop

# Check status
./claude-nights-watch-manager.sh status

# View logs
./claude-nights-watch-manager.sh logs
./claude-nights-watch-manager.sh logs -f  # Follow mode

# Use interactive log viewer
./view-logs.sh

# View current task and rules
./claude-nights-watch-manager.sh task

# Restart daemon
./claude-nights-watch-manager.sh restart
```

## 🔧 How It Works

1. **Monitoring**: The daemon continuously monitors your Claude usage windows
2. **Timing**: When approaching the 5-hour limit (within 2 minutes), it prepares for execution
3. **Task Preparation**: Reads both `rules.md` and `task.md`, combining them into a single prompt
4. **Autonomous Execution**: Executes the task using `claude --dangerously-skip-permissions`
5. **Logging**: All activities are logged to `logs/claude-nights-watch-daemon.log`

### Timing Logic

- **With ccusage**: Gets accurate remaining time from the API
- **Without ccusage**: Falls back to timestamp-based checking
- **Adaptive intervals**:
  - \>30 minutes remaining: Check every 10 minutes
  - 5-30 minutes remaining: Check every 2 minutes
  - <5 minutes remaining: Check every 30 seconds

## ⚠️ Safety Considerations

**IMPORTANT**: This tool runs Claude with the `--dangerously-skip-permissions` flag, meaning it will execute tasks without asking for confirmation. 

### Best Practices:

1. **Always test tasks manually first** before setting up autonomous execution
2. **Use comprehensive rules.md** to prevent destructive actions
3. **Start with simple, safe tasks** and gradually increase complexity
4. **Monitor logs regularly** to ensure proper execution
5. **Keep backups** of important data
6. **Run in isolated environments** when possible

### Recommended Restrictions:

- Limit file system access to project directories
- Prohibit deletion commands
- Prevent system modifications
- Restrict network access
- Set resource limits

## 📁 File Structure

```
claude-nights-watch/
├── claude-nights-watch-daemon.sh      # Core daemon process
├── claude-nights-watch-manager.sh     # Daemon management interface
├── setup-nights-watch.sh              # Interactive setup script
├── view-logs.sh                       # Interactive log viewer
├── README.md                          # This file
├── LICENSE                            # MIT License
├── CONTRIBUTING.md                    # Contribution guidelines
├── CHANGELOG.md                       # Version history
├── SUMMARY.md                         # Project summary
├── .gitignore                         # Git ignore file
├── .github/                           # GitHub templates
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── pull_request_template.md
├── logs/                              # All logs stored here (created on first run)
├── examples/                          # Example files
│   ├── task.example.md                # Example task file
│   └── rules.example.md               # Example rules file
└── test/                              # Test scripts and files
    ├── README.md                      # Testing documentation
    ├── test-immediate-execution.sh    # Direct task execution test
    ├── test-simple.sh                 # Simple functionality test
    ├── test-task-simple.md            # Simple test task
    └── test-rules-simple.md           # Simple test rules
```

## 📊 Logging

All logs are stored in the `logs/` directory within the project. Each log contains:

- **Timestamps**: Every action is timestamped
- **Full Prompts**: Complete prompt sent to Claude (rules + task)
- **Full Responses**: Everything Claude outputs
- **Status Messages**: Success/failure indicators

### Viewing Logs

Use the interactive log viewer:
```bash
./view-logs.sh
```

Features:
- Browse all log files
- View full logs or last 50 lines
- Filter to see only prompts sent to Claude
- Filter to see only Claude's responses
- Search for errors
- Follow logs in real-time

## 🧪 Testing

Test scripts are available in the `test/` directory:

```bash
cd test
./test-simple.sh  # Run a simple test
```

See `test/README.md` for detailed testing instructions.

## 🐛 Troubleshooting

### Daemon won't start
- Check if Claude CLI is installed: `which claude`
- Verify task.md exists in the working directory
- Check logs: `./claude-nights-watch-manager.sh logs`

### Tasks not executing
- Verify you have remaining Claude usage: `ccusage blocks`
- Check if past scheduled start time
- Ensure task.md is not empty
- Review logs for errors

### Timing issues
- Install ccusage for better accuracy: `npm install -g ccusage`
- Check system time is correct
- Verify `.claude-last-activity` timestamp

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. **Fork the repository** on GitHub
2. **Clone your fork** locally
3. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
4. **Make your changes** following our guidelines
5. **Test thoroughly** using the test suite
6. **Commit your changes** (`git commit -m 'Add amazing feature'`)
7. **Push to your fork** (`git push origin feature/amazing-feature`)
8. **Create a Pull Request** on GitHub

Please ensure:
- Code follows existing style
- Safety is prioritized  
- Documentation is updated
- Examples are provided
- Tests pass

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Created by**: [Aniket Karne](https://github.com/aniketkarne)
- **Built on top of**: The excellent [CCAutoRenew](https://github.com/aniketkarne/CCAutoRenew) project
- **Thanks to**: The Claude CLI team for the amazing tool

---

**Remember**: With great automation comes great responsibility. Always review your tasks and rules carefully before enabling autonomous execution! 🚨