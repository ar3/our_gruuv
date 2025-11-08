# Testing Strategy Guidelines

## Overview

This document outlines our testing strategy following the **70/25/5 Testing Pyramid** approach for fast, reliable, and maintainable tests.

## Testing Pyramid

### Layer 1: Unit Tests (70% - Foundation)
**Purpose**: Test business logic in isolation
**Speed**: ⚡️ Lightning fast (~0.01s each)
**Reliability**: 🎯 100% deterministic

**What to test:**
- Model methods and concerns
- Business logic calculations
- Validations
- Scopes
- Service objects
- Helper methods

**Example:**
```ruby
# spec/models/concerns/check_in_behavior_spec.rb
RSpec.describe CheckInBehavior, type: :model do
  describe '#completion_state' do
    it 'returns :both_open when neither employee nor manager has completed' do
      allow(check_in).to receive(:employee_completed?).and_return(false)
      allow(check_in).to receive(:manager_completed?).and_return(false)
      expect(check_in.completion_state).to eq(:both_open)
    end
  end
end
```

### Layer 2: Request Specs (25% - Workhorse)
**Purpose**: Test full request cycle (params → controller → model → database → response)
**Speed**: ⚡️ Fast (~0.1s each)
**Reliability**: 🎯 99% reliable (no browser, same thread)

**What to test:**
- HTTP requests/responses
- Parameter handling
- Database changes
- Redirects
- Authorization
- Edge cases
- Controller actions

**Example:**
```ruby
# spec/requests/organizations/check_ins_spec.rb
RSpec.describe "Organizations::CheckIns", type: :request do
  describe "PATCH /organizations/:org_id/people/:person_id/check_ins" do
    it "saves data and marks as completed with timestamp and person" do
      patch organization_person_check_ins_path(organization, employee_person),
            params: { check_ins: { position_check_in: { status: "complete" } } }
      
      check_in = PositionCheckIn.find_by(teammate: employee_teammate)
      expect(check_in.manager_completed_at).to be_present
      expect(check_in.manager_completed_by).to eq(manager_person)
      expect(response).to redirect_to(organization_person_check_ins_path(organization, employee_person))
    end
  end
end
```

### Layer 3: System Specs (5% - Smoke Tests)
**Purpose**: Test critical user flows end-to-end with real browser
**Speed**: 🐌 Slow (~3-5s each)
**Reliability**: ⚠️ Can be flaky

**What to test:**
- Critical happy paths only
- Complex JavaScript interactions
- Multi-page flows
- Visual regressions
- User experience

**What NOT to test:**
- Database state (use request specs)
- Edge cases (use request specs)
- Multiple scenarios (use request specs)
- Business logic (use unit tests)

**Example:**
```ruby
# spec/system/position_check_in_happy_path_spec.rb
RSpec.describe 'Position Check-In Happy Path', type: :system do
  it 'manager can complete a check-in and see success message' do
    visit organization_person_check_ins_path(organization, employee_person)
    
    select 'Praising/Trusting', from: 'check_ins[position_check_in][manager_rating]'
    fill_in 'check_ins[position_check_in][manager_private_notes]', with: 'Great work'
    choose 'Complete'
    click_button 'Save All Check-Ins'
    
    expect(page).to have_content('Check-ins saved successfully')
    expect(page).to have_content('Ready for Finalization')
    expect(page).to have_content('Great work')
  end
end
```

## Benefits of This Approach

### Speed
- **Before**: 2 system specs × 7s = 14s
- **After**: 10 request specs × 0.1s + 1 system spec × 5s = 6s
- **Savings**: 57% faster

### Reliability
- **Before**: System specs fail due to transaction issues
- **After**: Request specs run in same thread, no transaction issues
- **Result**: 0 flaky tests

### Debuggability
- **Before**: System spec fails → check screenshot, check logs, check database
- **After**: Request spec fails → clear error message with exact assertion
- **Result**: 10x faster debugging

### Maintainability
- **Before**: Change UI → update system specs
- **After**: Change UI → system spec still passes (tests UX, not implementation)
- **Result**: Less brittle tests

## Migration Guidelines

### When Creating New Tests

1. **Start with unit tests** - Test the business logic first
2. **Add request specs** - Test the controller actions and database changes
3. **Add ONE system spec** - Only for the critical happy path

### When Refactoring Existing Tests

1. **Identify what each test is actually testing**
2. **Move database assertions to request specs**
3. **Move business logic to unit tests**
4. **Keep only UX assertions in system specs**

### Example Migration

**Before (System Spec Testing Everything):**
```ruby
# ❌ BAD: System spec testing database state
it 'correctly handles draft vs complete status' do
  visit page
  fill_form
  click_submit
  
  # Testing database state in system spec
  check_in = PositionCheckIn.find_by(teammate: teammate)
  expect(check_in.manager_completed_at).to be_present
end
```

**After (Properly Layered):**
```ruby
# ✅ GOOD: Request spec testing database state
it 'marks as completed with timestamp and person' do
  patch path, params: { status: "complete" }
  
  check_in = PositionCheckIn.find_by(teammate: teammate)
  expect(check_in.manager_completed_at).to be_present
end

# ✅ GOOD: System spec testing UX only
it 'manager can complete a check-in and see success message' do
  visit page
  fill_form
  click_submit
  
  expect(page).to have_content('Check-ins saved successfully')
end
```

## Common Anti-Patterns to Avoid

### ❌ Don't Test Database State in System Specs
```ruby
# BAD
it 'saves to database' do
  visit page
  click_button
  expect(Model.count).to eq(1)
end
```

### ❌ Don't Test Business Logic in System Specs
```ruby
# BAD
it 'calculates correct values' do
  visit page
  expect(page).to have_content('Calculated: 42')
end
```

### ❌ Don't Test Multiple Scenarios in One System Spec
```ruby
# BAD
it 'handles all edge cases' do
  # Test 1: Draft
  # Test 2: Complete
  # Test 3: Toggle
  # Test 4: Error cases
end
```

### ✅ Do Test UX in System Specs
```ruby
# GOOD
it 'shows success message after submission' do
  visit page
  click_button
  expect(page).to have_content('Success!')
end
```

## File Organization

```
spec/
├── models/           # Unit tests (70%)
│   ├── concerns/
│   ├── services/
│   └── ...
├── requests/         # Request specs (25%)
│   ├── organizations/
│   └── ...
└── system/           # System specs (5%)
    ├── abilities/
    ├── aspirations/
    ├── assignments/
    ├── check_ins/
    ├── finalization/
    ├── goals/
    ├── huddles/
    ├── misc/
    ├── observations/
    ├── positions_and_seats/
    └── teammates/
```

### System Spec Organization Rule
**All system specs must live in a folder underneath `spec/system/`**. System specs should be organized by feature area (e.g., `spec/system/goals/`, `spec/system/check_ins/`) rather than as flat files in the `spec/system/` directory.

## Running Tests

### ⚠️ IMPORTANT: Never Run Full Spec Suite
**Rule**: Do NOT run the full spec suite (`bundle exec rspec`) as it takes too long and can cause timeouts. Instead, always run specs in segments by type.

### Run by Type (Recommended Approach)
```bash
# Unit tests only
bundle exec rspec spec/models/

# Request specs only
bundle exec rspec spec/requests/

# System specs - run by folder (each folder is a segment)
bundle exec rspec spec/system/abilities/
bundle exec rspec spec/system/aspirations/
bundle exec rspec spec/system/assignments/
bundle exec rspec spec/system/check_ins/
bundle exec rspec spec/system/finalization/
bundle exec rspec spec/system/goals/
bundle exec rspec spec/system/huddles/
bundle exec rspec spec/system/misc/
bundle exec rspec spec/system/observations/
bundle exec rspec spec/system/positions_and_seats/
bundle exec rspec spec/system/teammates/
```

### Run Specific Feature
```bash
# All check-in tests
bundle exec rspec spec/models/concerns/check_in_behavior_spec.rb spec/requests/organizations/check_ins_spec.rb spec/system/position_check_in_happy_path_spec.rb
```

### Full Suite Run Tracking
When running a full suite (for comprehensive testing), always:
1. Run in segments as shown above
2. **Update `Last_full_spec_suite_run.md` immediately after each segment completes** - This includes:
   - Marking the segment status as "⏳ Running..." when starting
   - Updating with timing data, examples count, failures, and date/time when complete
   - Each system spec folder is a separate segment and must be updated individually
3. Include total examples, failures, and time for each segment
4. Document any issues found for follow-up

## Performance Targets

- **Unit tests**: < 0.01s each
- **Request specs**: < 0.1s each
- **System specs**: < 5s each
- **Full suite**: < 30s total

## Success Metrics

- ✅ Zero flaky tests
- ✅ Clear failure messages
- ✅ Fast feedback loop
- ✅ Confidence to refactor
- ✅ Happy developers 😊

## References

- [Rails Testing Best Practices](https://guides.rubyonrails.org/testing.html)
- [RSpec Request Specs](https://relishapp.com/rspec/rspec-rails/docs/request-specs/request-spec)
- [RSpec System Specs](https://relishapp.com/rspec/rspec-rails/docs/system-specs/system-spec)
