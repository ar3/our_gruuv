# Forms Pattern Violations

This document tracks violations of the Forms pattern in the current codebase.

## Pattern Requirements

### Forms Should:
- Use ActiveModel by default for simple cases
- Escalate to dry-validation for complex/nested inputs
- Handle input shaping and validation
- Call Services for business logic
- Provide consistent error handling
- Keep invariants on models/DB

### Forms Should NOT:
- Contain business logic
- Access the database directly
- Handle authorization (use Policies instead)
- Mix validation with data persistence
- Have complex conditional logic in views

## Current Violations

### High Priority Violations

#### 1. ApplicationController - Complex Parameter Handling
**File**: `app/controllers/application_controller.rb` (lines 234-310)
**Issues**:
- Complex parameter validation logic in controller
- Mixed concerns (validation + business logic)
- Should be moved to Form object
- Complex conditional logic for different parameter types

#### 2. UploadEventsController - Complex Parameter Validation
**File**: `app/controllers/upload_events_controller.rb` (lines 48-78)
**Issues**:
- Complex parameter validation and type checking
- Mixed concerns (validation + business logic)
- Should use Form object for upload type validation
- Complex error handling for different parameter types

### Medium Priority Violations

#### 3. PeopleController - Parameter Handling
**File**: `app/controllers/people_controller.rb`
**Issues**:
- Parameter handling mixed with business logic
- Could benefit from Form object for person updates
- Simple but could be more structured

#### 4. InterestSubmissionsController - Simple Form Logic
**File**: `app/controllers/interest_submissions_controller.rb`
**Issues**:
- Basic form handling that could benefit from Form object
- Mixed validation and business logic
- Could be more structured with ActiveModel form

## Migration Priority

1. **High Priority**: Controllers with complex parameter handling
2. **Medium Priority**: Views with inline validation logic
3. **Low Priority**: Simple forms that could benefit from structure

## Notes

- Look for controllers with complex `params` handling
- Identify views with validation logic
- Consider forms for multi-step processes
- Focus on user input validation patterns
