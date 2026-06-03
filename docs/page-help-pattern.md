# Page Help Pattern (Header Info Icon + Expandable Explainer)

Use this pattern when a page has dense or stateful UI and users benefit from in-context guidance.

## UX Contract

- Show an info icon directly to the right of the page title.
- On hover: show a short tooltip that explains purpose and says click for details.
- On click: expand/collapse a hidden full-width alert below the header.
- Keep help page-specific and practical.

## Expanded help structure (three H3 sections)

Every expanded help alert should use **three top-level sections** (`%h3.fw-semibold.mb-2`):

1. **Goal of this page** — one short paragraph: what success looks like on this screen.
2. **Context** — shared background reused across MAAP/clarity pages:
   - `= render 'shared/maap/definition'` (subhead: `%h5` “What is MAAP?”)
   - `= render 'shared/check_ins/three_step_clarity_flow', organization:, teammate:` when the page is part of the clarity check-in rhythm (subhead: `%h5` “The three-step clarity check-in flow”)
3. **Specifics of this page** — only what differs on this route; use **`%h5`** subheads for subsections (e.g. “This page”, “Bulk clarity check-in”, “Sections on this page”).

Do not put page-only bullets under Context. Do not duplicate the three-step flow outside Context.

## Shared building blocks (DRY)

| Partial | Use for |
| --- | --- |
| `shared/maap/definition` | MAAP reverse acronym (Position, Assignment, Abilities, Milestones)—also for Assignment, Position, and Ability pages over time |
| `shared/check_ins/three_step_clarity_flow` | Linked three-step flow: Reflect Apart → bulk check-in; Review Together → finalization; Acknowledge/Observe → audit |
| `shared/page_help/header_info_button` | Info icon + tooltip + collapse target beside the page title |

Page-specific help partials live beside their views; pass `organization` and `teammate` (and any page locals) into shared partials.

## Authoring Checklist

- [ ] Info icon in header; expanded help in a `.collapse.mb-4` **below** the header (not inside `content_for :header`).
- [ ] **Goal of this page** (`%h3`) with one-sentence ultimate goal.
- [ ] **Context** (`%h3`) with MAAP definition and three-step flow when applicable.
- [ ] **Specifics of this page** (`%h3`) with page-only copy under `%h5` subheads.
- [ ] Concrete **example block** (mini table/card/row) when it helps interpretation.
- [ ] State legend(s) with visual color markers matching production colors (status-heavy pages).
- [ ] Guidance for action controls (refresh/recompute), including when not to use them.
- [ ] Tooltip + expand interaction present and accessible (`aria-controls`, `aria-expanded`, label).

## Copy Template

### Tooltip

`Quickly understand what needs attention on this page. Click for a full breakdown.`

### State line format

- `<color dot> <State name> - <why it appears / what it means>`

## Example Interpretation Pattern

- "If top status is `<state A>` and recency is `<state B>`, this usually means `<actionable interpretation>`."

## Notes for Reuse Across Pages

- Keep the interaction pattern constant (icon + tooltip + click-expand).
- Keep the **three H3 sections** constant; only Context partials and Specifics copy change per page.
- Prefer short, skimmable sections over long prose.
