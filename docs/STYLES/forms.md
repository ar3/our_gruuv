# Form Style Guide

This document defines the standard form patterns used throughout the OurGruuv application.

## HAML Best Practices

### Multi-line Ruby Code
When writing complex Ruby expressions in HAML, avoid deep nesting and multi-line expressions that can cause indentation errors:

```haml
// ❌ AVOID: Complex multi-line expressions
= f.select :permission_value, 
    options_for_select(
      [
        ['Yes', 'true'],
        ['No', 'false'], 
        ['Not Set', 'nil']
      ], 
      complex_conditional_logic
    ),
    {}, 
    { class: "form-select", onchange: "this.form.submit();" }

// ✅ PREFER: Single-line assignments
- options = [['Yes', 'true'], ['No', 'false'], ['Not Set', 'nil']]
- selected_value = complex_conditional_logic
= f.select :permission_value, options, { selected: selected_value }, { class: "form-select", onchange: "this.form.submit();" }
```

#### Key Principles:
- **Use `-` for Ruby code** that doesn't output to HTML (variable assignments)
- **Use `=` for Ruby code** that outputs to HTML (form helpers, content)
- **Keep complex logic on separate lines** with clear variable names
- **Avoid deep nesting** in single expressions
- **Prefer single-line assignments** over multi-line complex expressions

## Form Layout Patterns

### Standard Edit Page Structure
Edit pages should use full-width layout with buttons at the bottom:

```haml
.d-flex.justify-content-between.align-items-center.mb-2
  %h1.mb-0{id: "page-title"}
    %i.bi.bi-pencil.me-2
    Edit #{@resource.name}
  .d-flex.align-items-center
    .btn-group
      = link_to resource_path(@resource), class: "btn btn-info" do
        %i.bi.bi-eye.me-2
        View
      = link_to resources_path, class: "btn btn-secondary" do
        %i.bi.bi-arrow-left.me-2
        Back to Resources

.mb-4
  = link_to resource_path(@resource), class: "text-muted text-decoration-none" do
    %i.bi.bi-arrow-left.me-2
    Back to #{@resource.name}

.card
  .card-header
    %h5.mb-0
      %i.bi.bi-pencil.me-2
      Edit #{@resource.name}
  .card-body
    = form_with model: @form, url: resource_path(@resource), local: true do |f|
      - if @form.errors.any?
        .alert.alert-danger
          %h6 Please fix the following errors:
          %ul.mb-0
            - @form.errors.full_messages.each do |message|
              %li= message
      
      .col-12
        / All form fields go here in full width
        
      .d-flex.justify-content-end.gap-2.mt-4
        = f.submit "Update #{@resource.class.name}", class: "btn btn-primary"
        = link_to "Cancel", resource_path(@resource), class: "btn btn-outline-secondary"
```

### Standard New Page Structure
New pages should also use full-width layout with buttons at the bottom:

```haml
.d-flex.justify-content-between.align-items-center.mb-2
  %h1.mb-0{id: "page-title"}
    %i.bi.bi-plus.me-2
    New #{@resource.class.name}
  .d-flex.align-items-center
    = link_to resources_path, class: "btn btn-secondary" do
      %i.bi.bi-arrow-left.me-2
      Cancel

.mb-4
  = link_to resources_path, class: "text-muted text-decoration-none" do
    %i.bi.bi-arrow-left.me-2
    Back to Resources

.card
  .card-header
    %h5.mb-0
      %i.bi.bi-plus.me-2
      Create New #{@resource.class.name}
  .card-body
    = form_with model: @form, url: resources_path, local: true do |f|
      - if @form.errors.any?
        .alert.alert-danger
          %h6 Please fix the following errors:
          %ul.mb-0
            - @form.errors.full_messages.each do |message|
              %li= message
      
      .col-12
        / All form fields go here in full width
        
      .d-flex.justify-content-end.gap-2.mt-4
        = f.submit "Create #{@resource.class.name}", class: "btn btn-primary"
        = link_to "Cancel", resources_path, class: "btn btn-outline-secondary"
```

### Legacy 8:4 Form Structure (Deprecated)
**NOTE:** This pattern is deprecated and should NOT be used for new forms:

```haml
.card
  .card-header
    %h5.mb-0 Form Title
  .card-body
    = form_with model: @model, local: true do |f|
      .row
        .col-md-8
          / Form fields
        .col-md-4.border-start.border-secondary
          .d-grid.gap-2
            = f.submit "Save", class: "btn btn-primary"
            = link_to "Cancel", back_path, class: "btn btn-outline-secondary"
```

### Key Principles for Form Layout:
- **Full width**: Use `.col-12` for all form content
- **Buttons at bottom**: Save/Cancel buttons at bottom right with `.d-flex.justify-content-end.gap-2.mt-4`
- **Single back link**: Only use the `go_back_link` content_for block, not multiple back links
- **Consistent spacing**: `mt-4` for button section, `mb-4` for back link section
- **No 8:4 split**: Forms should use full width unless explicitly specified otherwise

## Implementation Checklist

When creating or updating forms, ensure:
- [ ] HAML uses single-line assignments for complex Ruby code
- [ ] Full-width layout with `.col-12` for form content
- [ ] Save/Cancel buttons at bottom right with proper spacing
- [ ] Single back link using `go_back_link` content_for block
- [ ] Consistent form validation and error handling
- [ ] Accessible form labels and structure
- [ ] No 8:4 split unless explicitly specified
