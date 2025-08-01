# Project Rules & Conventions

This document contains all the rules and conventions we follow in this project to maintain code quality, consistency, and best practices.

## Code Organization & Architecture

### Service Objects & Jobs
- Keep service objects small and use inversion of control
- Delegate complex actions to dedicated job classes (one method per class) under a namespace (e.g., `Huddles`)
- Jobs should be idempotent (handling creation or update)
- Jobs should be named with a verb and a noun, for example `Huddles::PostAnnouncementJob`

### Slack Integration
- `SlackService` `post_message` and `update_message` should accept `notifiable_type`, `notifiable_id`, and `main_thread_id`, with no huddle-specific logic
- Default Slack bot username should be 'OG'

## Display & Presentation

### Display Names
- When displaying names/titles of objects in views, use a `display_name` method, ideally on the decorator object
- This ensures separation of concerns and makes it easier to make adjustments in the future if we want to display an object differently

## Code Quality & Maintainability

### Method Design
- Methods should be as small as possible, following Sandi Metz's rules for code maintainability
- Keep methods focused and single-purpose

### Constants
- Avoid putting constants hardcoded in views when reasonable to do so

## Testing

### Framework
- Use RSpec instead of Minitest for testing in this project

### Test Policy
- Any failing tests must be either fixed or removed; tests should never remain failing

## User Experience

### Notifications
- Show a toast notification every time any action is submitted to inspire confidence in the system

## Development Workflow

### Server Management
- Always manually run the Rails server in a separate terminal
- Use `bin/dev` for comprehensive local testing
- Notify when changes aren't picked up by autoloading and require a server restart

### Code Changes
- Ask for confirmation before making any changes to existing code changes

### Deployment
- Use Railway exclusively for deployment
- Remove all other deployment options and focus on the Railway deploy flow

## Git & Deployment

### Commit Messages
- Start commit messages with the new mechanic introduced, followed by a summary of other notable changes
- Don't list every change in commit messages

### Deployment Process
- When user says 'make it so', run the full specs, commit merge and push to main, then perform the Railway deploy steps

---

*This document should be updated whenever new rules are established or existing rules are modified.* 