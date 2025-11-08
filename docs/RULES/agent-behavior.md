# Agent Behavior Rules

This document defines how the AI agent should behave when working on this project.

## Core Agent Principles

### Workflow Confirmation
- **Always provide commit message, summary, and questions before implementation**
- **Wait for user confirmation** before starting any work
- **Confirmation phrases**: 
  - "Make it happen" = Start implementing the work
  - "Make it so" = Commit, merge, push to main, and deploy

### Error Handling & Self-Correction
- **Self-correction attempts**: Try to fix errors up to 3 times with the exact same error message
- **Check-in threshold**: After 3 attempts with the same error, ask user if they want to handle it manually or if you should continue
- **Error pattern recognition**: If you encounter the same error type multiple times in different contexts, document it as a potential systemic issue
- **Manual intervention**: When hitting the check-in threshold, clearly state what you've tried and what the persistent issue appears to be

### Code Changes
- **Ask for confirmation before making any changes** to existing code changes
- **Always ask for verification before committing** - after each unit of work, ask user to verify either with code review or manually walking through the UI before executing any commits
- **Write commit message before starting work** - write the top line commit message before beginning each unit of work to ensure clarity on what we're trying to accomplish

### Testing Approach
- **When user says "TDD this bug"**: Follow strict TDD approach
- **Step 1**: Write spec(s) that reproduce the exact exception and fail because of the exception
- **Step 2**: Only then modify the code to fix the exception
- **Step 3**: Run the specs again to ensure the issue is actually fixed
- **Never skip Step 1**: Always reproduce the bug in tests before attempting to fix it

### Testing Requirements
- **When creating new forms**: MUST write 2 system specs (simple + complex)
- **When creating new pages**: MUST write 1 system spec (navigation + rendering)
- **When creating new controllers**: MUST write request specs for all actions (authorization, validations, redirects)
- **System specs are sacred**: Never delete, always update when features change
- **Use testing pyramid**: Unit specs (many) → Request specs (moderate) → System specs (few)

### Debugging & Development
- **Use `rails runner` instead of `rails console`** for quick debugging and testing
- **Avoid opening interactive consoles** unless actually needed for manual testing
- **Always manually run the Rails server** in a separate terminal
- **Use `bin/dev` for comprehensive local testing**
- **Notify when changes aren't picked up by autoloading** and require a server restart

### New Chat Workflow
- **When starting fresh conversations**: Review all vision documents in `docs/vision/` to understand current state and priorities

## Agent-Specific Rules

### Silent Failure Prevention
- **NEVER write code that might lead to silent failures** - they are the most costly to debug
- **Always handle error conditions explicitly** - use explicit error messages, redirects, or exceptions
- **Avoid methods that return nil/false silently** - prefer methods that raise exceptions or return explicit error objects
- **Use `dig` for safe parameter access** - but always check the result explicitly
- **Log errors when they occur** - don't let errors disappear into the void
- **Test error conditions** - ensure every error path is tested and produces visible feedback

### Code Quality Standards
- **Methods should be as small as possible**, following Sandi Metz's rules for code maintainability
- **Keep methods focused and single-purpose**
- **Follow SOLID principles** when appropriate, especially DRY (Don't Repeat Yourself) - use partials and abstractions for identical/near-identical code
- **Avoid putting constants hardcoded in views** when reasonable to do so
