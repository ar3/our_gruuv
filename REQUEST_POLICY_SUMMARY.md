# Request/Policy Spec Status

## Summary
4 request/policy spec failures identified:

### 1. SearchPolicy (1 failure)
- **Issue**: No `index?` method defined in `SearchPolicy`
- **Fix**: Add `def index?; show?; end` or similar

### 2. Request Specs (3 failures)
All have the same issue:
- **Issue**: `current_organization` is `nil` in the layout
- **Location**: `app/views/layouts/authenticated-v2-0.html.haml:109`
- **Error**: `No route matches {action: "show", controller: "organizations/search", organization_id: nil}`
- **Affected specs**: 
  - `spec/requests/employment_tenures_spec.rb:20`
  - `spec/requests/organizations_spec.rb:11`
  - `spec/requests/organizations_spec.rb:27`

## Fixes Needed

### Fix 1: Add index? to SearchPolicy
```ruby
class SearchPolicy < ApplicationPolicy
  def show?
    user.present?
  end
  
  def index?
    user.present?  # Same as show?
  end
  
  class Scope < Scope
    def resolve
      scope
    end
  end
end
```

### Fix 2: Mock current_organization in request specs
The specs need to set up `current_organization` or the layout needs to handle nil gracefully.

## Progress
- Core unit specs: ✅ Complete (118/118 passing)
- Request/Policy: 4 failures identified (should be quick fixes)
- System specs: 25 failures (browser automation complexity)

