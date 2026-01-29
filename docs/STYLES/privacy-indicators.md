# Privacy/Visibility Indicators Style Guide

## Overview

This document defines the standard patterns for displaying privacy/visibility levels throughout the application. Consistency in these indicators helps users quickly understand who can see content without needing to learn multiple visual systems.

## Core Principle: "Visible to" + Dots

Privacy is a **spectrum from closed to open**. We use a progressive dot fill pattern where **more filled dots = visible to more people**. This metaphor is intuitive and doesn't conflict with our semantic color system.

## Standard Label

Always use **"Visible to:"** as the label prefix. This phrasing:
- Aligns with the dot metaphor (more dots = visible to more)
- Works grammatically with both dots AND names
- States the outcome (who can see), not the setting
- Avoids the cognitive dissonance of "Privacy" (where "high privacy" would mean fewer dots)

## Display Patterns by Context

### Dense Views (Tables, Long Lists)
**Pattern:** `Visible to: 🔘🔘🔘○` with tooltip

Use when:
- 10+ items are visible at once
- Horizontal space is limited
- Quick scanning is the priority

```haml
%span.text-muted.small{"data-bs-toggle" => "tooltip", "data-bs-title" => tooltip_text}
  = visibility_display(item)
```

### Moderate Density Views (Cards, Short Lists)
**Pattern:** `Visible to: 🔘🔘🔘○` with tooltip

Same as dense views. The dots pattern works well for most list contexts.

### Detail/Show Pages (Single Item Focus)
**Pattern:** Full contextual text with actual names

Use when:
- User is focused on a single item
- Space is available
- Maximum clarity is valuable

Examples:
```
Visible to: Just me (private journal)
Visible to: Sarah Chen, Bob Smith
Visible to: Sarah Chen, Bob Smith, and their managers
Visible to: Everyone at Acme Corp
```

### Forms (Selecting Privacy)
**Pattern:** Radio buttons with full descriptions

Decision points need complete information to help users make informed choices.

## Dot Patterns by Entity

### Goals (4 levels)

| Privacy Level | Dots | Tooltip |
|---------------|------|---------|
| only_creator | `🔘○○○` | Only the creator can view this goal |
| only_creator_and_owner | `🔘🔘○○` | The creator and owner can view this goal |
| only_creator_owner_and_managers | `🔘🔘🔘○` | The creator, owner, and their managers can view this goal |
| everyone_in_company | `🔘🔘🔘🔘` | Everyone in the company can view this goal |

### Observations (5-6 levels)

| Privacy Level | Dots | Tooltip |
|---------------|------|---------|
| observer_only | `🔘○○○○` | Just for me (Journal) |
| observed_only | `🔘🔘○○○` | Just the observee(s) |
| managers_only | `🔘○🔘○○` | Just managers |
| observed_and_managers | `🔘🔘🔘○○` | Observees and their managers |
| public_to_company | `🔘🔘🔘🔘○` | Everyone in the company |
| public_to_world | `🔘🔘🔘🔘🔘` | Public (anyone with link) |

## What NOT to Do

### Don't Use Colors for Privacy Levels

Colors in our system have semantic meanings (red = danger, green = success, etc.). Using colors for privacy creates confusion:
- Is red "danger" or "most private"?
- Is green "success" or "most open"?

### Don't Use Icons Alone

Icons like 🔒, 👤, 👥, 🏢, 🌐 require users to learn/remember meanings. The progressive dot pattern is self-explanatory.

### Don't Mix Patterns

Pick one pattern for each context and use it consistently. Don't show dots in one card and icons in another.

## Helper Methods

### Goals

```ruby
# Returns "Visible to: 🔘🔘🔘○"
goal_visibility_display(goal)

# Returns just the dots: "🔘🔘🔘○"
goal_privacy_rings(goal)

# Returns tooltip text explaining who can see
goal_privacy_tooltip_text(goal)

# Legacy: Returns "🔘🔘🔘○ Creator, Owner & Managers"
goal_privacy_rings_with_label(goal)
```

### Observations

```ruby
# Returns just the dots: "🔘🔘🔘○○"
observation.decorate.privacy_rings

# Returns "🔘🔘🔘○○ Stakeholders"
observation.decorate.privacy_rings_with_label

# Returns full contextual text with names
privacy_level_display_text(observation)
```

## Implementation Examples

### HAML - Dense/Moderate View
```haml
%span.text-muted.small{"data-bs-toggle" => "tooltip", "data-bs-title" => goal_privacy_tooltip_text(goal)}
  = goal_visibility_display(goal)
```

### Ruby Helper - Dense/Moderate View
```ruby
content_tag(:span, goal_visibility_display(goal), 
  class: 'text-muted small', 
  'data-bs-toggle': 'tooltip', 
  'data-bs-title': goal_privacy_tooltip_text(goal))
```

### HAML - Detail View
```haml
%p
  %strong Visible to:
  = privacy_level_display_text(@observation)
```

## Migration Checklist

When updating existing privacy indicators:

1. Remove any colored badges used for privacy
2. Replace with `Visible to: [dots]` pattern
3. Ensure tooltip shows explanatory text
4. Use `text-muted small` styling for the display
5. Test that tooltips work on hover/focus

## Accessibility

- Dots provide shape-based differentiation (not color-dependent)
- Tooltips provide full text for screen readers
- Ensure sufficient contrast for dot characters
- Consider adding `aria-label` with tooltip text for better screen reader support
