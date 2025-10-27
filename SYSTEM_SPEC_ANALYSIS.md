# System Spec Analysis

## Summary
**83 system spec examples, 22 failures**

## Failure Patterns Analysis

### Pattern 1: Content Expectations Not Met
Common error: `expected to find text "..." but found different content`

**Examples:**
- `spec/system/aspiration_check_in_integration_spec.rb` - Aspiration content not found
- `spec/system/assignment_selection_spec.rb` - Success message not found
- `spec/system/position_check_in_happy_path_spec.rb` - Success message not found

### Pattern 2: Form Elements Not Found  
Common error: `Capybara::ElementNotFound`

**Examples:**
- `spec/system/aspiration_check_in_integration_spec.rb` - Select elements not found
- `spec/system/check_ins_card_view_spec.rb` - Form fields not found
- `spec/system/check_ins_field_alignment_spec.rb` - Form fields not found

### Pattern 3: View Consistency Issues
Common error: Card view vs table view form field mismatch

**Examples:**
- `spec/system/check_ins_card_view_spec.rb` - Multiple failures
- `spec/system/check_ins_view_consistency_spec.rb` - Multiple failures
- `spec/system/check_ins_tabular_view_spec.rb` - Multiple failures

## Potential Root Cause

The layout change we made (`app/views/layouts/authenticated-v2-0.html.haml` line 109) may have affected:
1. How pages are rendered
2. What content is visible
3. Form element rendering

## Recommendation

**Group the fixes by related functionality:**

### Group 1: Core Check-In Functionality (8-10 failures)
- Aspiration check-in specs
- Assignment check-in specs  
- Position check-in specs
- **Likely cause**: Single UI issue affecting all check-ins

### Group 2: View Consistency Specs (8-10 failures)
- Card view specs
- Table view specs
- Field alignment specs
- **Likely cause**: Single rendering issue

### Group 3: Integration/Finalization (4-5 failures)
- Finalization flow specs
- Integration specs
- **Likely cause**: Related to Group 1

## Fix Strategy

**Fix all at once** if a single root cause is found (likely the layout change or a shared helper).

**Fix in groups** if different root causes emerge:
1. Start with core check-in functionality
2. Then view consistency
3. Finally integration flows

## Next Steps
1. Run one failing spec in detail mode
2. Identify the exact cause
3. Determine if it's a single root cause or multiple issues
4. Proceed with fix strategy

