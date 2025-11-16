# Rules Overview

This document provides a comprehensive overview of all rules and conventions for the OurGruuv project. For detailed information, refer to the individual rule files.

## Quick Reference

| Category | File | Description |
|----------|------|-------------|
| **Agent Behavior** | [agent-behavior.md](./agent-behavior.md) | How the AI agent should behave and work |
| **Coding Style** | [coding-style.md](./coding-style.md) | Rails, Ruby, and code organization standards |
| **Services Patterns** | [services-patterns.md](./services-patterns.md) | Services, Result pattern, transactions |
| **Forms & Validation** | [forms-validation.md](./forms-validation.md) | Forms, ActiveModel, dry-validation |
| **Integrations** | [integrations.md](./integrations.md) | Gateway pattern, OAuth, webhooks |
| **Queries & Value Objects** | [queries-value-objects.md](./queries-value-objects.md) | Query objects, value objects, scopes |
| **Events & Handlers** | [events-handlers.md](./events-handlers.md) | Wisper, event patterns, upgrade to RES |
| **Project Workflow** | [project-workflow.md](./project-workflow.md) | Git, deployment, and team collaboration processes |
| **Context Management** | [context-management.md](./context-management.md) | OKR3 framework and vision document handling |

## Agent Behavior Quick Start

### Core Workflow
1. **Always provide commit message, summary, and questions before implementation**
2. **Wait for user confirmation** before starting any work
3. **Confirmation phrases**: 
   - "Make it happen" = Start implementing the work
   - "Make it so" = Commit, merge, push to main, and deploy

### Error Handling
- Try to fix errors up to 3 times with the same error message
- After 3 attempts, ask user if they want to handle it manually
- Document systemic issues if same error occurs in different contexts

### Testing Approach
- When user says "TDD this bug": Write failing specs first, then fix code
- Never skip reproducing the bug in tests before attempting to fix it

## Coding Standards Quick Start

### Authorization (Critical)
- **Always use Pundit** - never inline authorization logic
- **Create dedicated policy classes** for each model
- **Use `verify_authorized` and `verify_policy_scoped`** in all controllers
- **Test policies independently** from controllers

### Database & Performance
- **Always use `includes` for associations** accessed in views
- **Apply `includes` before `decorate`** for optimal performance
- **Use consistent scope names**: `:active`, `:inactive`, `:recent`
- **Test association includes** to catch naming mismatches early

### Display & Presentation
- **Always use timezone conversion** for DateTime/Time fields when displaying to users
- **Use `format_time_in_user_timezone` helper** - never use `.strftime()` directly on datetime fields
- **Date fields don't need conversion** - only DateTime/Time fields require timezone math
- **Convert to UTC when saving** - store all timestamps in UTC, convert only when displaying

### Code Quality
- **Keep methods small and focused** (Sandi Metz rules)
- **Use decorators for presentation logic**
- **Follow SOLID principles**, especially DRY
- **Never write code that leads to silent failures**

## Project Workflow Quick Start

### Git & Deployment
- **Start commit messages** with the new mechanic introduced
- **Use Railway exclusively** for deployment
- **Run full specs** before 'make it so' deployments

### User Experience
- **Show toast notifications** for every action submission
- **Don't hide unauthorized actions** - disable them with tooltips
- **Use semantic colors** with consistent meanings
- **Mobile-first responsive design** required

### Design Standards
- **8:4 column split** for stats (left) and actions (right)
- **Use full-width cards** for major sections
- **Consistent card heights** for professional appearance
- **Semantic HTML** with proper ARIA attributes

## Context Management Quick Start

### Vision Documents
- **Review all vision documents** when starting fresh conversations
- **Understand current OKR3 objectives** before making changes
- **Document learnings** when completing objectives

### OKR3 Framework
- **Objectives**: Focus on feelings, not solutions
- **Key Results**: Use COMMIT/STRETCH/TRANSFORM confidence levels
- **Structure**: DONE/DOING/DREAMING organization

## Implementation Checklist

When working on any feature:

**Agent Behavior:**
- [ ] Provide commit message and summary before starting
- [ ] Wait for user confirmation
- [ ] Handle errors with 3-attempt limit
- [ ] Use TDD approach for bug fixes

**Coding Standards:**
- [ ] Use Pundit for all authorization
- [ ] Include associations before decorating
- [ ] Test policies independently
- [ ] Keep methods small and focused
- [ ] Avoid silent failures
- [ ] Use timezone conversion for all DateTime/Time displays
- [ ] Never use `.strftime()` directly on datetime fields

**Project Workflow:**
- [ ] Show toast notifications for actions
- [ ] Use semantic colors consistently
- [ ] Follow responsive design patterns
- [ ] Test association includes
- [ ] Use Railway for deployment

**Context Management:**
- [ ] Review vision documents for context
- [ ] Align changes with current OKR3
- [ ] Document outcomes and learnings

## Common Patterns

### Authorization Pattern
```ruby
# Controller
authorize @record
policy_scope(Model)

# Policy
def show?
  user.admin? || user == record.user
end
```

### Query Optimization
```ruby
# Good
Model.includes(:associations).decorate

# Bad
Model.decorate.includes(:associations)
```

### Timezone Handling
```ruby
# Good - Uses timezone conversion
= format_time_in_user_timezone(@goal.created_at)

# Bad - No timezone conversion
= @goal.created_at.strftime("%B %d, %Y at %I:%M %p")

# Good - Date fields don't need conversion
= @goal.most_likely_target_date.strftime("%B %d, %Y")
```

### Error Handling
```ruby
# Good - explicit error handling
rescue ActiveRecord::RecordNotFound => e
  redirect_to root_path, alert: "Record not found"

# Bad - silent failure
record = Model.find_by(id: params[:id])
# record could be nil, causing silent failures
```

## Getting Help

- **Agent behavior**: See [agent-behavior.md](./agent-behavior.md) for AI-specific rules
- **Coding standards**: See [coding-style.md](./coding-style.md) for technical standards
- **Project workflow**: See [project-workflow.md](./project-workflow.md) for process rules
- **Context management**: See [context-management.md](./context-management.md) for vision and OKR3 handling
