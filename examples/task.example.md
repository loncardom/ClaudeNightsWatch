# Example Task for Claude Nights Watch

## Project: Automated Code Review and Improvement

### Objectives:
1. Review all Python files in the src/ directory
2. Identify and fix any linting issues
3. Add missing docstrings to functions
4. Create a summary report of changes

### Specific Tasks:

#### 1. Code Quality Check
- Run pylint on all Python files
- Fix any critical issues found
- Ensure PEP 8 compliance

#### 2. Documentation
- Add docstrings to all public functions
- Update README.md with any new features
- Generate API documentation

#### 3. Testing
- Run existing test suite
- Add tests for any uncovered functions
- Ensure all tests pass

#### 4. Final Report
- Create a CHANGES.md file
- List all modifications made
- Include before/after metrics

### Constraints:
- Do not modify any files outside the project directory
- Create a new branch called 'automated-improvements'
- Commit changes with descriptive messages

### Success Criteria:
- All tests pass
- No critical linting issues
- Documentation coverage > 80%
- Clean git history with atomic commits