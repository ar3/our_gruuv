# Authorization Vision

## Overview
The system will use a hybrid authorization approach combining role-based access control (RBAC) with discrete permissions per organization.

## Role Structure
- **Admin**: Global role with access to all system features
  - Stored as a boolean flag on the Person model
  - Only role we'll implement initially
  - Bypasses all organization-level permission checks

## Organization-Level Permissions
- Stored in a `person_organization_permissions` model
- Each permission is a boolean toggle (e.g., "edit organization", "view employment history")
- Permissions can be inherited from parent organizations
- Child organizations can override inherited permissions

## Permission Inheritance Rules
1. **Company Level**: Base permissions for the entire company
2. **Department Level**: Inherits from company, can override specific permissions
3. **Team Level**: Inherits from department, can override specific permissions
4. **Override Logic**: If a permission is explicitly set to false at a child level, it overrides the parent's true value

## Example Permission Flow
```
Company A: edit_organization = true
├── Department X: edit_organization = true (inherited)
│   ├── Team Y: edit_organization = false (overridden)
│   └── Team Z: edit_organization = true (inherited)
└── Department W: edit_organization = false (overridden)
    └── Team V: edit_organization = false (inherited)
```

## Permission Model Structure
```ruby
class PersonOrganizationPermission < ApplicationRecord
  belongs_to :person
  belongs_to :organization
  
  # Boolean permissions
  field :edit_organization, default: false
  field :view_employment_history, default: false
  field :manage_assignments, default: false
  # ... other permissions as needed
end
```

## Implementation Notes
- Permissions should be cached for performance
- Permission checks should be centralized in policy objects
- UI should clearly show inherited vs overridden permissions
- Admin role should bypass all permission checks
