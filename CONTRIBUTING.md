# Contributing to Claude Nights Watch

Thank you for your interest in contributing to Claude Nights Watch! 

## How to Contribute

### Reporting Issues

1. Check if the issue already exists
2. Include:
   - Clear description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - Log outputs (sanitized of sensitive data)
   - System information (OS, Claude CLI version)

### Submitting Pull Requests

1. Fork the repository from [https://github.com/aniketkarne/ClaudeNightsWatch](https://github.com/aniketkarne/ClaudeNightsWatch)
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly (see Testing section)
5. Commit with clear messages (`git commit -m 'Add amazing feature'`)
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request against the main repository

### Code Guidelines

- Follow existing shell script conventions
- Add comments for complex logic
- Update documentation for new features
- Include error handling
- Test on both macOS and Linux if possible

### Testing

Before submitting:
1. Run the test suite: `cd test && ./test-simple.sh`
2. Test your changes with real tasks
3. Verify logs capture all relevant information
4. Check that safety rules are respected

### Safety First

When contributing:
- Never add features that bypass safety rules
- Always consider autonomous execution implications
- Document any new risks or considerations
- Default to safer options

### Documentation

- Update README.md for user-facing changes
- Add examples for new features
- Document new configuration options
- Update test documentation if needed

## Development Setup

1. Fork and clone the repository
2. Create a test task.md and rules.md
3. Run tests to ensure everything works
4. Make your changes
5. Test again thoroughly

## Questions?

Feel free to open an issue for discussion before making large changes.