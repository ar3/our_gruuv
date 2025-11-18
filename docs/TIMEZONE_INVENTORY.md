# Timezone Inventory

This document catalogs all datetime fields displayed in views that are missing timezone conversion. Fields are categorized by whether they require timezone conversion (DateTime/Time) or not (Date).

## Field Type Reference

### Date Fields (No Timezone Conversion Needed)
- `earliest_target_date`, `most_likely_target_date`, `latest_target_date` (Goal)
- `check_in_started_on`, `check_in_ended_on` (CheckIn models)
- `check_in_week_start` (GoalCheckIn)
- `attained_at` (TeammateMilestone)
- Any field ending in `_on` that represents a calendar date

### DateTime/Time Fields (Timezone Conversion REQUIRED)
- `created_at`, `updated_at` (all models)
- `started_at`, `completed_at`, `deleted_at`, `became_top_priority` (Goal)
- `observed_at`, `published_at` (Observation)
- `employee_completed_at`, `manager_completed_at`, `official_check_in_completed_at` (PositionCheckIn, AspirationCheckIn)
- `started_at`, `ended_at` (EmploymentTenure)
- All notification timestamps
- Any field ending in `_at` that represents a specific moment in time

## Inventory by File

### app/views/organizations/goals/show.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 63: `@goal.started_at.strftime("%B %d, %Y at %I:%M %p")` → `format_time_in_user_timezone(@goal.started_at)`
- Line 66: `@goal.became_top_priority.strftime("%B %d, %Y at %I:%M %p")` → `format_time_in_user_timezone(@goal.became_top_priority)`
- Line 96: `@goal.completed_at.strftime("%B %d, %Y at %I:%M %p")` → `format_time_in_user_timezone(@goal.completed_at)`
- Line 106: `@goal.created_at.strftime("%B %d, %Y at %I:%M %p")` → `format_time_in_user_timezone(@goal.created_at)`
- Line 108: `@goal.updated_at.strftime("%B %d, %Y at %I:%M %p")` → `format_time_in_user_timezone(@goal.updated_at)`
- Line 242: `@goal.deleted_at.strftime("%B %d, %Y at %I:%M %p")` → `format_time_in_user_timezone(@goal.deleted_at)`
- Line 274: `@current_check_in.created_at.strftime('%B %d, %Y at %I:%M %p')` → `format_time_in_user_timezone(@current_check_in.created_at)`
- Line 305: `@last_check_in.created_at.strftime('%B %d, %Y')` → `format_time_in_user_timezone(@last_check_in.created_at)` (date-only format)

**Date Fields (No Conversion Needed):**
- Line 74: `@goal.earliest_target_date.strftime("%B %d, %Y")` ✓ (Date field)
- Line 78: `@goal.most_likely_target_date.strftime("%B %d, %Y")` ✓ (Date field)
- Line 82: `@goal.latest_target_date.strftime("%B %d, %Y")` ✓ (Date field)
- Line 145: `most_recent_check_in.check_in_week_start.strftime('%b %d, %Y')` ✓ (Date field)
- Line 207: `most_recent_check_in.check_in_week_start.strftime('%b %d, %Y')` ✓ (Date field)
- Line 270: `current_week_start.strftime('%B %d')` ✓ (Date field)
- Line 270: `current_week_end.strftime('%B %d, %Y')` ✓ (Date field)
- Line 332: `check_in.check_in_week_start.strftime("%B %d, %Y")` ✓ (Date field)

### app/views/organizations/goals/customize_view/styles/_check_in.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 44: `goal.started_at.strftime('%b %d, %Y')` → `format_time_in_user_timezone(goal.started_at)` (date-only format)
- Line 99: `goal.completed_at.strftime('%b %d, %Y')` → `format_time_in_user_timezone(goal.completed_at)` (date-only format)

**Date Fields (No Conversion Needed):**
- Line 9: `current_week_start.strftime('%B %d')` ✓ (Date field)
- Line 9: `current_week_end.strftime('%B %d, %Y')` ✓ (Date field)
- Line 51: `goal.most_likely_target_date.strftime('%b %d, %Y')` ✓ (Date field)

### app/views/organizations/goals/done.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 42: `check_in.created_at.strftime('%b %d, %Y at %I:%M %p')` → `format_time_in_user_timezone(check_in.created_at)`

### app/views/organizations/goals/customize_view/styles/_timeline.html.haml

**Date Fields (No Conversion Needed):**
- Line 26: `date.strftime('%B %d, %Y')` ✓ (Date field - grouped by date)
- Line 53: `goal.most_likely_target_date.strftime('%b %d')` ✓ (Date field)
- Line 69: `child_date.strftime('%b %d')` ✓ (Date field)

### app/views/organizations/goals/customize_view/styles/_cards.html.haml

**Date Fields (No Conversion Needed):**
- Line 21: `goal.most_likely_target_date.strftime('%b %d, %Y')` ✓ (Date field)

### app/views/organizations/goals/customize_view/styles/_list.html.haml

**Date Fields (No Conversion Needed):**
- Line 20: `goal.most_likely_target_date.strftime('%b %d, %Y')` ✓ (Date field)

### app/views/people/public.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 36: `observation.observed_at.strftime('%B %d, %Y')` → `format_time_in_user_timezone(observation.observed_at)` (date-only format)

**Date Fields (No Conversion Needed):**
- Line 73: `milestone.attained_at.strftime('%B %Y')` ✓ (Date field)

### app/views/organizations/teammates/position/show.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 104: `check_in.employee_completed_at.strftime('%m/%d/%Y %I:%M %p')` → `format_time_in_user_timezone(check_in.employee_completed_at)`
- Line 112: `check_in.manager_completed_at.strftime('%m/%d/%Y %I:%M %p')` → `format_time_in_user_timezone(check_in.manager_completed_at)`
- Line 123: `check_in.official_check_in_completed_at.strftime('%m/%d/%Y %I:%M %p')` → `format_time_in_user_timezone(check_in.official_check_in_completed_at)`

**Date Fields (No Conversion Needed):**
- Line 96: `check_in.check_in_started_on.strftime('%B %d, %Y')` ✓ (Date field)
- Line 98: `check_in.check_in_started_on.strftime('%I:%M %p')` ✓ (Date field - time portion should not exist, but if it does, it's still a Date)
- Line 157: `check_in.check_in_started_on.strftime('%B %d, %Y')` ✓ (Date field)

### app/views/organizations/observations/show.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 53: `@observation.observed_at.strftime('%B %d, %Y at %l:%M %p')` → `format_time_in_user_timezone(@observation.observed_at)`
- Line 59: `@observation.published_at.strftime('%B %d, %Y at %l:%M %p')` → `format_time_in_user_timezone(@observation.published_at)`
- Line 146: `notification.created_at.strftime('%m/%d/%y %l:%M %p')` → `format_time_in_user_timezone(notification.created_at)`
- Line 198: `@observation.created_at.strftime('%B %d, %Y')` → `format_time_in_user_timezone(@observation.created_at)` (date-only format)
- Line 202: `@observation.updated_at.strftime('%B %d, %Y')` → `format_time_in_user_timezone(@observation.updated_at)` (date-only format)

### app/views/kudos/show.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 53: `@observation.observed_at.strftime('%B %d, %Y at %l:%M %p')` → `format_time_in_user_timezone(@observation.observed_at)`
- Line 121: `notification.created_at.strftime('%m/%d/%y %l:%M %p')` → `format_time_in_user_timezone(notification.created_at)`
- Line 143: `@observation.created_at.strftime('%B %d, %Y')` → `format_time_in_user_timezone(@observation.created_at)` (date-only format)

### app/views/organizations/index.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 212: `huddle.created_at.strftime("%b %d, %Y")` → `format_time_in_user_timezone(huddle.created_at)` (date-only format)

### app/views/organizations/abilities/show.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 43: `@ability.created_at.strftime("%B %d, %Y at %I:%M %p")` → `format_time_in_user_timezone(@ability.created_at)`
- Line 45: `@ability.updated_at.strftime("%B %d, %Y at %I:%M %p")` → `format_time_in_user_timezone(@ability.updated_at)`
- Line 79: `@ability.created_at.strftime("%b %d, %Y")` → `format_time_in_user_timezone(@ability.created_at)` (date-only format)

### app/views/organizations/public_maap/aspirations/show.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 47: `observation.observed_at.strftime('%Y-%m-%d')` → `format_time_in_user_timezone(observation.observed_at)` (URL parameter format - may need custom helper)

### app/views/organizations/public_maap/abilities/show.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 65: `observation.observed_at.strftime('%Y-%m-%d')` → `format_time_in_user_timezone(observation.observed_at)` (URL parameter format - may need custom helper)

### app/views/organizations/public_maap/assignments/show.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 63: `observation.observed_at.strftime('%Y-%m-%d')` → `format_time_in_user_timezone(observation.observed_at)` (URL parameter format - may need custom helper)

### app/views/organizations/employees/displays/_check_ins_health.html.haml

**Date Fields (No Conversion Needed):**
- Line 39: `position_health[:open_check_in_started_on].strftime('%b %d, %Y')` ✓ (Date field)
- Line 42: `position_health[:last_rating_date].strftime('%b %d, %Y')` ✓ (Date field - if this is a Date, not DateTime)

### app/views/organizations/teammates/aspirations/show.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 51: `check_in.employee_completed_at.strftime('%m/%d/%Y %I:%M %p')` → `format_time_in_user_timezone(check_in.employee_completed_at)`
- Line 59: `check_in.manager_completed_at.strftime('%m/%d/%Y %I:%M %p')` → `format_time_in_user_timezone(check_in.manager_completed_at)`
- Line 70: `check_in.official_check_in_completed_at.strftime('%m/%d/%Y %I:%M %p')` → `format_time_in_user_timezone(check_in.official_check_in_completed_at)`

**Date Fields (No Conversion Needed):**
- Line 43: `check_in.check_in_started_on.strftime('%B %d, %Y')` ✓ (Date field)
- Line 45: `check_in.check_in_started_on.strftime('%I:%M %p')` ✓ (Date field - time portion should not exist)
- Line 104: `check_in.check_in_started_on.strftime('%B %d, %Y')` ✓ (Date field)

### app/views/organizations/check_ins_health/index.html.haml

**Date Fields (No Conversion Needed):**
- Line 109: `position_health[:open_check_in_started_on].strftime('%b %d, %Y')` ✓ (Date field)
- Line 112: `position_health[:last_rating_date].strftime('%b %d, %Y')` ✓ (Date field - if this is a Date, not DateTime)

### app/views/organizations/check_ins/_assignment_management_section.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 26: `previous_tenure.ended_at.strftime('%m/%d/%Y')` → `format_time_in_user_timezone(previous_tenure.ended_at)` (date-only format)
- Line 28: `data[:tenure].started_at.strftime('%m/%d/%Y')` → `format_time_in_user_timezone(data[:tenure].started_at)` (date-only format)
- Line 31: `most_recent.ended_at.strftime('%m/%d/%Y')` → `format_time_in_user_timezone(most_recent.ended_at)` (date-only format)

### app/views/people/assignments/show.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 128: `tenure.started_at.strftime('%m/%d/%Y')` → `format_time_in_user_timezone(tenure.started_at)` (date-only format)
- Line 131: `tenure.ended_at.strftime('%m/%d/%Y')` → `format_time_in_user_timezone(tenure.ended_at)` (date-only format)
- Line 180: `check_in.official_check_in_completed_at.strftime('%m/%d/%Y')` → `format_time_in_user_timezone(check_in.official_check_in_completed_at)` (date-only format)

**Date Fields (No Conversion Needed):**
- Line 158: `check_in.check_in_started_on.strftime('%m/%d/%Y')` ✓ (Date field)

### app/views/organizations/teammates/assignments/show.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 127: `tenure.started_at.strftime('%m/%d/%Y')` → `format_time_in_user_timezone(tenure.started_at)` (date-only format)
- Line 130: `tenure.ended_at.strftime('%m/%d/%Y')` → `format_time_in_user_timezone(tenure.ended_at)` (date-only format)
- Line 158: `latest.official_check_in_completed_at.strftime('%m/%d/%Y')` → `format_time_in_user_timezone(latest.official_check_in_completed_at)` (date-only format)
- Line 195: `check_in.employee_completed_at.strftime('%m/%d/%Y %I:%M %p')` → `format_time_in_user_timezone(check_in.employee_completed_at)`
- Line 203: `check_in.manager_completed_at.strftime('%m/%d/%Y %I:%M %p')` → `format_time_in_user_timezone(check_in.manager_completed_at)`
- Line 214: `check_in.official_check_in_completed_at.strftime('%m/%d/%Y %I:%M %p')` → `format_time_in_user_timezone(check_in.official_check_in_completed_at)`

**Date Fields (No Conversion Needed):**
- Line 187: `check_in.check_in_started_on.strftime('%B %d, %Y')` ✓ (Date field)
- Line 189: `check_in.check_in_started_on.strftime('%I:%M %p')` ✓ (Date field - time portion should not exist)
- Line 248: `check_in.check_in_started_on.strftime('%B %d, %Y')` ✓ (Date field)

### app/views/organizations/check_ins/_position_check_ins_table_completed.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 40: `check_in.official_check_in_completed_at&.strftime('%m/%d/%Y')` → `format_time_in_user_timezone(check_in.official_check_in_completed_at)` (date-only format)

### app/views/organizations/observations/new.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 18: `@observation.updated_at.strftime("%l:%M %p on %B %d, %Y")` → `format_time_in_user_timezone(@observation.updated_at)`
- Line 24: `@observation.published_at.strftime("%l:%M %p on %B %d, %Y")` → `format_time_in_user_timezone(@observation.published_at)`

### app/views/organizations/observations/_card_view.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 45: `observation.observed_at.strftime('%b %d, %Y')` → `format_time_in_user_timezone(observation.observed_at)` (date-only format)

### app/views/organizations/observations/_list_view.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 9: `observation.observed_at.strftime('%b %d, %Y')` → `format_time_in_user_timezone(observation.observed_at)` (date-only format)

### app/views/organizations/observations/_table_view.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 53: `observation.observed_at.strftime('%b %d, %Y')` → `format_time_in_user_timezone(observation.observed_at)` (date-only format)

### app/views/organizations/observations/review.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 47: `@form.observed_at&.strftime('%B %d, %Y at %l:%M %p')` → `format_time_in_user_timezone(@form.observed_at)` (if not nil)

### app/views/organizations/observations/quick_new.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 18: `@observation.updated_at.strftime("%l:%M %p on %B %d, %Y")` → `format_time_in_user_timezone(@observation.updated_at)`

### app/views/organizations/check_ins/_abilities_table.html.haml

**Date Fields (No Conversion Needed):**
- Line 45: `milestone.attained_at.strftime('%B %d, %Y')` ✓ (Date field)

### app/views/people/show/_align.html.haml

**DateTime Fields (Need Timezone Conversion):**
- Line 71: `current_assignment_tenure.started_at.strftime('%B %d, %Y')` → `format_time_in_user_timezone(current_assignment_tenure.started_at)` (date-only format)
- Line 76: `current_assignment_tenure.ended_at.strftime('%B %d, %Y')` → `format_time_in_user_timezone(current_assignment_tenure.ended_at)` (date-only format)

### app/views/people/growth.html.haml

**Date Fields (No Conversion Needed):**
- Line 101: `latest_check_in.check_in_started_on.strftime('%b %d')` ✓ (Date field)

## Summary Statistics

### Total DateTime Fields Requiring Conversion: ~70+
### Total Date Fields (No Conversion Needed): ~25+

### Files with Most Violations:
1. `app/views/organizations/goals/show.html.haml` - 8 datetime fields
2. `app/views/organizations/observations/show.html.haml` - 5 datetime fields
3. `app/views/organizations/teammates/assignments/show.html.haml` - 6 datetime fields
4. `app/views/organizations/teammates/position/show.html.haml` - 3 datetime fields
5. `app/views/kudos/show.html.haml` - 3 datetime fields

## Notes

1. **Date-only formatting**: Some datetime fields are formatted to show only the date portion (e.g., `strftime('%B %d, %Y')`). These still need timezone conversion because the date shown could differ based on timezone (e.g., 11:30 PM EST on Jan 1 is Jan 2 in PST).

2. **URL parameters**: Some datetime fields are formatted for URL parameters (e.g., `strftime('%Y-%m-%d')`). These may need special handling to ensure the date portion reflects the user's timezone.

3. **Helper method**: The existing `format_time_in_user_timezone` helper uses a fixed format (`'%B %d, %Y at %I:%M %p %Z'`). We may need to create additional helpers for date-only formatting or modify the existing helper to accept format options.

4. **Decorators**: Some date/time formatting may be moved to decorators in the future for better separation of concerns.

5. **Edge cases**: Some fields like `check_in_started_on` are Date fields but are being formatted with time (`%I:%M %p`). This suggests a potential data model issue that should be investigated.



