# Show Page Style Guide

This document defines the standard style guide for all show pages in the OurGruuv application.

## Page Header Layout

### Standard Header Structure
All show pages should follow this consistent header layout:

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

## Implementation Checklist

When creating or updating show pages, ensure:
- [ ] Header follows standard layout (title left, action right)
- [ ] Back link is below header as muted text
- [ ] Sections use 8:4 column split
- [ ] No colored headers - clean and simple
- [ ] Consistent button patterns and spacing
- [ ] Collapse elements use standard pattern (anchor tag + two spans + two icons)
- [ ] Responsive design considerations
- [ ] Semantic color usage only
