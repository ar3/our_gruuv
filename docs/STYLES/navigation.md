# Navigation Style Guide

This document defines the standard navigation patterns used throughout the OurGruuv application.

## Navigation Patterns

### View Switching
- Use dropdown buttons that show current state
- Button text should reflect current mode (e.g., "Management Mode", "Teammate Mode")
- Remove redundant labels - the button text IS the current state indicator

### Breadcrumbs & Back Links
- Back links below header as muted text
- Use consistent icon (`bi-arrow-left`) and styling
- No button styling for navigation elements

## Back Link Patterns

### Index Pages
Use `content_for :go_back_link` with the `go-back-link` CSS class:

```haml
- content_for :go_back_link do
  = link_to organization_path(@organization), class: "go-back-link" do
    %i.bi.bi-arrow-left.me-2
    Back to #{@organization.display_name}
```

### Show Pages
Use direct link below header as muted text:

```haml
.mb-4
  = link_to back_path, class: "text-muted text-decoration-none" do
    %i.bi.bi-arrow-left.me-2
    Back to Previous
```

## Implementation Checklist

When creating or updating navigation, ensure:
- [ ] Consistent icon usage (`bi-arrow-left`)
- [ ] Proper styling (muted text, no button styling)
- [ ] Clear navigation hierarchy
- [ ] Appropriate back link pattern for page type
