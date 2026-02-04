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
bundle exec rspec spec/system/check_in_observations/
bundle exec rspec spec/system/finalization/
bundle exec rspec spec/system/get_shit_done/
bundle exec rspec spec/system/goals/
bundle exec rspec spec/system/huddles/
bundle exec rspec spec/system/misc/
bundle exec rspec spec/system/observable_moments/
bundle exec rspec spec/system/observations/
bundle exec rspec spec/system/organizations/
bundle exec rspec spec/system/people/
bundle exec rspec spec/system/positions_and_seats/
bundle exec rspec spec/system/teammates/
bundle exec rspec spec/system/audit/
bundle exec rspec spec/system/vertical_navigation_spec.rb
bundle exec rspec spec/system/check_ins_save_and_redirect_spec.rb
bundle exec rspec spec/system/teammate_profile_links_spec.rb
```

### Run Specific Feature
```bash
# All check-in tests
bundle exec rspec spec/models/concerns/check_in_behavior_spec.rb spec/requests/organizations/check_ins_spec.rb spec/system/position_check_in_happy_path_spec.rb
```

### CI / Parallelization

To reduce full-suite wall-clock time and surface failures faster:

- **Split jobs**: Run unit + request segments in one CI job, and system specs in a separate job. Unit and request specs are faster and more reliable; run them first so most failures are caught without starting the browser.
- **Segment order**: Run Model → Controller → Request specs first (no browser). Then run system spec folders (Abilities, Aspirations, Assignments, Check-ins, etc.) in the order listed in "Segment Order" below. Optionally run system specs only on main/nightly.
- **Parallel segments**: Independent segments can be run in parallel (e.g. models + services + jobs in one job; requests + controllers in another; system in a third). Use a CI matrix or the `parallel_tests` gem to run multiple segments concurrently. Ensure each segment runs in isolation (clean DB, no shared state).
- **Tags**: System specs use `type: :system` (and often `js: true`). Tag slow or flaky examples if you need to run a fast subset (e.g. `rspec --tag ~slow`).

### Full Suite Run Tracking

**⚠️ CRITICAL RULE: One Segment Per Execution**
- **NEVER run multiple segments in the same command execution**
- Each segment must be run separately and tracked individually
- Wait for one segment to complete before starting the next

**When running a full suite (for comprehensive testing), follow this strict process:**

1. **Before starting each segment:**
   - Update `Last_full_spec_suite_run.md` to mark the segment status as "⏳ Running..."
   - **CRITICAL: Use ACTUAL current date/time** - Run `date '+%Y-%m-%d %H:%M:%S'` to get the current timestamp and use it for all date/time fields. NEVER use hardcoded dates or estimated times.
   - Record the start time for the segment using the actual current timestamp

2. **Run the segment:**
   - Execute only ONE segment at a time
   - Use the commands shown in "Run by Type" section above
   - Each system spec folder is treated as a separate segment

3. **After completing each segment:**
   - **CRITICAL: Use ACTUAL current date/time** - Run `date '+%Y-%m-%d %H:%M:%S'` immediately after the segment completes to get the exact completion timestamp
   - Update `Last_full_spec_suite_run.md` immediately with:
     - Segment status (✅ Complete, ❌ Error, etc.)
     - Timing data (execution time and total time with load)
     - Examples count
     - Failures count (or error details)
     - **Date/time of completion** - Use the actual timestamp from the `date` command, formatted as `YYYY-MM-DD HH:MM:SS`
   - If failures exist, parse RSpec output and add details to the "Failure Analysis" section at the bottom of the document

4. **Failure Analysis Section:**
   - Located at the bottom of `Last_full_spec_suite_run.md`
   - For each failed spec, include:
     - Spec file path
     - Line number (if available)
     - Test description
     - Error message (first line or key excerpt)
     - Suspected issue (based on error pattern)
   - Group similar failures together when possible

5. **Segment Order (MUST RUN ALL):**
   The following segments MUST be run in this exact order, and ALL segments must be completed:
   - Model Specs (`spec/models/`)
   - Controller Specs (`spec/controllers/`)
   - Request Specs (`spec/requests/`)
   - System Specs - Abilities (`spec/system/abilities/`)
   - System Specs - Aspirations (`spec/system/aspirations/`)
   - System Specs - Assignments (`spec/system/assignments/`)
   - System Specs - Check-ins (`spec/system/check_ins/`)
   - System Specs - Check-in Observations (`spec/system/check_in_observations/`)
   - System Specs - Finalization (`spec/system/finalization/`)
   - System Specs - Get Shit Done (`spec/system/get_shit_done/`)
   - System Specs - Goals (`spec/system/goals/`)
   - System Specs - Huddles (`spec/system/huddles/`)
   - System Specs - Misc (`spec/system/misc/`)
   - System Specs - Observable Moments (`spec/system/observable_moments/`)
   - System Specs - Observations (`spec/system/observations/`)
   - System Specs - Organizations (`spec/system/organizations/`)
   - System Specs - People (`spec/system/people/`)
   - System Specs - Positions and Seats (`spec/system/positions_and_seats/`)
   - System Specs - Teammates (`spec/system/teammates/`)
   - System Specs - Audit (`spec/system/audit/`)
   - System Specs - vertical_navigation (`spec/system/vertical_navigation_spec.rb`)
   - System Specs - check_ins_save_and_redirect (`spec/system/check_ins_save_and_redirect_spec.rb`)
   - System Specs - teammate_profile_links (`spec/system/teammate_profile_links_spec.rb`)
   - ENM Specs (`spec/enm/`)
   
   **Do not stop after a few segments - continue until ALL segments are complete.**

### Command Triggers for Segmented Spec Running

The following command phrases will trigger the segmented spec running process:
- "run full spec suite"
- "run all specs"
- "run complete test suite"
- "run segmented specs"
- "run specs in segments"

**⚠️ CRITICAL: When any of these phrases are used, the assistant MUST:**
1. **Run ALL segments** in the order specified above (Model Specs → Controller Specs → Request Specs → all System Spec segments → ENM Specs)
2. **Never stop early** - Continue running all segments until the complete suite is finished
3. Run segments one at a time in the order specified above
4. Update `Last_full_spec_suite_run.md` before and after each segment with **actual current date/time** (use `date '+%Y-%m-%d %H:%M:%S'` command)
5. Parse failures and add them to the Failure Analysis section
6. Never run multiple segments in a single execution
7. Update the "Run Date" and "Started" timestamp at the top of `Last_full_spec_suite_run.md` with the actual current date/time when beginning the run

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
