# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-15

### Added
- Initial release of Claude Nights Watch
- Autonomous task execution from task.md files
- Safety rules enforcement from rules.md files
- Comprehensive logging system with full prompt/response capture
- Interactive setup wizard (`setup-nights-watch.sh`)
- Daemon management system (`claude-nights-watch-manager.sh`)
- Interactive log viewer (`view-logs.sh`)
- Test suite with immediate execution testing
- Scheduled start time support
- Integration with ccusage for accurate timing
- Fallback to time-based checking without ccusage
- Adaptive monitoring intervals based on remaining time

### Features
- **Core Daemon**: Monitors Claude usage windows and executes tasks
- **Task Management**: Reads and executes tasks from markdown files
- **Safety System**: Enforces rules and constraints for autonomous execution
- **Logging**: Complete audit trail of all executions and responses
- **Scheduling**: Start monitoring at specific times
- **Testing**: Comprehensive test suite for validation

### Documentation
- Complete README with installation and usage instructions
- Example task and rules files
- Testing documentation
- Contributing guidelines
- MIT License

### Safety
- Uses `--dangerously-skip-permissions` with safety rule enforcement
- Comprehensive example rules for common safety scenarios
- Logging of all prompts and responses for audit purposes
- Test scripts for validation before production use

## [Unreleased]

### Planned
- Web dashboard for monitoring and management
- Multiple task file support
- Task scheduling and queuing
- Integration with more timing tools
- Enhanced error recovery mechanisms
