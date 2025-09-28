# Application Styles & Layout Standards

## Page Header Layout

### Standard Header Structure
All show and index pages should follow this consistent header layout:

```haml
.d-flex.justify-content-between.align-items-center.mb-2
  %h1.mb-0{id: "page-title"}
    Page Title
  .d-flex.align-items-center
    = render 'action_component'  # Primary action component

.mb-4
  = link_to back_path, class: "text-muted text-decoration-none" do
    %i.bi.bi-arrow-left.me-2
    Back to Previous
```

### Key Principles:
- **Header row**: Title on left, primary action on right
- **Margin**: Use `mb-2` for header, `mb-4` for back link section
- **Back link**: Always below header as muted text (no button styling)
- **Primary action**: Right-aligned in header row (e.g., view switcher, create button)

## Section Layout

### Standard Section Structure
All content sections should use this pattern:

```haml
.card.mb-4{ role: "region", "aria-labelledby": "section-name" }
  .card-header
    %h5.mb-0{ id: "section-name" }
      %i.bi.bi-icon.me-2
      Section Title
  .card-body
    .row
      .col-md-8
        / Stats, content, tables
      .col-md-4.border-start.border-secondary
        .d-grid.gap-2
          / Action buttons
```

### Key Principles:
- **8:4 column split**: Content on left (8 cols), actions on right (4 cols)
- **Simple headers**: No colored backgrounds, just clean card headers
- **Consistent spacing**: `mb-4` between sections
- **Action grouping**: Right sidebar with `.d-grid.gap-2` for button stacks

## Color System

### Semantic Colors Only
- **Primary**: `text-primary` for key metrics/numbers
- **Info**: `text-info` for secondary metrics
- **Success**: `text-success` for positive states
- **Warning**: `text-warning` for caution states
- **Secondary**: `text-secondary` for metadata
- **Muted**: `text-muted` for helper text

### No Colored Headers
- Card headers should be clean and simple
- Use icons and clear typography instead of background colors
- Maintain consistency across all pages

## Button Patterns

### Button Hierarchy
1. **Primary actions**: `btn btn-primary` (e.g., Create, Save)
2. **Secondary actions**: `btn btn-outline-primary` (e.g., Edit, View)
3. **Success actions**: `btn btn-success` (e.g., Add, Connect)
4. **Warning actions**: `btn btn-warning` (e.g., Change, Modify)
5. **Danger actions**: `btn btn-danger` (e.g., Delete, Remove)

### Button Groups
- Use `.d-grid.gap-2` for vertical button stacks in right sidebars
- Use `.btn-group` for related horizontal button groups
- Consistent spacing with `me-2` between button and icon

## Navigation Patterns

### View Switching
- Use dropdown buttons that show current state
- Button text should reflect current mode (e.g., "Management Mode", "Teammate Mode")
- Remove redundant labels - the button text IS the current state indicator

### Breadcrumbs & Back Links
- Back links below header as muted text
- Use consistent icon (`bi-arrow-left`) and styling
- No button styling for navigation elements

## Interactive Components

### Collapse Elements
All collapsible sections should use this consistent pattern for chevron rotation:

```haml
%a.text-decoration-none{"data-bs-toggle" => "collapse", "data-bs-target" => "#target-id", "aria-expanded" => "false", "aria-controls" => "target-id", style: "cursor: pointer;"}
  %span.not-collapsed
    %i.bi.bi-chevron-up.me-2
    %small.text-muted (Hide details)
  %span.collapsed
    %i.bi.bi-chevron-down.me-2
    %small.text-muted (Show details)
```

#### Key Elements:
- **Anchor tag**: Use `<a>` instead of `<button>` for better Bootstrap compatibility
- **Two spans**: `.not-collapsed` and `.collapsed` classes
- **Two icons**: `bi-chevron-up` (expanded) and `bi-chevron-down` (collapsed)
- **Existing CSS**: Leverages app's existing collapse CSS that handles `aria-expanded`

#### Examples in App:
- Position index page (`/organizations/:id/positions`)
- People complete picture page (`/organizations/:org_id/people/:id/complete_picture`)
- Assignment details page (`/people/:id/assignments/:id`)

#### CSS Support:
The app already has CSS in `application.bootstrap.scss` that handles this pattern:
```scss
button[aria-expanded="false"] .not-collapsed, a[aria-expanded="false"] .not-collapsed {
  display: none;
}
button[aria-expanded="true"] .collapsed, a[aria-expanded="true"] .collapsed {
  display: none;
}
button[aria-expanded="true"] .not-collapsed, a[aria-expanded="true"] .not-collapsed {
  display: inline;
}
button[aria-expanded="false"] .collapsed, a[aria-expanded="false"] .collapsed {
  display: inline;
}
```

## Responsive Design

### Column Behavior
- **Desktop**: 8:4 split for content vs actions
- **Tablet**: Maintain split but stack on very small screens
- **Mobile**: Stack columns vertically for better mobile experience

### Spacing
- **Section spacing**: `mb-4` between major sections
- **Header spacing**: `mb-2` for header row, `mb-4` for back link
- **Content spacing**: `mt-3` for content within sections

## Authorization UX Patterns

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

### Bootstrap Components
- **No manual initialization**: All Bootstrap components (tooltips, collapse, popovers) are automatically initialized in the global JavaScript file
- **Use standard attributes**: `data-bs-toggle`, `data-bs-title`, etc. work out of the box
- **No custom JavaScript**: Avoid adding initialization code in individual views

## Implementation Checklist

When creating or updating pages, ensure:
- [ ] Header follows standard layout (title left, action right)
- [ ] Back link is below header as muted text
- [ ] Sections use 8:4 column split
- [ ] No colored headers - clean and simple
- [ ] Consistent button patterns and spacing
- [ ] Collapse elements use standard pattern (anchor tag + two spans + two icons)
- [ ] Authorization UX follows warning icon pattern (outside button)
- [ ] No manual Bootstrap component initialization
- [ ] Responsive design considerations
- [ ] Semantic color usage only
