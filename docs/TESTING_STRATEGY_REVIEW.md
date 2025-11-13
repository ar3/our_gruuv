# Testing Strategy Review

**Date**: 2025-11-09  
**Reviewer**: AI Assistant  
**Purpose**: Comprehensive review of testing strategy and current state

## Executive Summary

The project follows a well-structured **70/25/5 Testing Pyramid** approach with clear segmentation for efficient test execution. The strategy emphasizes speed, reliability, and maintainability.

## Current Testing Architecture

### Testing Pyramid Distribution

1. **Unit Tests (70%)** - Foundation Layer
   - **Location**: `spec/models/`, `spec/services/`, `spec/policies/`, `spec/decorators/`, `spec/queries/`, `spec/jobs/`, `spec/forms/`, `spec/helpers/`
   - **Speed**: ⚡️ Lightning fast (~0.01s each)
   - **Purpose**: Test business logic in isolation
   - **Status**: ✅ Strong coverage

2. **Request Specs (25%)** - Workhorse Layer
   - **Location**: `spec/requests/`, `spec/controllers/`
   - **Speed**: ⚡️ Fast (~0.1s each)
   - **Purpose**: Test full request cycle (HTTP → controller → model → DB → response)
   - **Status**: ⚠️ Significant failures detected (309 controller failures, 98 request failures)

3. **System Specs (5%)** - Smoke Tests
   - **Location**: `spec/system/` (organized by feature area)
   - **Speed**: 🐌 Slow (~3-5s each)
   - **Purpose**: Test critical end-to-end user flows with real browser
   - **Status**: ⚠️ Some failures (88 failures in last run)

4. **ENM Specs** - Isolated Module
   - **Location**: `spec/enm/`
   - **Purpose**: Ethical Non-Monogamy assessment module (isolated)
   - **Status**: ✅ Separate test suite

## Test Organization

### Directory Structure
```
spec/
├── models/              # Unit tests (993 examples)
├── controllers/         # Controller specs (402 examples)
├── requests/            # Request specs (159 examples)
├── system/              # System specs (386 examples)
│   ├── abilities/
│   ├── aspirations/
│   ├── assignments/
│   ├── audit/
│   ├── check_in_observations/
│   ├── check_ins/
│   ├── finalization/
│   ├── goals/
│   ├── huddles/
│   ├── misc/
│   ├── observations/
│   ├── positions_and_seats/
│   └── teammates/
├── enm/                 # ENM module specs
├── decorators/          # Decorator specs
├── policies/             # Policy specs
├── services/             # Service specs
├── queries/              # Query specs
├── jobs/                 # Job specs
├── forms/                # Form specs
└── helpers/              # Helper specs
```

### Unit Test Segmentation

Unit tests are organized into **10 segments**:

1. **Models** (`spec/models/`)
2. **Controllers** (`spec/controllers/`)
3. **Requests** (`spec/requests/`)
4. **Decorators** (`spec/decorators/`)
5. **Policies** (`spec/policies/`)
6. **Services** (`spec/services/`)
7. **Queries** (`spec/queries/`)
8. **Jobs** (`spec/jobs/`)
9. **Forms** (`spec/forms/`)
10. **Helpers** (`spec/helpers/`)

### System Spec Segmentation

System specs are organized into **13 feature-based folders**, each treated as a separate segment:

1. **Abilities** (`spec/system/abilities/`)
2. **Aspirations** (`spec/system/aspirations/`)
3. **Assignments** (`spec/system/assignments/`)
4. **Audit** (`spec/system/audit/`)
5. **Check-in Observations** (`spec/system/check_in_observations/`)
6. **Check-ins** (`spec/system/check_ins/`)
7. **Finalization** (`spec/system/finalization/`)
8. **Goals** (`spec/system/goals/`)
9. **Huddles** (`spec/system/huddles/`)
10. **Misc** (`spec/system/misc/`)
11. **Observations** (`spec/system/observations/`)
12. **Positions and Seats** (`spec/system/positions_and_seats/`)
13. **Teammates** (`spec/system/teammates/`)

## Test Execution Strategy

### Key Rules

1. **⚠️ CRITICAL**: Never run `bundle exec rspec` without arguments
2. **One Segment Per Execution**: Each segment must be run separately
3. **Track Everything**: Update `Last_full_spec_suite_run.md` before/after each segment
4. **Parse Failures**: Add detailed failure analysis to tracking document

### Execution Scripts

- **`bin/unit-specs`**: Runs all non-system specs (models, controllers, requests, etc.)
- **`bin/system-specs`**: Runs all system specs (not recommended - use segments instead)
- **`bin/enm-specs`**: Runs ENM module specs only

### Recommended Execution Order

When running full suite:

1. Model Specs (`spec/models/`)
2. Controller Specs (`spec/controllers/`)
3. Request Specs (`spec/requests/`)
4. Decorator Specs (`spec/decorators/`)
5. Policy Specs (`spec/policies/`)
6. Service Specs (`spec/services/`)
7. Query Specs (`spec/queries/`)
8. Job Specs (`spec/jobs/`)
9. Form Specs (`spec/forms/`)
10. Helper Specs (`spec/helpers/`)
11. System Specs - Abilities (`spec/system/abilities/`)
12. System Specs - Aspirations (`spec/system/aspirations/`)
13. System Specs - Assignments (`spec/system/assignments/`)
14. System Specs - Audit (`spec/system/audit/`)
15. System Specs - Check-in Observations (`spec/system/check_in_observations/`)
16. System Specs - Check-ins (`spec/system/check_ins/`)
17. System Specs - Finalization (`spec/system/finalization/`)
18. System Specs - Goals (`spec/system/goals/`)
19. System Specs - Huddles (`spec/system/huddles/`)
20. System Specs - Misc (`spec/system/misc/`)
21. System Specs - Observations (`spec/system/observations/`)
22. System Specs - Positions and Seats (`spec/system/positions_and_seats/`)
23. System Specs - Teammates (`spec/system/teammates/`)
24. ENM Specs (`spec/enm/`)

## Current Test Status (Last Run: 2025-11-09)

### Summary
- **Total Examples**: 1,554
- **Total Failures**: 88 (all in system specs)
- **Total Time**: ~22 minutes (when run in segments)

### Breakdown

| Segment | Examples | Failures | Time | Status |
|---------|-----------|----------|------|--------|
| Models | 993 | 0 | 37.32s | ✅ |
| Controllers | 402 | 309 | 27.68s | ⚠️ |
| Requests | 159 | 98 | ~26s | ⚠️ |
| System - Abilities | 39 | 1 | 88.32s | ⚠️ |
| System - Aspirations | 6 | 1 | 26.05s | ⚠️ |
| System - Assignments | 44 | 10 | 147.7s | ⚠️ |
| System - Check-ins | 0 | 1 error | 0.00s | ❌ |
| System - Finalization | 27 | 5 | 64.41s | ⚠️ |
| System - Goals | 54 | 19 | 242.5s | ⚠️ |
| System - Huddles | 32 | 3 | 90.12s | ⚠️ |
| System - Misc | 31 | 3 | 83.03s | ⚠️ |
| System - Observations | 32 | 1 | 144.1s | ⚠️ |
| System - Positions/Seats | 38 | 3 | 104.76s | ⚠️ |
| System - Teammates | 83 | 40 | 420.0s | ⚠️ |

### Critical Issues

1. **Check-ins Segment**: Load error - cannot load `shared_examples/check_in_form_fields`
2. **Teammates Segment**: 40 failures (largest failure count)
3. **Goals Segment**: 19 failures
4. **Assignments Segment**: 10 failures

## Testing Infrastructure

### Configuration Files

- **`spec/spec_helper.rb`**: Base RSpec configuration, SimpleCov setup
- **`spec/rails_helper.rb`**: Rails-specific configuration, Capybara setup
- **`.rspec`**: RSpec defaults

### Key Dependencies

- **RSpec**: Test framework
- **Capybara**: Browser automation
- **Selenium WebDriver**: Browser driver
- **FactoryBot**: Test data generation
- **DatabaseCleaner**: Database state management
- **SimpleCov**: Code coverage tracking
- **Shoulda Matchers**: Model validation testing
- **Pundit RSpec**: Policy testing

### Database Strategy

- **Unit/Request Specs**: Transactional fixtures (fast, same thread)
- **System Specs**: Truncation strategy (separate browser process)
- **DatabaseCleaner**: Manages cleanup for system specs

## Best Practices & Guidelines

### ✅ Do's

1. **Test Business Logic in Unit Tests**: Models, services, policies
2. **Test HTTP Cycle in Request Specs**: Controllers, redirects, database changes
3. **Test UX in System Specs**: Critical happy paths only
4. **Run Segments Separately**: One at a time for tracking
5. **Update Tracking Document**: Before and after each segment
6. **Parse Failures**: Add detailed analysis to tracking document

### ❌ Don'ts

1. **Don't Test Database State in System Specs**: Use request specs
2. **Don't Test Business Logic in System Specs**: Use unit tests
3. **Don't Test Multiple Scenarios in One System Spec**: Keep focused
4. **Don't Run Full Suite Without Segmentation**: Always use segments
5. **Don't Skip Failure Analysis**: Always document failures

## Performance Targets

- **Unit tests**: < 0.01s each
- **Request specs**: < 0.1s each
- **System specs**: < 5s each
- **Full suite**: < 30 minutes (when run in segments)

## Recommendations

### Immediate Actions

1. **Fix Check-ins Load Error**: Resolve `shared_examples/check_in_form_fields` issue
2. **Investigate Teammates Failures**: 40 failures need attention
3. **Review Goals Failures**: 19 failures in critical feature
4. **Address Assignments Failures**: 10 failures need resolution

### Long-term Improvements

1. **Reduce System Spec Failures**: Target < 5% failure rate
2. **Optimize Slow Specs**: Teammates segment takes 420s (7 minutes)
3. **Add More Request Specs**: Reduce reliance on system specs
4. **Improve Failure Messages**: Better debugging information
5. **Consider Parallel Execution**: For unit/request specs (not system specs)

## Success Metrics

- ✅ Zero flaky tests
- ✅ Clear failure messages
- ✅ Fast feedback loop
- ✅ Confidence to refactor
- ✅ Happy developers 😊

## References

- **Testing Strategy**: `docs/RULES/testing_strategy.md`
- **Last Full Run**: `Last_full_spec_suite_run.md`
- **Test Organization**: `docs/RULES/testing-strategy-summary.md`

---

**Next Steps**: Run specs in segments to get current status and update tracking document.

