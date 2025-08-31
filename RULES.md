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

### Authorization & Security
- **Always use Pundit for authorization** - never implement inline authorization logic in controllers
- **Create dedicated policy classes** for each model that needs authorization
- **Use `verify_authorized` and `verify_policy_scoped` callbacks** in all controllers
- **Centralize permission logic** in policy objects, not in controllers or models
- **Admin role should be simple** - use a boolean flag (`og_admin`) that bypasses all permission checks
- **Test policies independently** from controllers for better maintainability
- **Follow consistent authorization patterns** across all controllers:
  - Use `authorize @record` for individual record actions
  - Use `policy_scope(Model)` for collection actions
  - Use `authorize Model` for class-level actions (like index)

### Authorization Anti-Patterns to Avoid
- **Never use `before_action` callbacks for authorization** - this leads to sloppy, hard-to-maintain code
- **Don't implement custom authorization methods** in controllers (like `ensure_admin_or_self`)
- **Avoid mixing authorization patterns** - stick to Pundit's standard approach
- **Don't skip authorization** - always use `verify_authorized` to catch missing authorization calls
- **Never check admin status directly in controllers or models** - always use Pundit policies for authorization decisions
- **Never put authorization logic in views** - use `policy(@record).action?` instead of inline permission checks

### Common Authorization Scenarios
- **User accessing their own records**: Use `user == record` in policy methods
- **Admin bypass**: Always check `user.admin?` first in policy methods
- **Collection filtering**: Use `policy_scope` to filter collections based on user permissions
- **Nested resources**: Authorize the parent resource when appropriate (e.g., `authorize @person` for employment tenures)
- **New records**: For `new`/`create` actions, authorize based on the context (e.g., the person being created for)

## Display & Presentation

### Display Names
- When displaying names/titles of objects in views, use a `display_name` method, ideally on the decorator object
- This ensures separation of concerns and makes it easier to make adjustments in the future if we want to display an object differently

### Decorator Usage
- **Always decorate collections and records** before passing to views using `.decorate`
- **Use decorators for presentation logic** - keep models focused on business logic
- **Apply includes before decorate** for performance: `Model.includes(:associations).decorate`
- **Create dedicated decorator classes** for complex presentation logic

## Code Quality & Maintainability

### Error Handling & Debugging
- **Self-correction attempts**: Try to fix errors up to 3 times with the exact same error message
- **Check-in threshold**: After 3 attempts with the same error, ask user if they want to handle it manually or if you should continue
- **Error pattern recognition**: If you encounter the same error type multiple times in different contexts, document it as a potential systemic issue
- **Manual intervention**: When hitting the check-in threshold, clearly state what you've tried and what the persistent issue appears to be

### Method Design
- Methods should be as small as possible, following Sandi Metz's rules for code maintainability
- Keep methods focused and single-purpose
- Follow SOLID principles when appropriate, especially DRY (Don't Repeat Yourself) - use partials and abstractions for identical/near-identical code

### Constants
- Avoid putting constants hardcoded in views when reasonable to do so

### Database Field Naming
- **Date fields**: Use `_on` suffix (e.g., `check_in_started_on`, `check_in_ended_on`, `started_at`, `ended_at`)
- **Timestamp fields**: Use `_at` suffix (e.g., `created_at`, `updated_at`)

## UX Rules

### Authorization & Permission Display
- **Don't hide things**: Show all actions but disable unauthorized ones
- **Clear feedback**: Use warning icons next to disabled buttons/links with tooltips
- **Helpful tooltips**: Explain what permission is needed for each action on hover over warning icon
- **Consistent patterns**: Use the same UI patterns across all permission checks
- **Visual indicators**: Use consistent icons and colors for permission states
- **Disabled button styling**: Use `btn-outline-secondary` class for disabled buttons to clearly indicate they're not actionable
- **Secondary action styling**: Use `btn-outline-primary` for secondary actions and navigation links to distinguish from disabled buttons
- **Button layout**: Use `.flex-grow-1` wrapper with `.w-100` on disabled buttons to maintain full-width appearance minus warning icon space
- **Tooltip implementation**: Use Bootstrap tooltips with `data-bs-toggle="tooltip"` and `data-bs-title` for permission messages

### Permission-Based UI Implementation
- **Controller authorization**: Use permissive authorization for views (e.g., `authorize @resource, :show?`) and handle specific permissions in the view
- **View-level permission checks**: Use helper methods like `current_person&.can_create_employment?(@organization)` in views
- **Conditional UI rendering**: Show enabled buttons for authorized actions, disabled buttons with tooltips for unauthorized actions
- **Consistent permission patterns**: Use the same `if authorized / else disabled + tooltip` pattern across all actions
- **Policy logic belongs in Pundit policies**: Never implement complex authorization logic directly in views - use `policy(@record).action?` instead
- **Avoid multi-line conditionals in views**: Keep view logic simple by delegating complex checks to policy methods
- **Use semantic policy method names**: Create descriptive policy methods like `view_employment_history?` instead of complex inline checks

### Color System & Visual Design
- **Colors must have consistent, meaningful purposes** - never use colors as random decoration
- **Follow semantic color usage** across the entire interface:
  - **Blue (primary)**: Main metrics, counts, primary data points
  - **Blue (info)**: Secondary metrics, ratings, additional information
  - **Gray (secondary)**: Dates, timestamps, less important data
  - **Green (success)**: Positive states, completed items, "good" metrics
  - **Yellow (warning)**: Attention needed, caution states, neutral states
  - **Red (danger)**: Critical issues, errors, "bad" metrics
- **Limited color palette**: Use 5-7 colors maximum for clarity
- **Accessibility first**: Ensure sufficient contrast ratios for all color combinations
- **Cultural considerations**: Avoid red/green combinations for colorblind users

### Dashboard Layout & Organization
- **Use full-width cards for each major section** to create visual unity
- **8:4 column split for stats and actions**: Stats on the left (8 columns), actions on the right (4 columns)
- **Subtle visual dividers**: Use `border-start border-secondary` for clean separation between stats and actions
- **Consistent card heights**: Each section should have matching heights for professional appearance
- **Group related functionality**: Actions should be grouped with their relevant content areas
- **Prioritize information architecture**: Organize content logically by grouping related information together

### Accessibility & Semantic Structure
- **Use semantic HTML elements**: Employ proper heading hierarchy (H1 → H5) and semantic tags
- **ARIA regions and landmarks**: Mark major sections with `role="region"` and `aria-labelledby`
- **Proper labeling**: Each interactive element should have clear, descriptive labels
- **Keyboard navigation**: Ensure all interactive elements are accessible via keyboard
- **Screen reader support**: Use proper ARIA attributes to help assistive technologies navigate content

## Development Rules

### Debugging & Testing
- **Use `rails runner` instead of `rails console`** for quick debugging and testing
- **Avoid opening interactive consoles** unless actually needed for manual testing

### Model Scopes & Naming
- **Use consistent scope names** across models: `:active`, `:inactive`, `:recent`
- **Active scopes should use `where(ended_at: nil)`** for time-based models (employment tenures, assignments)
- **Inactive scopes should use `where.not(ended_at: nil)`** for completed/ended records
- **Scope names should be descriptive** and indicate the state or filter being applied

### Database Query Optimization
- **Always use `includes` for associations** that will be accessed in views
- **Apply `includes` before `decorate`** for optimal performance
- **Use `joins` only when you need to filter by associated data**, not for display
- **Order queries efficiently**: `Model.includes(:associations).order(:field).decorate`

### STI (Single Table Inheritance) & Association Patterns
- **Use domain-specific association names** when pointing to STI models (e.g., `belongs_to :company` for employment, not generic `organization`)
- **Be consistent with association names** across all includes, queries, and model methods
- **Test association includes** to catch naming mismatches early (they fail at query execution, not model loading)
- **For STI associations**: Use the specific subclass name when the relationship is semantically about that type (employment → company, not organization)

### Transaction Handling
- **Use transactions for multi-step operations** that must succeed or fail together
- **Wrap related database changes** in `ActiveRecord::Base.transaction` blocks
- **Handle transaction failures gracefully** with proper error handling and user feedback
- **Use `save!` and `update!`** within transactions to ensure failures are caught

### Error Handling & Validation
- **Rescue specific ActiveRecord errors** (`RecordInvalid`, `RecordNotFound`, `RecordNotUnique`)
- **Provide user-friendly error messages** when validation fails
- **Log errors appropriately** for debugging and monitoring
- **Handle edge cases gracefully** - don't let unexpected errors crash the application

## Testing

### Framework
- Use RSpec instead of Minitest for testing in this project

### Test Policy
- Any failing tests must be either fixed or removed; tests should never remain failing
- **Focus on high-value testing** - test complex business logic that's hard to debug manually
- **Skip testing simple CRUD** that Rails handles automatically
- **Test what could go wrong** rather than aiming for 100% coverage

### Policy Testing
- **Test policies independently** from controllers using dedicated policy specs
- **Test all permission scenarios** including admin bypass, user access, and denied access
- **Test policy scopes** to ensure proper filtering of collections
- **Mock user context** properly in policy tests to simulate different user roles

### High-Value Testing Scenarios
- **Data integrity** (validations, constraints, overlapping tenures)
- **Authorization flows** to prevent security issues
- **Complex business logic** (job changes, energy % changes, tenure transitions)
- **Edge cases** that could cause production issues

### Association Testing (Critical for Manual Testing Bug Prevention)
- **Always test association includes** - test that `Model.includes(:association)` works without errors
- **Test complex includes** - verify multi-association includes work: `Model.includes(:assoc1, :assoc2, :assoc3)`
- **Test wrong association names fail** - ensure using incorrect names raises `StatementInvalid` with column errors
- **Test association queries** - verify `Model.where(association: record)` works correctly
- **Execute queries in tests** - association errors only appear when queries are executed (`.count`, `.first`, etc.)

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