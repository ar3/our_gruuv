# Testing Strategy

## The Testing Pyramid

### Unit Specs (Most tests, fastest)
- Models, decorators, services, policies, queries, jobs
- Test individual components in isolation
- Run on every save

### Request Specs (Moderate number, fast)
- Test controller actions, HTTP responses, redirects
- Test authorization, validations, state changes
- No browser required (Rack-level testing)
- These ARE your integration tests

### System Specs (Fewest tests, slowest)
- Test critical end-to-end user workflows
- Use real browser (Capybara + Selenium)
- Test JavaScript interactions, full UI
- Tagged as `:critical`, excluded by default

## Form Testing Requirements

**Every form MUST have 2 system specs:**
1. Simple submission (minimal data)
2. Complex submission (all fields, edge cases)

**Every major page MUST have 1 system spec:**
- Navigation to page
- Page renders without errors
- Key UI elements present

## Critical Paths (Always Test)

1. **Check-ins workflow** (highest priority)
2. **Form submissions** (all forms)
3. **Major page rendering** (dashboard, indexes)
4. **Authentication flows** (login, OAuth)

## Migration Status

- ✅ 24 request specs (keep)
- ❌ 11 feature specs → migrate to system specs
- ❌ 4 view specs → delete
- ✅ 1 system spec (expand)

## Development Workflow

```bash
# Fast development (excludes critical system specs)
bundle exec rspec --tag ~critical

# Pre-deployment (runs all tests including critical paths)
bundle exec rspec --tag critical
bundle exec rspec  # or run all
```

## Spec Maintenance Rules

1. **Request specs are primary** - Fast feedback, always run
2. **System specs are sacred** - Never delete, always update when features change
3. **2 system specs minimum per form** - Simple & complex scenarios
4. **1 system spec minimum per major page** - Happy path rendering
5. **Request + System coverage for critical flows** - Both layers of testing
6. **Full E2E system spec for check-ins** - This is the money maker

## Decision Framework

### Use Request Specs When:
1. **Testing controller logic** - Does the endpoint return 200? Redirect correctly?
2. **Testing authorization** - Can user access this action? Proper 403/404?
3. **Testing validations** - Does bad data return 422 with errors?
4. **Testing API responses** - JSON structure, status codes
5. **Testing state changes** - Record created? Attributes updated?
6. **Bug reproduction** - Quick feedback loop for backend issues

### Use System Specs When:
1. **Testing complete user workflows** - Multi-step forms, wizards
2. **Testing JavaScript interactions** - Dynamic forms, AJAX, modals
3. **Testing UI rendering** - Page loads without errors, correct content displays
4. **Testing form submissions** - Fill in fields, click buttons, see results
5. **Testing critical paths** - End-to-end flows users MUST be able to complete
6. **Testing integrations** - OAuth flows, external services

## Examples

### Request Spec Example
```ruby
it 'creates the ability successfully' do
  post organization_abilities_path(organization), params: { ability: {...} }
  expect(response).to have_http_status(:redirect)
  expect(Ability.last.name).to eq('Test Ability')
end
```

### System Spec Example
```ruby
scenario 'creating a new huddle when not logged in' do
  visit new_huddle_path
  fill_in 'New company name', with: 'New Company'
  click_button 'Start Huddle'
  expect(page).to have_content('Huddle created successfully!')
end
```
