# Style Guide Overview

This document provides a comprehensive overview of all styling patterns used in the OurGruuv application. For detailed information, refer to the individual style guide files.

## Quick Reference

| Component | File | Description |
|-----------|------|-------------|
| **Index Pages** | [index-pages.md](./index-pages.md) | Standard patterns for list/index pages |
| **Show Pages** | [show-pages.md](./show-pages.md) | Standard patterns for detail/show pages |
| **Buttons** | [buttons.md](./buttons.md) | Button hierarchy and authorization patterns |
| **Colors** | [colors.md](./colors.md) | Semantic color system and usage |
| **Privacy Indicators** | [privacy-indicators.md](./privacy-indicators.md) | Visibility/privacy level display patterns |
| **Navigation** | [navigation.md](./navigation.md) | Navigation and back link patterns |
| **Forms** | [forms.md](./forms.md) | Form layout and HAML best practices |
| **Responsive** | [responsive.md](./responsive.md) | Responsive design patterns |
| **Accessibility** | [accessibility.md](./accessibility.md) | Accessibility standards and responsive design |

## Page Type Quick Start

### Index Pages
Use the `content_for` pattern with:
- `content_for :title` for page title (REQUIRED - first line)
- `content_for :go_back_link` for navigation
- `content_for :header` for title and create button
- `content_for :header_action` for filter/sort button
- Standard table layout with responsive wrapper

### Show Pages
Use the direct layout pattern with:
- `content_for :title` for page title (REQUIRED - first line)
- `.d-flex.justify-content-between.align-items-center.mb-2` for header
- Direct back link below header as muted text
- 8:4 column split for content vs actions

## Key Principles

### Consistency
- **No colored headers** - clean and simple card headers
- **Semantic colors only** - use the color system for meaning
- **Consistent spacing** - `mb-4` between sections, `mb-2` for headers
- **Standard icons** - Bootstrap icons with `me-2` spacing

### Authorization
- **Disabled buttons** with warning icons outside the button
- **Clear tooltips** explaining required permissions
- **Visual hierarchy** showing action vs restriction

### Responsive Design
- **8:4 column split** for desktop content/actions
- **Stack vertically** on mobile
- **Responsive tables** with `.table-responsive` wrapper

## Implementation Checklist

When creating or updating any page:

**Index Pages:**
- [ ] Use `content_for` pattern for header and navigation
- [ ] Include filter/sort modal (disabled save button)
- [ ] Standard table layout with action buttons
- [ ] Authorization UX for create button

**Show Pages:**
- [ ] Use direct header layout pattern
- [ ] 8:4 column split for content/actions
- [ ] Collapse elements use standard pattern
- [ ] Clean card headers without colors

**All Pages:**
- [ ] `content_for :title` included at the top of every view file (REQUIRED)
- [ ] Page title is descriptive and concise (3-8 words)
- [ ] Consistent button patterns and spacing
- [ ] Semantic color usage only
- [ ] Responsive design considerations
- [ ] No manual Bootstrap component initialization
- [ ] HAML uses single-line assignments for complex Ruby code

## Common Patterns

### Header with Create Button
```haml
- content_for :header do
  .d-flex.align-items-center
    %h1.mb-0.me-2 [Title]
    .d-flex.align-items-center
      - if policy([Model]).create?
        = link_to new_[resource]_path, class: "btn btn-primary ml-2" do
          %i.bi.bi-plus
      - else
        .btn.btn-primary.disabled{style: "opacity: 0.6; cursor: not-allowed;"}
          %i.bi.bi-plus
        %i.bi.bi-exclamation-triangle.text-warning.ms-2{"data-bs-toggle" => "tooltip", "data-bs-title" => "You need [permission] to perform this action"}
```

### Standard Table Actions
```haml
.btn-group.btn-group-sm
  = link_to [resource]_path([resource]), class: "btn btn-outline-primary" do
    %i.bi.bi-eye
  = link_to edit_[resource]_path([resource]), class: "btn btn-outline-secondary" do
    %i.bi.bi-pencil
  = link_to [resource]_path([resource]), method: :delete, class: "btn btn-outline-danger", data: { confirm: "Are you sure?" } do
    %i.bi.bi-trash
```

### Collapse Element
```haml
%a.text-decoration-none{"data-bs-toggle" => "collapse", "data-bs-target" => "#target-id", "aria-expanded" => "false", "aria-controls" => "target-id", style: "cursor: pointer;"}
  %span.not-collapsed
    %i.bi.bi-chevron-up.me-2
    %small.text-muted (Hide details)
  %span.collapsed
    %i.bi.bi-chevron-down.me-2
    %small.text-muted (Show details)
```

## Getting Help

- **Index pages**: See [index-pages.md](./index-pages.md) for complete patterns
- **Show pages**: See [show-pages.md](./show-pages.md) for layout patterns
- **Colors**: See [colors.md](./colors.md) for semantic color usage
- **Buttons**: See [buttons.md](./buttons.md) for authorization patterns
- **Forms**: See [forms.md](./forms.md) for HAML best practices
- **Navigation**: See [navigation.md](./navigation.md) for back link patterns
- **Responsive**: See [responsive.md](./responsive.md) for mobile patterns
