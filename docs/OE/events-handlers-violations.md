# Events & Handlers Pattern Violations

This document tracks violations of the Events and Handlers pattern in the current codebase.

## Pattern Requirements

### Events Should:
- Use Wisper for in-process pub/sub
- Be past tense (`InvoicePaid`, `SubscriptionActivated`)
- Be simple data containers
- Be in `app/events/` directory

### Handlers Should:
- Handle one effect per handler
- Be idempotent
- Be in `app/handlers/` directory
- Use `DoXOnY` naming pattern

### Services Should:
- Publish events for side effects
- Use `broadcast` for Wisper events
- Keep business logic separate from side effects

## Current Violations

### High Priority Violations

#### 1. Services with Side Effects
**Files**: Multiple services
**Issues**:
- Services perform side effects directly (email sending, Slack posting)
- No event publishing for side effects
- Should publish events and let handlers process side effects
- Mixed business logic with side effects

#### 2. Controllers with Side Effects
**Files**: Multiple controllers
**Issues**:
- Controllers perform side effects directly
- Should delegate side effects to Services with event publishing
- Mixed concerns in controllers

### Medium Priority Violations

#### 3. No Event System
**Issues**:
- No Wisper or event system implemented
- Side effects are tightly coupled to business logic
- No decoupling of side effects from main business flow

## Migration Priority

1. **High Priority**: Services with multiple side effects
2. **Medium Priority**: Controllers with side effects
3. **Low Priority**: Simple side effects that could be events

## Notes

- Look for services with multiple side effects
- Identify controllers doing side effects
- Consider events for cross-cutting concerns
- Focus on side effects that could be async
