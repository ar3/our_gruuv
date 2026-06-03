# Page help — section structure

Reference for clarity/MAAP page help panels. Full interaction pattern: [page-help-pattern.md](../page-help-pattern.md). Cursor rule: `.cursor/rules/page-help-ux-pattern.mdc`.

## Three top-level sections (`h3`)

| Section | Contents |
| --- | --- |
| **Goal of this page** | One paragraph: what the user is trying to accomplish on this screen. |
| **Context** | Reusable background: MAAP definition (`shared/maap/definition`), three-step clarity flow (`shared/check_ins/three_step_clarity_flow`) when the page fits that rhythm. |
| **Specifics of this page** | Copy and bullets that apply only to this route (controls, energy bars, sections, when to use bypass vs normal flow, etc.). |

## Subsections (`h5`)

Under **Context**, shared partials own their titles:

- What is MAAP?
- The three-step clarity check-in flow

Under **Specifics of this page**, each page uses its own `h5` labels (e.g. “Bulk clarity check-in”, “Sections on this page”).

## Pages using this structure

- Bulk clarity check-in — `check_ins/_bulk_check_in_page_help.html.haml`
- Review / finalization — `finalizations/_finalization_page_help.html.haml`
- Single-assignment check-in — `teammates/assignments/_single_item_check_in_page_help.html.haml`
- Set day-to-day assignments (tenure bypass) — `company_teammates/_set_day_to_day_assignments_page_help.html.haml`
