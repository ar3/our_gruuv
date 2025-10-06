# Show Page Style Guide

This document defines the standard style guide for all show pages in the OurGruuv application.

## Page Header Layout

### Standard Header Structure
All show pages should follow this consistent header layout:

```haml
= content_for :header do
  .d-flex.justify-content-between.align-items-center.mb-2
    %h1.mb-0{id: "page-title"}
      Page Title
    .d-flex.align-items-center
      = content_for :top_actions  # Edit button and other primary actions

.mb-4
  = content_for :go_back_link  # Single back link to index page
```

### Key Principles:
- **Header row**: Title on left, primary actions on right
- **Margin**: Use `mb-2` for header, `mb-4` for back link section
- **Back link**: Always below header as muted text (no button styling)
- **Primary actions**: Right-aligned in header row (edit button, view switcher, etc.)
- **Single edit button**: Only one edit button per page, placed in `top_actions` content_for
- **Single back link**: Only one "back to [plural]" link, placed in `go_back_link` content_for

## Section Layout

### Standard Show Page Structure
All show pages should use this pattern with content on left and spotlight on right:

```haml
.row
  .col-md-8
    / Main content sections
    .card.mb-4{ role: "region", "aria-labelledby": "section-name" }
      .card-header
        %h5.mb-0{ id: "section-name" }
          %i.bi.bi-icon.me-2
          Section Title
      .card-body
        / Content goes here
  
  .col-md-4
    / Spotlight section with analytics and interesting tidbits
    .card.mb-4
      .card-header
        %h6.mb-0
          %i.bi.bi-star.me-2
          Spotlight
      .card-body
        / Analytics, stats, interesting tidbits about the object
```

### Spotlight Section
The spotlight section should contain:
- **Analytics**: Key metrics, counts, statistics
- **Interesting tidbits**: Fun facts, related data, contextual information
- **Quick actions**: Secondary actions that don't belong in the header
- **Related objects**: Links to related resources

### When to Use 8:4 Column Split
**IMPORTANT:** The 8:4 column split should ONLY be used when explicitly specified for specific page types:

**✅ Use 8:4 split for:**
- Show pages with content + spotlight sidebar
- Index pages with filters/sort sidebar
- Dashboard pages with stats + quick actions
- Pages explicitly designed with content/action separation

**❌ DON'T use 8:4 split for:**
- Edit forms (use full width with buttons at bottom)
- New forms (use full width with buttons at bottom)
- Simple show pages without spotlight sidebars
- Standard CRUD pages

### Key Principles:
- **8:4 column split**: Content on left (8 cols), spotlight on right (4 cols) - ONLY when explicitly specified
- **Simple headers**: No colored backgrounds, just clean card headers
- **Consistent spacing**: `mb-4` between sections
- **Spotlight content**: Analytics, tidbits, and secondary actions in right sidebar

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
- [ ] Header follows standard layout (title left, actions right)
- [ ] Single edit button placed in `top_actions` content_for
- [ ] Single back link placed in `go_back_link` content_for
- [ ] Sections use 8:4 column split with spotlight sidebar
- [ ] Spotlight section contains analytics and interesting tidbits
- [ ] No colored headers - clean and simple
- [ ] Consistent button patterns and spacing
- [ ] Collapse elements use standard pattern (anchor tag + two spans + two icons)
- [ ] Responsive design considerations
- [ ] Semantic color usage only
