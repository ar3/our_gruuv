# Services Pattern Violations

This document tracks violations of the Services pattern in the current codebase.

## Pattern Requirements

### Services Should:
- Have one verb name (`ChargeInvoice`, `SyncFranchisee`)
- Have one public `call` method
- Use `Result` pattern for return values
- Wrap operations in transactions when needed
- Handle errors explicitly with `Result.ok/err`
- Be callable from both controllers and jobs

### Services Should NOT:
- Mix business logic with external API calls
- Return inconsistent data structures
- Handle authorization (use Policies instead)
- Access the database directly without models
- Have multiple public methods

## Current Violations

### High Priority Violations

#### 1. SlackService - Mixed Concerns
**File**: `app/services/slack_service.rb`
**Issues**:
- Mixes business logic with external API calls
- Returns inconsistent data structures (`{ success: false, error: "..." }`)
- No Result pattern
- Complex error handling mixed with business logic
- Should be split into Gateway + Service

#### 2. MaapChangeExecutionService - No Result Pattern
**File**: `app/services/maap_change_execution_service.rb`
**Issues**:
- Returns boolean values instead of Result pattern
- No explicit error handling with Result.err
- Multiple public methods (`execute!`)
- Should use Result.ok/err pattern

#### 3. EmploymentDataUploadProcessor - Inconsistent Returns
**File**: `app/services/employment_data_upload_processor.rb`
**Issues**:
- Returns boolean instead of Result pattern
- Complex error handling without Result.err
- Should use Result.ok/err for consistent returns

### Medium Priority Violations

#### 4. SlackChannelsService - No Result Pattern
**File**: `app/services/slack_channels_service.rb`
**Issues**:
- Returns boolean instead of Result pattern
- No explicit error handling with Result.err
- Should use Result.ok/err pattern

#### 5. PendoService - Direct API Access
**File**: `app/services/pendo_service.rb`
**Issues**:
- Direct HTTP calls without Gateway pattern
- No error categorization (retryable vs non-retryable)
- Should use Gateway pattern for external API access

## Migration Priority

1. **High Priority**: Services with mixed concerns (API + business logic)
2. **Medium Priority**: Services with inconsistent return values
3. **Low Priority**: Services that could benefit from Result pattern

## Notes

- Focus on services that are called from multiple places
- Prioritize services with complex error handling
- Consider breaking large services into smaller, focused ones
