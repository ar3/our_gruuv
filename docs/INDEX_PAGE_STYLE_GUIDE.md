# Index Page Style Guide

This document defines the standard style guide for all index pages in the OurGruuv application.

## Required Elements

### 1. Back Link Section
- **Back Link**: Use `content_for :go_back_link` to provide navigation back to the parent page
- **Icon**: Use `bi-arrow-left` icon with consistent styling
- **Target**: Should link back to the appropriate parent page (e.g., organization show page)
- **Styling**: Use the `go-back-link` CSS class for consistent styling

```haml
- content_for :go_back_link do
  = link_to organization_path(@organization), class: "go-back-link" do
    %i.bi.bi-arrow-left.me-2
    Back to #{@organization.display_name}
```

### 2. Header Section
- **Title**: Use `content_for :header` with a flex container
- **Plus Button**: Add a plus button next to the title for creating new objects

```haml
- content_for :header do
  .d-flex.justify-content-between.align-items-center
    %h1.mb-0 
      [Page Title]
      = link_to new_[resource]_path, class: "btn btn-primary" do
        %i.bi.bi-plus
```

### 3. Header Action Section
- **Customize Button**: Add a "Filter & Sort" button that opens a modal
- **Icon**: Use Bootstrap icons (`bi-funnel`)

```haml
- content_for :header_action do
  %button.btn.btn-outline-secondary{"data-bs-toggle" => "modal", "data-bs-target" => "#[resource]FilterModal", type: "button"}
    %i.bi.bi-funnel.me-2
    Filter & Sort
```

### 4. Main Content Area
- **Container**: Use `.row.justify-content-center` with `.col-lg-12`
- **Table View**: Default to table view with responsive wrapper
- **Empty State**: Use alert with info styling and call-to-action

```haml
.row.justify-content-center
  .col-lg-12
    - if @[resources].any?
      .table-responsive
        %table.table.table-hover
          %thead
            %tr
              %th [Column Headers]
          %tbody
            - @[resources].each do |[resource]|
              %tr
                %td [Content]
                %td
                  .btn-group.btn-group-sm
                    = link_to [resource]_path([resource]), class: "btn btn-outline-primary" do
                      %i.bi.bi-eye
                    = link_to edit_[resource]_path([resource]), class: "btn btn-outline-secondary" do
                      %i.bi.bi-pencil
                    = link_to [resource]_path([resource]), method: :delete, class: "btn btn-outline-danger", data: { confirm: "Are you sure?" } do
                      %i.bi.bi-trash
    - else
      .alert.alert-info
        %h6.mb-2
          %i.bi.bi-info-circle.me-2
          No [Resources] Created
        %p.mb-2 
          [Description of what to do next]
          = link_to "Create First [Resource]", new_[resource]_path, class: "btn btn-primary btn-sm"
```

### 5. Filter & Sort Modal
- **Modal ID**: Use `#[resource]FilterModal`
- **Title**: Include "(coming soon)" in the title
- **Disabled Save Button**: The "Apply Filters" button should be disabled
- **Sections**: Include Filters, Sort Options, View Style, and Spotlight

```haml
/ Modal for Filter & Sort
#[resource]FilterModal.modal.fade{"aria-hidden" => "true", "aria-labelledby" => "[resource]FilterModalLabel", tabindex: "-1"}
  .modal-dialog.modal-lg
    .modal-content
      .modal-header
        %h5.modal-title#[resource]FilterModalLabel
          %i.bi.bi-funnel.me-2
          Filter & Sort [Resources] (coming soon)
        %button.btn-close{"aria-label" => "Close", "data-bs-dismiss" => "modal", type: "button"}
      .modal-body
        .row
          .col-md-6
            %h6.mb-3
              %i.bi.bi-funnel.me-2
              Filters
            [Filter options specific to the resource]
          .col-md-6
            %h6.mb-3
              %i.bi.bi-sort-down.me-2
              Sort Options
            [Sort options specific to the resource]
            .mb-3
              %label.form-label View Style
              .form-check
                %input.form-check-input{checked: "checked", type: "radio", name: "viewStyle", value: "table"}
                %label.form-check-label
                  %i.bi.bi-table.me-2
                  Table View
              .form-check
                %input.form-check-input{type: "radio", name: "viewStyle", value: "cards"}
                %label.form-check-label
                  %i.bi.bi-grid.me-2
                  Card View
              .form-check
                %input.form-check-input{type: "radio", name: "viewStyle", value: "list"}
                %label.form-check-label
                  %i.bi.bi-list.me-2
                  List View
            .mb-3
              %label.form-label Spotlight
              %select.form-select
                %option No Spotlight
                %option [Resource-specific spotlight options]
      .modal-footer
        %button.btn.btn-secondary{"data-bs-dismiss" => "modal", type: "button"} Cancel
        %button.btn.btn-primary.disabled{type: "button"}
          %i.bi.bi-check.me-2
          Apply Filters
```

## Standard Actions

### Table Actions
- **View**: `btn-outline-primary` with `bi-eye` icon
- **Edit**: `btn-outline-secondary` with `bi-pencil` icon  
- **Delete**: `btn-outline-danger` with `bi-trash` icon
- **Group**: Use `.btn-group.btn-group-sm` for action buttons

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

## Implementation Notes

1. **Modal Functionality**: The modal doesn't need to work initially - just the UI structure
2. **Save Button**: Always disable the "Apply Filters" button in the modal
3. **Responsive**: Use Bootstrap responsive classes for mobile compatibility
4. **Accessibility**: Include proper ARIA labels and semantic HTML
5. **Consistency**: Follow the same pattern across all index pages
6. **Back Link Styling**: Use the `go-back-link` CSS class instead of inline styles for consistency

## Examples

- **Seats Index**: `/app/views/organizations/seats/index.html.haml`
- **Aspirations Index**: `/app/views/organizations/aspirations/index.html.haml`

## Future Enhancements

When implementing the modal functionality:
1. Add JavaScript for filter/sort logic
2. Implement view style switching
3. Add spotlight functionality
4. Enable the "Apply Filters" button
5. Add URL parameter persistence for filters
