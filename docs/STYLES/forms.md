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

### Standard Form Structure
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

## Implementation Checklist

When creating or updating forms, ensure:
- [ ] HAML uses single-line assignments for complex Ruby code
- [ ] Proper form layout with 8:4 column split
- [ ] Consistent button patterns
- [ ] Clear form validation and error handling
- [ ] Accessible form labels and structure
