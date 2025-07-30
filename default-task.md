# Default Refactoring Task - "Do No Harm, Clean Things Up"

This is the default task that runs when no project-specific task content is provided. It performs safe, language-agnostic cleanup and refactoring operations using git branches for safety.

## Task Overview

Perform safe cleanup and refactoring operations that improve code quality without breaking functionality. All changes are made on a separate git branch to ensure safety.

## Tasks to Execute

### 1. **Environment Setup and Safety**
   - Navigate to the target project directory
   - Verify this is a git repository
   - Check git status and ensure working directory is clean
   - Create a new branch: `nights-watch-refactor-$(date +%Y%m%d-%H%M%S)`
   - Switch to the new branch

### 2. **Language-Agnostic File Cleanup**
   - **Remove Common Junk Files:**
     - Delete `.DS_Store` files (macOS)
     - Remove `Thumbs.db` files (Windows)
     - Clean up `.tmp`, `.temp`, `.bak` files
     - Remove empty directories (except `.git`)

   - **Normalize Line Endings:**
     - Fix mixed line endings in text files
     - Ensure consistent line ending style

   - **Whitespace Cleanup:**
     - Remove trailing whitespace from text files
     - Fix inconsistent indentation where obvious
     - Ensure files end with newlines

### 3. **Documentation Maintenance**
   - **README Improvements:**
     - Fix obvious typos in README files
     - Ensure proper markdown formatting
     - Add missing sections if template is obvious

   - **Comment Cleanup:**
     - Remove commented-out code blocks (if clearly obsolete)
     - Fix obvious typos in comments
     - Standardize comment formatting

### 4. **Configuration File Organization**
   - **Config File Cleanup:**
     - Sort package.json dependencies alphabetically (if present)
     - Remove unused configuration entries (if obviously unused)
     - Standardize configuration file formatting

   - **Environment Files:**
     - Check for `.env.example` vs `.env` consistency
     - Ensure sensitive files are in `.gitignore`

### 5. **Git Repository Maintenance**
   - **Gitignore Improvements:**
     - Add common ignore patterns for detected languages
     - Remove duplicate entries
     - Organize ignore patterns logically

   - **Branch Cleanup Suggestions:**
     - List stale branches (merged or very old)
     - Suggest cleanup actions (don't delete automatically)

### 6. **Language-Specific Safe Operations**
   - **If JavaScript/Node.js detected:**
     - Check for unused dependencies (suggest removal)
     - Look for obvious security vulnerabilities in package.json

   - **If Python detected:**
     - Check for unused imports (suggest removal)
     - Look for obvious formatting issues

   - **If any language with tests:**
     - Check if test commands are documented
     - Verify test files are in .gitignore appropriately

### 7. **Final Safety Check and Summary**
   - Review all changes made
   - Ensure no functional code was modified
   - Create a commit with descriptive message
   - Generate a summary report of actions taken
   - Provide instructions for reviewing and merging changes

## Safety Constraints

**NEVER:**
- Modify functional code logic
- Delete files that could contain important data
- Make changes to version control history
- Modify build configurations without certainty
- Touch database files or schemas
- Modify deployment configurations

**ALWAYS:**
- Work on a separate git branch
- Make small, focused commits
- Test that nothing is broken after changes
- Document what was changed and why
- Provide rollback instructions

## Success Criteria

- Git branch created with all changes
- No functional code modified
- Only safe, non-breaking cleanup performed
- Clear summary of actions provided
- Easy rollback available via git branch deletion
