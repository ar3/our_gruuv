# Accessibility & Responsive Design Guide

This document defines accessibility standards and responsive design patterns for the OurGruuv application.

## Accessibility Standards

### Semantic HTML Structure
- **Use semantic HTML elements**: Employ proper heading hierarchy (H1 → H5) and semantic tags
- **ARIA regions and landmarks**: Mark major sections with `role="region"` and `aria-labelledby`
- **Proper labeling**: Each interactive element should have clear, descriptive labels
- **Keyboard navigation**: Ensure all interactive elements are accessible via keyboard
- **Screen reader support**: Use proper ARIA attributes to help assistive technologies navigate content

### Color & Visual Accessibility
- **Accessibility first**: Ensure sufficient contrast ratios for all color combinations
- **Cultural considerations**: Avoid red/green combinations for colorblind users
- **Test with colorblind users**: The system should work for all users
- **Semantic color usage**: Use colors with consistent, meaningful purposes

## Responsive Design

### Mobile-First Approach
- **Mobile-first approach**: All pages must be responsive and look good on mobile devices unless otherwise stated
- **Bootstrap responsive utilities**: Use Bootstrap's responsive classes for consistent mobile experience
- **Touch-friendly interfaces**: Ensure interactive elements are appropriately sized for touch devices
- **Responsive navigation**: Navigation should work seamlessly across all device sizes
- **Responsive images**: Use responsive image techniques for optimal loading across devices

### Column Behavior
- **Desktop**: 8:4 split for content vs actions
- **Tablet**: Maintain split but stack on very small screens
- **Mobile**: Stack columns vertically for better mobile experience

### Spacing
- **Section spacing**: `mb-4` between major sections
- **Header spacing**: `mb-2` for header row, `mb-4` for back link
- **Content spacing**: `mt-3` for content within sections

## Dashboard Layout & Organization

### Visual Design Principles
- **Use full-width cards for each major section** to create visual unity
- **8:4 column split for stats and actions**: Stats on the left (8 columns), actions on the right (4 columns)
- **Subtle visual dividers**: Use `border-start border-secondary` for clean separation between stats and actions
- **Consistent card heights**: Each section should have matching heights for professional appearance
- **Group related functionality**: Actions should be grouped with their relevant content areas
- **Prioritize information architecture**: Organize content logically by grouping related information together

## User Experience Standards

### Notifications
- Show a toast notification every time any action is submitted to inspire confidence in the system

## Implementation Checklist

When creating or updating pages for accessibility and responsiveness, ensure:
- [ ] Proper heading hierarchy (H1 → H5)
- [ ] ARIA regions and landmarks for major sections
- [ ] Clear, descriptive labels for interactive elements
- [ ] Keyboard navigation support
- [ ] Screen reader compatibility
- [ ] Sufficient color contrast ratios
- [ ] Mobile-first responsive design
- [ ] Touch-friendly interface elements
- [ ] Consistent spacing and layout patterns
- [ ] Semantic color usage only
