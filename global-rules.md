# Global Safety Rules for Claude Nights Watch

These rules apply to ALL project executions and MUST be followed at all times.

## CRITICAL SAFETY CONSTRAINTS

**⚠️ ABSOLUTE RESTRICTIONS:**
- NEVER run `rm -rf` or equivalent destructive commands
- NEVER modify or delete `.git` directories or git history
- NEVER commit sensitive information (keys, passwords, tokens)
- NEVER execute commands that could damage the system
- NEVER modify system files or configurations outside project scope

## EXECUTION CONTEXT

**Environment Awareness:**
- You are executing autonomously via `claude --dangerously-skip-permissions`
- Always verify file paths before modifying files
- Use relative paths within the project directory
- Prefer creating new files over modifying existing ones unless explicitly required

## DEFENSIVE PROGRAMMING

**Safety First:**
- Always validate inputs and file existence before operations
- Use defensive error handling in all scripts
- Test commands with `--dry-run` flags when available
- Create backups before modifying critical files

## LOGGING AND VISIBILITY

**Transparency:**
- Log all significant actions taken
- Explain what you're doing and why
- Report any errors or unexpected conditions
- Always create todo lists to track progress

## INTELLIGENT ANALYSIS WITH GEMINI MCP

**Large Codebase Analysis:**
- For analyzing multiple files or entire directories, ALWAYS use Gemini MCP integration
- Use `mcp__gemini-mcp__gemini_codebase_analysis` for comprehensive directory analysis
- Use `mcp__gemini-mcp__gemini_analyze_code` for detailed code section analysis
- Use `mcp__gemini-mcp__gemini_quick_query` for rapid Q&A about code patterns

**When to Use Gemini Offload:**
- Analyzing more than 3-5 files simultaneously
- Understanding project architecture or patterns
- Searching for specific implementations across the codebase
- Generating comprehensive reports about code quality or structure
- Any task that requires understanding relationships between multiple files

**Gemini Usage Pattern:**
```
# Always use Gemini for large-scale analysis first
result = mcp__gemini-mcp__gemini_codebase_analysis(directory_path="/path/to/analyze")
# Then use the insights to guide specific actions
```

**Integration Requirement:**
- This is a MANDATORY optimization for complex analysis tasks
- Gemini's 1M token context window handles entire codebases efficiently
- Always prefer Gemini analysis over manual file-by-file examination
- Use Gemini insights to create targeted action plans

These rules are immutable and take precedence over any project-specific instructions.
