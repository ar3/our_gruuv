# Color System Documentation

## Overview

This document outlines the semantic color system used throughout the Our Gruuv application. Every color has a specific meaning and should be used consistently to provide clear visual feedback to users.

## Semantic Color Usage

### Core Principles
- **Colors must have consistent, meaningful purposes** - never use colors as random decoration
- **Follow semantic color usage** across the entire interface
- **Limited color palette**: Use 5-7 colors maximum for clarity
- **Accessibility first**: Ensure sufficient contrast ratios for all color combinations
- **Cultural considerations**: Avoid red/green combinations for colorblind users

### Semantic Color Meanings

| Color | Bootstrap Class | Meaning | Usage |
|-------|----------------|---------|-------|
| **Blue (primary)** | `bg-primary`, `text-primary` | Main metrics, counts, primary data points | Primary buttons, overall scores, main navigation, key information |
| **Blue (info)** | `bg-info`, `text-info` | Secondary metrics, ratings, additional information | Counts, statistics, neutral information, data points |
| **Gray (secondary)** | `bg-secondary`, `text-secondary` | Dates, timestamps, less important data | Roles, inactive status, placeholder data, secondary actions |
| **Green (success)** | `bg-success`, `text-success` | Positive states, completed items, "good" metrics | Completed actions, submitted feedback, high ratings (4-5), appreciations, active status |
| **Yellow (warning)** | `bg-warning`, `text-warning` | Attention needed, caution states, neutral states | Pending actions, improvement suggestions, medium ratings (3), needs attention |
| **Red (danger)** | `bg-danger`, `text-danger` | Critical issues, errors, "bad" metrics | Errors, low ratings (1-2), critical issues, failed actions |
| **Light** | `bg-light`, `text-muted` | Empty states, zero values, inactive | Empty states, zero counts, inactive elements, no data |

## Rating Color Mapping

Individual ratings use colors to provide immediate visual feedback:

| Rating | Color | Meaning |
|--------|-------|---------|
| 1-2 | Danger (Red) | Poor performance, needs immediate attention |
| 3 | Warning (Yellow/Orange) | Average performance, room for improvement |
| 4-5 | Success (Green) | Good to excellent performance |

## S.E.E. 20 Score Color Mapping

The S.E.E. 20 score is a composite score representing overall huddle performance:

| Score Range | Color | Meaning |
|-------------|-------|---------|
| 0-5 | Danger (Red) | Critical issues, needs immediate attention |
| 6-10 | Warning (Yellow/Orange) | Significant room for improvement |
| 11-15 | Info (Blue) | Average performance |
| 16-19 | Success (Green) | Good performance |
| 20 | Primary (Blue) | Perfect score - exceptional performance |

## Feedback Participation Color Mapping

Feedback participation badges change color based on completion percentage:

| Participation % | Color | Meaning |
|-----------------|-------|---------|
| 0-25% | Danger (Red) | Very low participation, needs immediate attention |
| 26-50% | Warning (Yellow/Orange) | Low participation, needs follow-up |
| 51-75% | Info (Blue) | Moderate participation |
| 76-99% | Success (Green) | Good participation |
| 100% | Primary (Blue) | Perfect participation - everyone has submitted |

## Status Color Mapping

| Status | Color | Meaning |
|--------|-------|---------|
| Active, Completed, Submitted | Success (Green) | Positive completion |
| Pending | Warning (Yellow/Orange) | Awaiting action |
| Inactive | Secondary (Gray) | Not currently active |
| Cancelled | Danger (Red) | Failed or cancelled |

## Feedback Type Colors

| Feedback Type | Color | Meaning |
|---------------|-------|---------|
| Appreciation | Success (Green) | Positive feedback |
| Suggestion | Warning (Yellow/Orange) | Improvement feedback |
| Private | Info (Blue) | Confidential information |

## Conflict Style Colors

| Conflict Style | Color | Meaning |
|----------------|-------|---------|
| Collaborative | Success (Green) | Positive, win-win approach |
| Competing | Warning (Yellow/Orange) | Needs attention, potential conflict |
| Compromising | Info (Blue) | Neutral, balanced approach |
| Accommodating | Secondary (Gray) | Passive approach |
| Avoiding | Light (Light Gray) | Minimal engagement |

## Helper Methods

The application provides helper methods to ensure consistent color usage:

### Rating Helpers
```ruby
rating_color(rating)           # Returns color class for a rating
rating_badge(rating)           # Returns a badge with rating and appropriate color
```

### S.E.E. 20 Score Helpers
```ruby
nat_20_color(score)            # Returns color class for a S.E.E. 20 score
nat_20_badge(score)            # Returns a badge with S.E.E. 20 score and appropriate color
```

### Feedback Participation Helpers
```ruby
feedback_participation_color(submitted_count, total_count)  # Returns color class for participation
feedback_participation_badge(submitted_count, total_count)  # Returns a badge with participation and color
```

### Status Helpers
```ruby
status_color(status)           # Returns color class for a status
status_badge(status, text)     # Returns a badge with status and appropriate color
```

### Feedback Helpers
```ruby
feedback_color(type)           # Returns color class for feedback type
feedback_badge(type, text)     # Returns a badge with feedback type and appropriate color
```

### Conflict Style Helpers
```ruby
conflict_style_color(style)    # Returns color class for conflict style
conflict_style_badge(style)    # Returns a badge with conflict style and appropriate color
```

### General Helpers
```ruby
badge_class(color)             # Returns "badge bg-{color}"
text_class(color)              # Returns "text-{color}"
```

## Usage Examples

### In Views
```haml
/ Rating badge
= rating_badge(4)

/ S.E.E. 20 score badge
= nat_20_badge(18)

/ Feedback participation badge
= feedback_participation_badge(3, 5)

/ Status badge
= status_badge('submitted', 'Feedback Submitted')

/ Feedback badge
= feedback_badge('appreciation', 'Yes')

/ Conflict style badge
= conflict_style_badge('Collaborative')
```

### In CSS Classes
```haml
/ Using helper methods
%span{class: badge_class(rating_color(5))}= 5

/ Direct Bootstrap classes (when appropriate)
%span.badge.bg-info Count: 5
```

## Implementation Guidelines

1. **Always use helper methods** when displaying ratings, statuses, feedback types, or conflict styles
2. **Don't hardcode colors** - use the semantic color system
3. **Be consistent** - the same type of data should always use the same color
4. **Consider accessibility** - ensure sufficient contrast ratios
5. **Test with colorblind users** - the system should work for all users

## Constants

All color mappings are defined in `config/initializers/huddle_constants.rb`:

- `HuddleConstants::COLORS` - General color meanings
- `HuddleConstants::RATING_COLORS` - Individual rating colors
- `HuddleConstants::NAT_20_COLORS` - S.E.E. 20 score colors
- `HuddleConstants::STATUS_COLORS` - Status-specific colors
- `HuddleConstants::FEEDBACK_COLORS` - Feedback type colors
- `HuddleConstants::CONFLICT_STYLE_COLORS` - Conflict style colors

## Migration Notes

When updating existing components:

1. Replace hardcoded color classes with helper methods
2. Ensure semantic meaning matches the new system
3. Test visual consistency across the application
4. Update any custom CSS that might conflict with the new system

## Future Considerations

- Consider adding dark mode support
- Evaluate color contrast ratios for accessibility
- Consider adding color themes for different organizations
- Monitor user feedback on color usage and meaning

## Rating Color Mapping

Individual ratings use colors to provide immediate visual feedback:

| Rating | Color | Meaning |
|--------|-------|---------|
| 1-2 | Danger (Red) | Poor performance, needs immediate attention |
| 3 | Warning (Yellow/Orange) | Average performance, room for improvement |
| 4-5 | Success (Green) | Good to excellent performance |

## S.E.E. 20 Score Color Mapping

The S.E.E. 20 score is a composite score representing overall huddle performance:

| Score Range | Color | Meaning |
|-------------|-------|---------|
| 0-5 | Danger (Red) | Critical issues, needs immediate attention |
| 6-10 | Warning (Yellow/Orange) | Significant room for improvement |
| 11-15 | Info (Blue) | Average performance |
| 16-19 | Success (Green) | Good performance |
| 20 | Primary (Blue) | Perfect score - exceptional performance |

## Feedback Participation Color Mapping

Feedback participation badges change color based on completion percentage:

| Participation % | Color | Meaning |
|-----------------|-------|---------|
| 0-25% | Danger (Red) | Very low participation, needs immediate attention |
| 26-50% | Warning (Yellow/Orange) | Low participation, needs follow-up |
| 51-75% | Info (Blue) | Moderate participation |
| 76-99% | Success (Green) | Good participation |
| 100% | Primary (Blue) | Perfect participation - everyone has submitted |

## Status Color Mapping

| Status | Color | Meaning |
|--------|-------|---------|
| Active, Completed, Submitted | Success (Green) | Positive completion |
| Pending | Warning (Yellow/Orange) | Awaiting action |
| Inactive | Secondary (Gray) | Not currently active |
| Cancelled | Danger (Red) | Failed or cancelled |

## Feedback Type Colors

| Feedback Type | Color | Meaning |
|---------------|-------|---------|
| Appreciation | Success (Green) | Positive feedback |
| Suggestion | Warning (Yellow/Orange) | Improvement feedback |
| Private | Info (Blue) | Confidential information |

## Conflict Style Colors

| Conflict Style | Color | Meaning |
|----------------|-------|---------|
| Collaborative | Success (Green) | Positive, win-win approach |
| Competing | Warning (Yellow/Orange) | Needs attention, potential conflict |
| Compromising | Info (Blue) | Neutral, balanced approach |
| Accommodating | Secondary (Gray) | Passive approach |
| Avoiding | Light (Light Gray) | Minimal engagement |

## Helper Methods

The application provides helper methods to ensure consistent color usage:

### Rating Helpers
```ruby
rating_color(rating)           # Returns color class for a rating
rating_badge(rating)           # Returns a badge with rating and appropriate color
```

### S.E.E. 20 Score Helpers
```ruby
nat_20_color(score)            # Returns color class for a S.E.E. 20 score
nat_20_badge(score)            # Returns a badge with S.E.E. 20 score and appropriate color
```

### Feedback Participation Helpers
```ruby
feedback_participation_color(submitted_count, total_count)  # Returns color class for participation
feedback_participation_badge(submitted_count, total_count)  # Returns a badge with participation and color
```

### Status Helpers
```ruby
status_color(status)           # Returns color class for a status
status_badge(status, text)     # Returns a badge with status and appropriate color
```

### Feedback Helpers
```ruby
feedback_color(type)           # Returns color class for feedback type
feedback_badge(type, text)     # Returns a badge with feedback type and appropriate color
```

### Conflict Style Helpers
```ruby
conflict_style_color(style)    # Returns color class for conflict style
conflict_style_badge(style)    # Returns a badge with conflict style and appropriate color
```

### General Helpers
```ruby
badge_class(color)             # Returns "badge bg-{color}"
text_class(color)              # Returns "text-{color}"
```

## Usage Examples

### In Views
```haml
/ Rating badge
= rating_badge(4)

/ S.E.E. 20 score badge
= nat_20_badge(18)

/ Feedback participation badge
= feedback_participation_badge(3, 5)

/ Status badge
= status_badge('submitted', 'Feedback Submitted')

/ Feedback badge
= feedback_badge('appreciation', 'Yes')

/ Conflict style badge
= conflict_style_badge('Collaborative')
```

### In CSS Classes
```haml
/ Using helper methods
%span{class: badge_class(rating_color(5))}= 5

/ Direct Bootstrap classes (when appropriate)
%span.badge.bg-info Count: 5
```

## Implementation Guidelines

1. **Always use helper methods** when displaying ratings, statuses, feedback types, or conflict styles
2. **Don't hardcode colors** - use the semantic color system
3. **Be consistent** - the same type of data should always use the same color
4. **Consider accessibility** - ensure sufficient contrast ratios
5. **Test with colorblind users** - the system should work for all users

## Constants

All color mappings are defined in `config/initializers/huddle_constants.rb`:

- `HuddleConstants::COLORS` - General color meanings
- `HuddleConstants::RATING_COLORS` - Individual rating colors
- `HuddleConstants::NAT_20_COLORS` - S.E.E. 20 score colors
- `HuddleConstants::STATUS_COLORS` - Status-specific colors
- `HuddleConstants::FEEDBACK_COLORS` - Feedback type colors
- `HuddleConstants::CONFLICT_STYLE_COLORS` - Conflict style colors

## Migration Notes

When updating existing components:

1. Replace hardcoded color classes with helper methods
2. Ensure semantic meaning matches the new system
3. Test visual consistency across the application
4. Update any custom CSS that might conflict with the new system

## Future Considerations

- Consider adding dark mode support
- Evaluate color contrast ratios for accessibility
- Consider adding color themes for different organizations
- Monitor user feedback on color usage and meaning 