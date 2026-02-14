# Button Style Guide

This document defines the standard button patterns used throughout the OurGruuv application.

## Button Hierarchy

1. **Primary actions**: `btn btn-primary` (e.g., Create, Save)
2. **Secondary actions**: `btn btn-outline-primary` (e.g., Edit, View)
3. **Success actions**: `btn btn-success` (e.g., Add, Connect)
4. **Warning actions**: `btn btn-warning` (e.g., Change, Modify)
5. **Danger actions**: `btn btn-danger` (e.g., Delete, Remove)

## Button Groups

- Use `.d-grid.gap-2` for vertical button stacks in right sidebars
- Use `.btn-group` for related horizontal button groups
- Consistent spacing with `me-2` between button and icon

## Authorization UX Patterns

### Permission Display Principles
- **Don't hide things**: Show all actions but disable unauthorized ones
- **Clear feedback**: Use warning icons next to disabled buttons/links with tooltips
- **Helpful tooltips**: Explain what permission is needed for each action on hover over warning icon
- **Consistent patterns**: Use the same UI patterns across all permission checks
- **Visual indicators**: Use consistent icons and colors for permission states

### Disabled Button Styling
- **Disabled button styling**: Use `btn-outline-secondary` class for disabled buttons to clearly indicate they're not actionable
- **Secondary action styling**: Use `btn-outline-primary` for secondary actions and navigation links to distinguish from disabled buttons
- **Button layout**: Use `.flex-grow-1` wrapper with `.w-100` on disabled buttons to maintain full-width appearance minus warning icon space
- **Tooltip implementation**: Use Bootstrap tooltips with `data-bs-toggle="tooltip"` and `data-bs-title` for permission messages

### Index Page Header with Create Button
For index pages, use this header structure with conditional create button:

```haml
- content_for :header do
  .d-flex.align-items-center
    %h1.mb-0.me-2
      [Page Title]
    .d-flex.align-items-center
      - if policy([Model]).create?
        = link_to new_[resource]_path, class: "btn btn-primary ml-2" do
          %i.bi.bi-plus
      - else
        .btn.btn-primary.disabled{style: "opacity: 0.6; cursor: not-allowed;"}
          %i.bi.bi-plus
        %i.bi.bi-exclamation-triangle.text-warning.ms-2{"data-bs-toggle" => "tooltip", "data-bs-title" => "You need [specific permission] to perform this action"}
```

#### Key Principles:
- **Flex layout**: Use `.d-flex.align-items-center` for proper vertical alignment
- **Title spacing**: Add `me-2` to title for proper spacing from button
- **Button container**: Wrap button logic in `.d-flex.align-items-center` for consistent alignment
- **Plus icon only**: Use only the `bi-plus` icon for create buttons (no text) - follows Material Design FAB pattern
- **Warning icon outside button**: Place warning icon next to the disabled button, not inside it
- **Clear messaging**: Tooltip explains exactly what permission is needed
- **Visual hierarchy**: Disabled button shows the action, warning icon explains the restriction
- **Consistent styling**: Use `opacity: 0.6` and `cursor: not-allowed` for disabled state

### Permission-Based UI Implementation
- **Controller authorization**: Use permissive authorization for views (e.g., `authorize @resource, :show?`) and handle specific permissions in the view
- **View-level permission checks**: Use helper methods like `current_person&.can_create_employment?(@organization)` in views
- **Conditional UI rendering**: Show enabled buttons for authorized actions, disabled buttons with tooltips for unauthorized actions
- **Consistent permission patterns**: Use the same `if authorized / else disabled + tooltip` pattern across all actions
- **Policy logic belongs in Pundit policies**: Never implement complex authorization logic directly in views - use `policy(@record).action?` instead
- **Avoid multi-line conditionals in views**: Keep view logic simple by delegating complex checks to policy methods
- **Use semantic policy method names**: Create descriptive policy methods like `view_employment_history?` instead of complex inline checks

## Standard Actions

### Table Actions
- **View**: `btn-outline-primary` with `bi-eye` icon
- **Edit**: `btn-outline-secondary` with `bi-pencil` icon  
- **Delete**: `btn-outline-danger` with `bi-trash` icon
- **Group**: Use `.btn-group.btn-group-sm` for action buttons

### Index page bulk action row
- **All secondary**: Every button in the bulk action row (Filter/Sort, View Flows, Download all, View Analytics, etc.) MUST use `btn btn-sm btn-outline-secondary`. See [Index Pages](index-pages.md#5-bulk-action-row-optional).

### Icons
- **Plus**: `bi-plus` for create buttons
- **Filter**: `bi-funnel` for filter buttons
- **View**: `bi-eye` for view actions
- **Edit**: `bi-pencil` for edit actions
- **Delete**: `bi-trash` for delete actions
- **Table**: `bi-table` for table view
- **Cards**: `bi-grid` for card view
- **List**: `bi-list` for list view
- **Info**: `bi-info-circle` for empty states

## Bootstrap Components

- **No manual initialization**: All Bootstrap components (tooltips, collapse, popovers) are automatically initialized in the global JavaScript file
- **Use standard attributes**: `data-bs-toggle`, `data-bs-title`, etc. work out of the box
- **No custom JavaScript**: Avoid adding initialization code in individual views

## Implementation Checklist

When creating or updating buttons, ensure:
- [ ] Consistent button patterns and spacing
- [ ] Authorization UX follows warning icon pattern (outside button)
- [ ] No manual Bootstrap component initialization
- [ ] Proper icon usage with `me-2` spacing
- [ ] Disabled states use consistent styling
- [ ] Tooltips provide clear permission messaging
