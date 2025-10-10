# Milestone Attainment Implementation Plan

## Overview

Create a complete milestone attainment system that allows managers and users with `can_manage_employment` permission to award milestones to teammates. The interface will show relevant context including how long the person has been on assignments requiring the ability and any observations related to the ability.

**Note**: This plan includes renaming `PersonMilestone` model and `person_milestones` table to `TeammateM milestone` and `teammate_milestones` for consistency, since the model belongs to `teammate` not `person`.

**Note**: No index page needed - use existing `celebrate_milestones` page as the index

## Phase 1: Model Rename (First Priority)

### 1. Create Migration to Rename Table

**File**: `db/migrate/YYYYMMDDHHMMSS_rename_person_milestones_to_teammate_milestones.rb`

```ruby
class RenamePersonMilestonesToTeammateMilestones < ActiveRecord::Migration[8.0]
  def change
    rename_table :person_milestones, :teammate_milestones
  end
end
```

### 2. Rename Model File

- Rename: `app/models/person_milestone.rb` → `app/models/teammate_milestone.rb`
- Update class name: `PersonMilestone` → `TeammateM milestone`
- Keep all associations and validations the same (already uses `belongs_to :teammate`)

### 3. Update Model Associations

Update has_many associations in these files:

- `app/models/teammate.rb`: `has_many :person_milestones` → `has_many :teammate_milestones`
- `app/models/ability.rb`: `has_many :person_milestones` → `has_many :teammate_milestones`
- Update method names like `person_attainments` to reference teammate_milestones

### 4. Update Factories

- Rename: `spec/factories/person_milestones.rb` → `spec/factories/teammate_milestones.rb`
- Update factory definition: `:person_milestone` → `:teammate_milestone`

### 5. Update Specs

- Rename: `spec/models/person_milestone_spec.rb` → `spec/models/teammate_milestone_spec.rb`
- Update all references to `PersonMilestone` → `TeammateM milestone`

### 6. Update All References

Search and replace in these files/directories:

- Controllers: `app/controllers/` (especially organizations/people_controller.rb)
- Services: `app/services/` (especially maap_change_detection_service.rb, maap_data/)
- Models: `app/models/person.rb` (has helper methods referencing person_milestones)
- Views: `app/views/` (especially execute_changes partials, complete_picture views)
- Migrations: Check if any seed data or other migrations reference it
- Tests: All spec files

## Phase 2: New Milestone Attainment System

### 1. Service Layer

**File**: `app/services/milestone_attainment_service.rb`

- Create service following Result pattern from `lib/result.rb`
- Handle milestone creation with transaction boundary
- Check for duplicate milestones (same teammate + ability + level)
- Return `Result.ok(milestone)` or `Result.err(message)`

### 2. Form Layer

**File**: `app/forms/milestone_attainment_form.rb`

- Use Reform with ActiveModel validations (per `docs/RULES/forms-validation.md`)
- Properties: `teammate_id`, `ability_id`, `milestone_level`, `attained_at`
- Virtual property: `ability_filter` (for toggling relevant vs all abilities)
- Validates presence of all required fields
- Call `MilestoneAttainmentService` in `save` method

### 3. Policy Layer

**File**: `app/policies/teammate_milestone_policy.rb`

- Authorization: managers OR users with `can_manage_employment`
- Use `Teammate.can_manage_employment_in_hierarchy?` pattern (line 114-142 in `app/models/teammate.rb`)
- Methods: `create?`, `new?`, `show?`

### 4. Controller Layer

**File**: `app/controllers/organizations/teammate_milestones_controller.rb`

- Nested under organizations: `/organizations/:organization_id/teammate_milestones`
- Actions: `new`, `create`, `show` (no index - use celebrate_milestones page)
- Authorization using Pundit `authorize TeammateM milestone`
- `new` action preparation:
  - Load all teammates for organization
  - Calculate relevant abilities (from active assignment requirements)
  - Calculate all abilities (from organization)
  - Load assignment tenure data for each ability
  - Load observations for teammate + ability combination
- Redirect to `celebrate_milestones_organization_path` after creation

### 5. Routes

**File**: `config/routes.rb`

- Add nested resource in organizations block (around line 97):
  ```ruby
  resources :teammate_milestones, module: :organizations, only: [:new, :create, :show]
  ```

### 6. Views

**File**: `app/views/organizations/teammate_milestones/new.html.haml`

- Header with back link to celebrate_milestones
- Form with teammate selector (dropdown)
- Ability selector with filter toggle (relevant vs all)
- Milestone level selector (1-5 with descriptions from ability)
- Date picker for attained_at (defaults to today)
- Context section showing:
  - Assignment tenure information (each assignment requiring ability + duration)
  - Observations about this ability (all observations with rating badges)

**File**: `app/views/organizations/teammate_milestones/show.html.haml`

- Display milestone details
- Show certified_by, attained_at, ability details
- Link to teammate's complete_picture page

### 7. Update Existing Pages

**File**: `app/views/organizations/celebrate_milestones.html.haml`

- Change line 20 from `milestones_overview_path` to `new_organization_teammate_milestone_path(@organization)`
- Update button text to "Award Milestone"

**File**: `app/views/organizations/people/complete_picture.html.haml`

- Add "Award Milestone" button in milestones section
- Link to `new_organization_teammate_milestone_path(@current_organization, teammate_id: teammate.id)`
- Only show if user has `can_manage_employment?` permission

### 8. Helper Methods

**File**: `app/helpers/teammate_milestones_helper.rb`

- `milestone_level_name(level)` - Returns friendly names (Demonstrated, Advanced, Expert, Coach, Industry-Recognized)
- `milestone_level_options` - Returns array for select dropdown
- `assignment_tenure_duration(tenure)` - Calculate duration display
- `observation_rating_badge(rating)` - Display rating with color

## Phase 3: Testing

### Test Files to Create

1. `spec/services/milestone_attainment_service_spec.rb`
2. `spec/forms/milestone_attainment_form_spec.rb`
3. `spec/policies/teammate_milestone_policy_spec.rb`
4. `spec/controllers/organizations/teammate_milestones_controller_spec.rb`
5. **`spec/features/teammate_milestone_attainment_spec.rb`** - End-to-end feature spec for the form

### Test Files to Update

1. `spec/models/teammate_milestone_spec.rb` - Update after rename
2. Other specs that reference PersonMilestone

### End-to-End Feature Spec Requirements

- Test the complete milestone awarding workflow
- Test teammate selection
- Test ability filtering (relevant vs all)
- Test milestone level selection
- Test context display (assignment tenure + observations)
- Test form validation
- Test successful milestone creation
- Test redirect to celebrate_milestones page
- Test authorization (only managers/can_manage_employment can access)

## Summary of Files

### Files to Create

1. `db/migrate/YYYYMMDDHHMMSS_rename_person_milestones_to_teammate_milestones.rb`
2. `app/services/milestone_attainment_service.rb`
3. `app/forms/milestone_attainment_form.rb`
4. `app/policies/teammate_milestone_policy.rb`
5. `app/controllers/organizations/teammate_milestones_controller.rb`
6. `app/helpers/teammate_milestones_helper.rb`
7. `app/views/organizations/teammate_milestones/new.html.haml`
8. `app/views/organizations/teammate_milestones/show.html.haml`
9. **`spec/features/teammate_milestone_attainment_spec.rb`** - End-to-end feature spec
10. Test files for all new code

### Files to Rename

1. `app/models/person_milestone.rb` → `app/models/teammate_milestone.rb`
2. `spec/models/person_milestone_spec.rb` → `spec/models/teammate_milestone_spec.rb`
3. `spec/factories/person_milestones.rb` → `spec/factories/teammate_milestones.rb`

### Files to Modify (PersonMilestone → TeammateM milestone)

1. `app/models/teammate.rb` - Update association
2. `app/models/ability.rb` - Update association and methods
3. `app/models/person.rb` - Update helper methods
4. `app/controllers/organizations/people_controller.rb` - Update references
5. `app/controllers/people_controller.rb` - Update references
6. `app/services/maap_change_detection_service.rb` - Update references
7. `app/services/maap_data/bulk_check_in_finalization_processor.rb` - Update references
8. `app/views/organizations/celebrate_milestones.html.haml` - Update references + add link
9. `app/views/organizations/people/complete_picture.html.haml` - Update references + add button
10. `app/views/people/execute_changes/_milestones_section.html.haml` - Update references
11. `config/routes.rb` - Add new routes (only new, create, show)
12. All spec files that reference PersonMilestone

## Implementation Order

1. Phase 1 (Rename) - Ensures consistency before building new features
2. Phase 2 (New System) - Build on clean foundation
3. Phase 3 (Testing) - Comprehensive test coverage


