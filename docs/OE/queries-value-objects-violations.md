# Queries & Value Objects Pattern Violations

This document tracks violations of the Queries and Value Objects patterns in the current codebase.

## Pattern Requirements

### Queries Should:
- Handle complex reads/reporting
- Be reusable across controllers/jobs
- Use stable shapes and joins
- Handle pagination and sorting
- Be in `app/queries/` directory

### Value Objects Should:
- Be immutable domain types
- Use `Data.define` (Ruby ≥ 3.2)
- Handle domain calculations/units
- Have equality by value
- Not access the database

### Scopes Should:
- Handle simple, composable filters
- Be single-table or simple joins
- Remain on models when appropriate

## Current Violations

### High Priority Violations

#### 1. PeopleController - Complex Queries in Controller
**File**: `app/controllers/people_controller.rb` (lines 19-28)
**Issues**:
- Complex includes and joins in controller
- Multiple query patterns that could be reused
- Should be moved to Query objects
- Complex preloading logic

#### 2. Organizations::PeopleController - Complex Queries
**File**: `app/controllers/organizations/people_controller.rb` (lines 10-22)
**Issues**:
- Complex includes and joins in controller
- Organization-scoped queries that could be reused
- Should be moved to Query objects

### Medium Priority Violations

#### 3. HuddlesController - Complex Query Logic
**File**: `app/controllers/huddles_controller.rb` (lines 6-18)
**Issues**:
- Complex grouping and sorting logic
- Multiple query patterns
- Could benefit from Query objects for reusability

#### 4. PeopleController - Assignment Data Loading
**File**: `app/controllers/people_controller.rb` (lines 126-143)
**Issues**:
- Complex assignment data loading logic
- Should be moved to Query object
- Complex sorting and filtering logic

## Migration Priority

1. **High Priority**: Complex queries in controllers
2. **Medium Priority**: Repeated query patterns
3. **Low Priority**: Simple scopes that could be value objects

## Notes

- Look for complex queries in controllers
- Identify repeated query patterns
- Consider value objects for domain calculations
- Focus on queries used in multiple places
