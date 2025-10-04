# Responsive Design Guide

This document defines the responsive design patterns used throughout the OurGruuv application.

## Column Behavior

### Desktop Layout
- **8:4 column split**: Content on left (8 cols), actions on right (4 cols)
- **Full width**: Use `.col-lg-12` for full-width content areas

### Tablet Layout
- Maintain split but stack on very small screens
- Use Bootstrap responsive classes for tablet-specific adjustments

### Mobile Layout
- Stack columns vertically for better mobile experience
- Use `.col-12` for full-width mobile layouts

## Spacing

### Section Spacing
- **Section spacing**: `mb-4` between major sections
- **Header spacing**: `mb-2` for header row, `mb-4` for back link
- **Content spacing**: `mt-3` for content within sections

### Container Patterns
```haml
.container.mt-4
  .row
    .col-12
      / Content
```

## Responsive Classes

### Bootstrap Grid System
- Use `.row` and `.col-*` classes for responsive layouts
- Prefer `.col-lg-12` for full-width content
- Use `.col-md-8` and `.col-md-4` for content/action splits

### Responsive Utilities
- Use `.d-none`, `.d-md-block` for responsive visibility
- Use `.table-responsive` for responsive tables
- Use `.btn-group-sm` for smaller button groups on mobile

## Implementation Checklist

When creating or updating responsive layouts, ensure:
- [ ] Responsive design considerations
- [ ] Proper Bootstrap grid usage
- [ ] Mobile-friendly button sizes
- [ ] Responsive table wrappers
- [ ] Appropriate spacing for different screen sizes
