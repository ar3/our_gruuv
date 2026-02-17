# Show Page Style Guide

This document defines the standard style guide for all show pages in the OurGruuv application.

## Required Elements

### Page Title
- **REQUIRED**: Every page MUST include `content_for :title` at the top of the view file
- **Purpose**: Provides descriptive page titles for browser tabs and page visit tracking
- **Format**: Use descriptive, concise titles (3-8 words)
- **Pattern**: For show pages, use the resource name or identifier (e.g., `@position.display_name`, `@assignment.title`)
- **Placement**: Must be the first line in the view file (before any other content_for blocks)

```haml
- content_for :title, @position.display_name
- content_for :title, "Edit Position"
- content_for :title, "About #{@teammate.person.casual_name}"
```

**Examples:**
- Show pages: `@resource.name`, `@resource.title`, `@resource.display_name`
- Edit pages: `"Edit Position"`, `"Edit Assignment"`
- Custom pages: `"Manage Assignments for #{@position.position_type.external_title}"`
- Person pages: `"About #{@teammate.person.casual_name}"`

**Note**: Page titles are automatically tracked in `PageVisit` records and appear in browser tabs. Always include a descriptive title for every page.

## Page Header Layout

### Standard Header Structure
All show pages should follow this consistent header layout:

```haml
= content_for :header do
  .d-flex.justify-content-between.align-items-center.mb-2
    %h1.mb-0{id: "page-title"}
      Page Title
    .d-flex.align-items-center
      = content_for :header_action  # Mode switcher and other header actions

.mb-4
  = content_for :go_back_link  # Single back link to index page
```

### Required Content For Sections
All show pages MUST use these three content_for sections:

#### 1. `content_for :header`
- Contains the main page title and primary actions
- Title should include appropriate icon and object name
- Actions should be right-aligned in the header row

#### 2. `content_for :header_action`
- Contains the mode switcher partial and other header actions
- Mode switcher should be included for show/edit page pairs
- Other header-specific actions can be included here

#### 3. `content_for :go_back_link`
- Contains single back link to the index page
- Should be styled as muted text (no button styling)
- Should use appropriate icon and descriptive text

### Key Principles:
- **Header row**: Title on left, primary actions on right
- **Margin**: Use `mb-2` for header, `mb-4` for back link section
- **Back link**: Always below header as muted text (no button styling)
- **Primary actions**: Right-aligned in header row (edit button, mode switcher)
- **Single edit button**: Only one edit button per page, placed in `header` content_for
- **Single back link**: Only one "back to [plural]" link, placed in `go_back_link` content_for
- **Authorization**: Edit buttons must check policy and show tooltip when disabled
- **Mode switcher**: Required for show/edit page pairs, shows current mode and available modes

## Reusable Header Partial

### Global Header Partial (`app/views/shared/_header.html.haml`)
For consistent header implementation across all show pages, use the shared header partial:

```haml
= render 'shared/header', 
  header_name: content_tag(:i, '', class: 'bi bi-icon me-2') + @resource.name,
  header_quick_action_url: edit_resource_path(@resource),
  header_quick_action_content: content_tag(:i, '', class: 'bi bi-pencil me-2'),
  header_quick_action_is_enabled: policy(@resource).update?,
  header_quick_action_disabled_tooltip: "You need [specific permission] to edit [resource]"
```

### Header Partial Parameters
- **`header_name`**: The complete header content including icon and title
- **`header_quick_action_url`**: URL for the edit action (when enabled)
- **`header_quick_action_content`**: Content for the edit button (usually icon)
- **`header_quick_action_is_enabled`**: Boolean for authorization check
- **`header_quick_action_disabled_tooltip`**: Tooltip text when action is disabled

### Benefits of Using the Header Partial
- **Consistency**: Ensures all headers follow the same structure
- **Maintainability**: Changes to header structure only need to be made in one place
- **Authorization**: Built-in support for disabled states with tooltips
- **Reusability**: Can be used across all show pages with different parameters

## Edit Page Standards

### Edit Page Structure
Edit pages should follow the same content_for structure as show pages but with different content:

```haml
- content_for :header do
  = render 'shared/header', 
    header_name: content_tag(:i, '', class: 'bi bi-icon me-2') + "Edit #{@resource.name}",
    header_quick_action_url: resource_path(@resource),
    header_quick_action_content: content_tag(:i, '', class: 'bi bi-eye me-2'),
    header_quick_action_is_enabled: true,
    header_quick_action_disabled_tooltip: ""

- content_for :go_back_link do
  = link_to resource_path(@resource), class: "text-muted text-decoration-none" do
    %i.bi.bi-arrow-left.me-2
    Back to #{@resource.name}

- content_for :header_action do
  = render 'mode_switcher'
```

### Edit Page Key Differences
- **Header title**: Prefixed with "Edit " + resource name
- **Quick action**: Links back to show page (view action) instead of edit
- **Back link**: Goes back to show page, not index page
- **Mode switcher**: Same as show page, shows current edit mode
- **Form content**: Full-width form below the header sections

### Edit Page Requirements
- **Same content_for structure**: Uses `:header`, `:go_back_link`, and `:header_action`
- **Mode switcher**: Required for show/edit page pairs
- **View action**: Quick action should link to show page
- **Consistent navigation**: Back link goes to show page, not index
- **Form layout**: Use full width for forms (no 8:4 column split)

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

## Mode Switchers

### Standard Mode Switcher Pattern
For show/edit page pairs, use a mode switcher partial that follows this pattern:

```haml
.dropdown
  %button.btn.btn-outline-primary.btn-sm.dropdown-toggle{"data-bs-toggle" => "dropdown", "aria-expanded" => "false", type: "button"}
    %i.bi.bi-eye.me-2
    = [resource]_current_view_name
  %ul.dropdown-menu
    %li
      - if action_name == 'show'
        .dropdown-item.text-muted
          %i.bi.bi-eye.me-2
          View Mode (Active)
          %i.bi.bi-check-circle.text-success.ms-2
      - else
        = link_to [resource]_path(@[resource]), class: 'dropdown-item' do
          %i.bi.bi-eye.me-2
          View Mode
      
    %li
      - if action_name == 'edit'
        .dropdown-item.text-muted
          %i.bi.bi-pencil.me-2
          Edit Mode (Active)
          %i.bi.bi-check-circle.text-success.ms-2
      - elsif policy(@[resource]).update?
        = link_to edit_[resource]_path(@[resource]), class: 'dropdown-item' do
          %i.bi.bi-pencil.me-2
          Edit Mode
      - else
        .dropdown-item.text-muted.disabled
          %i.bi.bi-pencil.me-2
          Edit Mode
          %i.bi.bi-exclamation-triangle.text-warning.ms-2{"data-bs-toggle" => "tooltip", "data-bs-title" => "You need [specific permission] to edit [resource]"}
```

### Mode Switcher Requirements
- **Three states per mode**: Active (current), Available (clickable), Disabled (with tooltip)
- **Authorization checks**: Each mode should check appropriate policy methods
- **Tooltip messages**: Disabled modes must explain what permission is needed
- **Helper method**: Create `[resource]_current_view_name` helper method
- **Consistent icons**: Use `bi-eye` for view mode, `bi-pencil` for edit mode
- **Status indicators**: Active mode shows check circle, disabled shows warning triangle

### Helper Method Pattern
Create a helper method for each resource:

```ruby
module [Resource]Helper
  def [resource]_current_view_name
    return 'View Mode' unless action_name
    
    case action_name
    when 'show'
      'View Mode'
    when 'edit'
      'Edit Mode'
    else
      action_name.titleize
    end
  end
end
```

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
- [ ] `content_for :title` included at the top of the view file (REQUIRED)
- [ ] Header follows standard layout (title left, actions right)
- [ ] Uses all three required content_for sections (`:header`, `:header_action`, `:go_back_link`)
- [ ] Single edit button placed in `header` content_for with authorization check
- [ ] Single back link placed in `go_back_link` content_for
- [ ] Mode switcher included in `header_action` for show/edit page pairs
- [ ] Mode switcher shows three states: active, available, disabled with tooltips
- [ ] Helper method created for `[resource]_current_view_name`
- [ ] Sections use 8:4 column split with spotlight sidebar (when appropriate)
- [ ] Spotlight section contains analytics and interesting tidbits
- [ ] No colored headers - clean and simple
- [ ] Consistent button patterns and spacing
- [ ] Collapse elements use standard pattern (anchor tag + two spans + two icons)
- [ ] Responsive design considerations
- [ ] Semantic color usage only
- [ ] Authorization properly implemented with tooltips for disabled actions

When creating or updating edit pages, ensure:
- [ ] `content_for :title` included at the top of the view file (REQUIRED)
- [ ] Uses same content_for structure as show pages (`:header`, `:header_action`, `:go_back_link`)
- [ ] Header title prefixed with "Edit " + resource name
- [ ] Quick action links to show page (view action)
- [ ] Back link goes to show page, not index page
- [ ] Mode switcher included in `header_action`
- [ ] Form uses full width (no 8:4 column split)
- [ ] Uses shared header partial with appropriate parameters
