# Association expand: Add more link

**Canonical implementation:** Position manage assignments (`organizations/positions/_assignment_form_sections` → `shared/association_expand/_add_more_link`).

## When to use

On “associate multiple things” pages where the **already associated** list is shown first, and the **available / not-yet-associated** list is collapsed behind an expand control.

## Where it’s used

| Page | Partial | CTA |
|------|---------|-----|
| Position manage assignments | `organizations/positions/_assignment_form_sections` | Add Assignments |
| Position Direct Milestone Requirements | `shared/ability_milestones/_form_sections` | Add Ability Milestones |
| Assignment Ability Milestone Requirements | same shared partial | Add Ability Milestones |
| Ability Assignment Milestone Requirements | `shared/assignment_milestones/_form_sections` | Add Assignment Milestones |
| Title manage paths | `organizations/titles/_title_path_form_sections` | Add Title Paths |
| Assignment reliance | `organizations/assignments/consumer_assignments/_reliance_form_sections` | Add Assignment Reliance |
| Day-to-day assignment tenure bypass | page-local | Add Assignments |

## Pattern

Do **not** bury the action in one long sentence.

Use a single clickable control (`shared/association_expand/_add_more_link`) with:

1. **CTA** — short, verb-first, slightly larger (`fw-semibold fs-5`), with `bi-plus-circle` before and `bi-chevron-down` after; capitalize the domain noun when it is a product proper noun (e.g. **Assignments**, **Abilities**, **Titles**)
2. **Supporting sentence** — muted, one line under the CTA (why / what’s available)
3. **Whole block expands** — both CTA and sentence are inside the same collapse toggle link

### Copy shape

| Part | Example |
|------|---------|
| CTA | `Add Assignments` / `Add Ability Milestones` / `Add Title Paths` |
| Supporting | `Click to expand if being a Senior Software Engineer needs more of the 42 available Assignments.` |

Supporting text starts with **Click to expand if…**, then keep the page’s natural subject wording (including inverse forms like “is required by more of the…”).

### Markup

```haml
= render "shared/association_expand/add_more_link",
  collapse_id: "addPositionAssignments",
  cta_label: "Add Assignments",
  supporting_text: "Click to expand if being a #{subject_name} needs more of the #{available_count} available Assignments."
```

## Anti-patterns

- One long link line ending in “… add new …”
- CTA only (no context) or context only (no clear verb)
- Separate links for CTA vs sentence (they must share one expand target)
