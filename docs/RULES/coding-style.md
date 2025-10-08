# Coding Style Guide

This document defines the coding standards and style conventions for this Rails application.

## Code Organization & Architecture

### Service Objects & Jobs
- Keep service objects small and use inversion of control
- Delegate complex actions to dedicated job classes (one method per class) under a namespace (e.g., `Huddles`)
- Jobs should be idempotent (handling creation or update)
- Jobs should be named with a verb and a noun, for example `Huddles::PostAnnouncementJob`

### Slack Integration
- `SlackService` `post_message` and `update_message` should accept `notifiable_type`, `notifiable_id`, and `main_thread_id`, with no huddle-specific logic
- Default Slack bot username should be 'OG'

## Authorization & Security

### Pundit Authorization
- **Always use Pundit for authorization** - never implement inline authorization logic in controllers
- **Create dedicated policy classes** for each model that needs authorization
- **Use `verify_authorized` and `verify_policy_scoped` callbacks** in all controllers
- **Centralize permission logic** in policy objects, not in controllers or models
- **Admin role should be simple** - use a boolean flag (`og_admin`) that bypasses all permission checks
- **Test policies independently** from controllers for better maintainability

### Authorization Patterns
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

## View Organization & Partials

### Partial Rendering Rules
- **Always use full paths for partials** - never use relative paths
- **Organize partials in logical subdirectories** - use `spotlights/`, `forms/`, `cards/` folders
- **Use descriptive partial names** - avoid generic names like `_item.html.haml`
- **Test partial rendering** - verify partials can be found and rendered correctly

### Partial Path Examples
```haml
/ CORRECT - Full path from app/views/
= render 'upload_events/spotlights/upload_data_overview'
= render 'organizations/cards/team_summary'
= render 'shared/forms/error_messages'

/ INCORRECT - Relative paths (will cause MissingTemplate errors)
= render 'spotlights/upload_data_overview'
= render '../shared/error_messages'
= render './partial_name'
```

### Partial Organization Structure
```
app/views/
├── [resource]/
│   ├── spotlights/          # Data overview partials
│   ├── forms/               # Form partials
│   ├── cards/               # Card component partials
│   └── index.html.haml
├── shared/                  # Cross-resource partials
│   ├── forms/
│   ├── cards/
│   └── modals/
```

### Partial Naming Conventions
- **Spotlights**: `_[resource]_overview.html.haml` (e.g., `_upload_data_overview.html.haml`)
- **Forms**: `_[form_name].html.haml` (e.g., `_user_registration.html.haml`)
- **Cards**: `_[card_name].html.haml` (e.g., `_team_summary.html.haml`)
- **Modals**: `_[modal_name].html.haml` (e.g., `_confirmation_dialog.html.haml`)

### Partial Testing Checklist
Before committing partials:
- [ ] Partial file exists in correct directory
- [ ] Render call uses full path from `app/views/`
- [ ] Partial renders without errors
- [ ] All required instance variables are available
- [ ] Partial follows naming conventions

## Display & Presentation

### Display Names
- When displaying names/titles of objects in views, use a `display_name` method, ideally on the decorator object
- This ensures separation of concerns and makes it easier to make adjustments in the future if we want to display an object differently

### Decorator Usage
- **Always decorate collections and records** before passing to views using `.decorate`
- **Use decorators for presentation logic** - keep models focused on business logic
- **Apply includes before decorate** for performance: `Model.includes(:associations).decorate`
- **Create dedicated decorator classes** for complex presentation logic

## Database & Query Optimization

### Database Field Naming
- **Date fields**: Use `_on` suffix (e.g., `check_in_started_on`, `check_in_ended_on`, `started_at`, `ended_at`)
- **Timestamp fields**: Use `_at` suffix (e.g., `created_at`, `updated_at`)

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

## Enums

### Use Descriptive String Values, Not Integers

**✅ Good:**
```ruby
enum :privacy_level, {
  observer_only: 'observer_only',
  observed_only: 'observed_only',
  managers_only: 'managers_only',
  observed_and_managers: 'observed_and_managers',
  public_observation: 'public_observation'
}
```

**❌ Avoid:**
```ruby
enum :privacy_level, {
  observer_only: 0,
  observed_only: 1,
  managers_only: 2,
  observed_and_managers: 3,
  public_observation: 4
}
```

### Why Descriptive Enums Are Better

1. **Readability**: Database values are self-documenting
2. **Debugging**: Easier to understand what values mean in logs/queries
3. **Maintenance**: No need to remember what integer 3 means
4. **Database Queries**: More readable when writing raw SQL
5. **API Responses**: JSON responses are more meaningful
6. **Migration Safety**: Adding new values doesn't require careful ordering

### Migration Pattern

When converting from integer to descriptive enums:

```ruby
class ChangeEnumToDescriptive < ActiveRecord::Migration[8.0]
  def up
    # Add temporary string column
    add_column :table_name, :column_name_string, :string
    
    # Migrate data
    execute <<-SQL
      UPDATE table_name 
      SET column_name_string = CASE column_name
        WHEN 0 THEN 'value_one'
        WHEN 1 THEN 'value_two'
        WHEN 2 THEN 'value_three'
        ELSE 'default_value'
      END
    SQL
    
    # Remove old column and rename new one
    remove_column :table_name, :column_name
    rename_column :table_name, :column_name_string, :column_name
    
    # Add constraints
    change_column_null :table_name, :column_name, false
    change_column_default :table_name, :column_name, 'default_value'
  end

  def down
    # Reverse migration...
  end
end
```

### Testing Descriptive Enums

```ruby
describe 'enums' do
  it 'defines enum with descriptive values' do
    expect(Model.enum_name).to eq({
      'value_one' => 'value_one',
      'value_two' => 'value_two',
      'value_three' => 'value_three'
    })
  end
end
```

### Exception: Performance-Critical Enums

Only use integer enums when:
- The enum has 10+ values
- Database performance is critical
- Storage space is a major concern

Even then, consider if the readability benefits outweigh the performance costs.

## Policies

### Always Use `actual_user` Instead of `user`

**✅ Good:**
```ruby
class ObservationPolicy < ApplicationPolicy
  def show?
    actual_user == record.observer
  end

  def create?
    actual_user.present?
  end

  private

  def user_in_observees?
    return false unless actual_user.is_a?(Person)
    record.observed_teammates.any? { |teammate| teammate.person == actual_user }
  end
end
```

**❌ Avoid:**
```ruby
class ObservationPolicy < ApplicationPolicy
  def show?
    user == record.observer  # Wrong - bypasses impersonation
  end

  def create?
    user.present?  # Wrong - bypasses impersonation
  end
end
```

### Why Use `actual_user`?

1. **Impersonation Support**: The `user` parameter may be a wrapper object that supports impersonation
2. **Consistency**: All existing policies use `actual_user` (99+ instances across codebase)
3. **Admin Bypass**: The `admin_bypass?` method uses `real_user` to prevent impersonation bypass
4. **Future-Proof**: Supports authentication system changes without breaking policies

### Policy Pattern

```ruby
class ApplicationPolicy
  # Helper method to get the actual user from pundit_user
  def actual_user
    user.respond_to?(:user) ? user.user : user
  end

  # Admin bypass - og_admin users get all permissions
  def admin_bypass?
    # Check if the real user (not impersonated) is an admin
    real_user = user.respond_to?(:real_user) ? user.real_user : actual_user
    real_user&.admin?
  end
end
```

### Testing Policies

When testing policies, use the actual user object, not wrapper objects:

```ruby
# ✅ Good
expect(subject).to permit(actual_person, record)

# ❌ Avoid
expect(subject).to permit(wrapper_user, record)
```

## Form Objects & Controller Actions

### Use Form Objects for Create/Update Actions

**✅ Good - Use Reform Forms:**
```ruby
class ObservationForm < Reform::Form
  property :story
  property :privacy_level
  property :primary_feeling
  property :secondary_feeling
  property :observed_at
  property :custom_slug
  
  validates :story, presence: true
  validates :privacy_level, presence: true
  validates :primary_feeling, inclusion: { in: Feelings::FEELINGS.map { |f| f[:discrete_feeling].to_s } }
  
  def save
    return false unless valid?
    super
    model.save
  end
end

# In controller:
def create
  authorize Observation.new(company: @company)
  
  @form = ObservationForm.new(Observation.new(company: @company))
  @form.current_person = current_person
  
  if @form.validate(observation_params) && @form.save
    redirect_to organization_observation_path(@company, @form.model)
  else
    render :new, status: :unprocessable_entity
  end
end
```

**✅ Good - Use ActiveModel Forms for Simpler Cases:**
```ruby
class SimpleForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :name, :string
  attribute :description, :string
  
  validates :name, presence: true
  validates :description, presence: true
  
  def save
    return false unless valid?
    # Custom save logic here
    true
  end
end
```

**❌ Avoid - Direct Model Updates in Controllers:**
```ruby
def create
  @observation = Observation.new(observation_params)
  if @observation.save
    # Complex logic mixed in controller
    create_observees
    create_ratings
    send_notifications
    redirect_to @observation
  else
    render :new
  end
end
```

### Form Object Benefits

1. **Separation of Concerns**: Form logic separated from controller logic
2. **Reusability**: Forms can be used in multiple contexts (web, API, etc.)
3. **Testability**: Forms can be tested independently
4. **Complex Validation**: Handle multi-step validation and nested attributes
5. **Clean Controllers**: Controllers focus on HTTP concerns, not business logic

### When to Use Each Type

**Use Reform Forms when:**
- Complex nested attributes (has_many, belongs_to)
- Multi-step validation logic
- Need to sync multiple models
- Complex form state management

**Use ActiveModel Forms when:**
- Simple single-model forms
- Basic validation needs
- Custom save logic that doesn't fit Reform patterns

### Controller Pattern

```ruby
class ObservationsController < ApplicationController
  def new
    @form = ObservationForm.new(Observation.new(company: @company))
    @form.current_person = current_person
    authorize @form.model
  end

  def create
    authorize Observation.new(company: @company)
    
    @form = ObservationForm.new(Observation.new(company: @company))
    @form.current_person = current_person
    
    if @form.validate(observation_params) && @form.save
      redirect_to organization_observation_path(@company, @form.model)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @form = ObservationForm.new(@observation)
    @form.current_person = current_person
    authorize @observation
  end

  def update
    authorize @observation
    
    @form = ObservationForm.new(@observation)
    @form.current_person = current_person
    
    if @form.validate(observation_params) && @form.save
      redirect_to organization_observation_path(@company, @observation)
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
```

## Testing Standards

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

### Integration Testing (Critical for Controller Parameter Issues)
- **Always write integration tests for form submissions** - test actual browser parameter behavior, not just unit tests
- **Test array parameters correctly** - ensure `teammate_ids: []` is permitted as `teammate_ids: []`, not `:teammate_ids`
- **Test Rails checkbox behavior** - verify empty checkbox arrays (`[""]`) are handled correctly
- **Test form value preservation** - ensure form values persist on validation failure
- **Test the complete user flow** - from form submission through controller to model creation
- **Use request specs for integration testing** - not controller specs which bypass parameter processing

### Integration Testing Anti-Patterns to Avoid
- **Don't rely only on unit tests** - they bypass the actual controller parameter processing
- **Don't test with different parameters than the browser sends** - use `observees_attributes` when browser sends `teammate_ids[]`
- **Don't skip parameter permitting tests** - Rails silently filters out unpermitted parameters
- **Don't assume form objects work the same as direct model assignment** - test the actual form submission flow

### Integration Testing Pattern
```ruby
# ✅ Good - Test actual browser behavior
RSpec.describe 'Observation Form Submission', type: :request do
  let(:params) do
    {
      organization_id: company.id,
      observation: {
        story: 'Great work!',
        teammate_ids: [teammate1.id.to_s, teammate2.id.to_s]  # Array as browser sends
      }
    }
  end

  it 'creates observation with observees' do
    expect {
      post organization_observations_path(company), params: params
    }.to change(Observation, :count).by(1)
     .and change(Observee, :count).by(2)
  end
end

# ❌ Avoid - Testing different parameters than browser sends
RSpec.describe 'Observation Creation', type: :controller do
  let(:params) do
    {
      observation: {
        observees_attributes: { '0' => { teammate_id: teammate.id } }  # Different from browser
      }
    }
  end
end
```

## Form Testing Requirements (Critical for All Forms)

### Mandatory Feature Specs for All Forms

**Every form in the application MUST have comprehensive feature specs that follow these requirements:**

#### 1. **Complete User Flow Testing**
- **Test the full user journey**: Index → Create → Show → Back to Index
- **Test all form steps**: Multi-step forms must test each step explicitly
- **Test navigation**: Verify all links and buttons work correctly
- **Test form state persistence**: Values should persist across steps and validation failures

#### 2. **Explicit Assertions (No Conditional Logic)**
- **NEVER use conditional logic** (`if`, `unless`, `any?`) in feature specs
- **Always assert expected state** before interacting with elements
- **Fail loudly** when expected elements are missing
- **Verify page state** at each step before proceeding

```ruby
# ✅ Good - Explicit assertions
expect(page).to have_css('select[name*="observation[observation_ratings_attributes]"]', count: 2)
ability_selects = page.all('select[name*="observation[observation_ratings_attributes]"]')
ability_selects.first.select('Strongly Agree (Exceptional)')

# ❌ Bad - Conditional logic masks failures
ability_selects = page.all('select[name*="observation[observation_ratings_attributes]"]')
if ability_selects.any?
  ability_selects.first.select('Strongly Agree (Exceptional)')
end
```

#### 3. **Form Validation Testing**
- **Test validation errors**: Submit invalid data and verify error messages
- **Test form value preservation**: Values should persist on validation failure
- **Test required field validation**: Ensure required fields are enforced
- **Test custom validations**: Test business logic validations

#### 4. **Multiple Data Scenarios**
- **Test with no data**: Empty state, no related records
- **Test with minimal data**: Single record scenarios
- **Test with multiple data**: Multiple records, complex scenarios
- **Test edge cases**: Boundary conditions, special characters

#### 5. **UI Element Verification**
- **Verify all form elements**: Inputs, selects, checkboxes, buttons
- **Verify navigation elements**: Links, back buttons, action buttons
- **Verify modal elements**: If forms use modals, test modal behavior
- **Verify responsive elements**: Mobile-friendly interactions

### Form Testing Anti-Patterns to Avoid

#### ❌ **Never Use Conditional Logic**
```ruby
# ❌ Bad - Masks real failures
if page.has_css?('.error')
  expect(page).to have_content('Error message')
end

# ✅ Good - Fails loudly if element missing
expect(page).to have_css('.error')
expect(page).to have_content('Error message')
```

#### ❌ **Never Skip Assertions**
```ruby
# ❌ Bad - Assumes elements exist
click_button 'Submit'

# ✅ Good - Verifies elements exist first
expect(page).to have_button('Submit')
click_button 'Submit'
```

#### ❌ **Never Test Different Data Than Browser Sends**
```ruby
# ❌ Bad - Tests different parameters than browser
let(:params) { { observation: { observees_attributes: {...} } } }

# ✅ Good - Tests actual browser parameters
let(:params) { { observation: { teammate_ids: [...] } } }
```

### Required Feature Spec Structure

Every form must have at least these feature specs:

```ruby
RSpec.feature 'FormName Complete Flow', type: :feature do
  describe 'Complete form flow scenarios' do
    it 'creates record with no related data available' do
      # Test empty state scenario
    end

    it 'creates record with related data and selects some' do
      # Test with data available scenario
    end

    it 'creates record with all optional fields filled' do
      # Test complete form scenario
    end

    it 'creates record with minimal required fields only' do
      # Test minimal scenario
    end
  end

  describe 'Form validation and error handling' do
    it 'shows validation errors and preserves form values' do
      # Test validation failure scenario
    end
  end

  describe 'Navigation and UI elements' do
    it 'navigates correctly between all pages' do
      # Test navigation flow
    end

    it 'shows all expected UI elements' do
      # Test UI element presence
    end
  end
end
```

### Form Testing Checklist

Before considering any form complete, verify:

- [ ] **Complete user flow tested** (Index → Create → Show → Back to Index)
- [ ] **All form steps tested** (for multi-step forms)
- [ ] **No conditional logic** in feature specs
- [ ] **Explicit assertions** before all interactions
- [ ] **Validation error testing** with form value preservation
- [ ] **Multiple data scenarios** tested
- [ ] **UI elements verified** (buttons, links, modals)
- [ ] **Navigation tested** (all links and buttons work)
- [ ] **Edge cases covered** (empty state, minimal data, complex data)
- [ ] **Integration tests** for parameter processing
- [ ] **Form object specs** for validation logic

### Enforcement

**This rule is MANDATORY for all forms.** Any form without comprehensive feature specs following these patterns will be rejected in code review.

**Why This Matters:**
- **Catches real bugs** instead of masking them
- **Ensures consistent user experience** across all forms
- **Prevents production issues** by testing actual browser behavior
- **Maintains code quality** through explicit testing patterns
- **Reduces debugging time** by failing fast with clear error messages
