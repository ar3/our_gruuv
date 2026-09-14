# Association expand: Add more link

**Canonical implementation:** Position manage assignments (`organizations/positions/_assignment_form_sections` → `shared/association_expand/_add_more_link`).

## When to use

On “associate multiple things” pages where the **already associated** list is shown first, and the **available / not-yet-associated** list is collapsed behind an expand control.

Examples (roll out one page at a time after visual approval):

- Position manage assignments (done — reference)
- Ability / assignment milestone requirement forms (`shared/ability_milestones/_form_sections`, `shared/assignment_milestones/_form_sections`)
- Title path associations (`organizations/titles/_title_path_form_sections`)
- Day-to-day assignment tenure bypass add section
- Any similar Change + collapsed Add pattern

## Pattern

Do **not** bury the action in one long sentence.

Use a single clickable control (`shared/association_expand/_add_more_link`) with:

1. **CTA** — short, verb-first, slightly larger (`fw-semibold fs-5`), with `bi-plus-circle` before and `bi-chevron-down` after; capitalize the domain noun when it is a product proper noun (e.g. **Assignments**)
2. **Supporting sentence** — muted, one line under the CTA (why / what’s available)
3. **Whole block expands** — both CTA and sentence are inside the same collapse toggle link

### Copy shape

| Part | Example |
|------|---------|
| CTA | `Add Assignments` |
| Supporting | `Click to expand if being a Senior Software Engineer needs more of the 42 available Assignments.` |

CTA should name the thing being added (`Add Abilities`, `Add Title Paths`, etc.). Supporting text starts with **Click to expand if…** then subject + available count context.

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

## Rollout

Reference page first; after manual review, apply the same partial + copy shape to the other associate pages listed above.
