# Page Help Pattern (Header Info Icon + Expandable Explainer)

**Canonical example:** Protect Flow — `app/views/organizations/protect_flow/show.html.haml` + `_page_help.html.haml`.

Use this pattern when a page has dense or stateful UI and users benefit from in-context guidance.

Cursor rule: `.cursor/rules/page-help-ux-pattern.mdc`. Section structure detail: [UX/page-help-structure.md](UX/page-help-structure.md).

**Object × Lens list/show headers:** place the info icon immediately after the lens dropdown, then the primary action (plus on List / edit on Show). Tooltips: `Add new {Object}` / `Edit {Object}`. See [UX/object-lens-header-actions.md](UX/object-lens-header-actions.md) and `.cursor/rules/object-lens-header-actions.mdc`.

---

## Canonical implementation (do this)

1. **Header** — title and info control in one `h1` flex row:

```haml
- page_help_id = "myPageHelp"

- content_for :header do
  .d-flex.flex-wrap.align-items-center.gap-2
    %h1.mb-0.d-flex.align-items-center.gap-2
      Page Title
      = render "shared/page_help/header_info_button",
               collapse_id: page_help_id,
               tooltip: "One short sentence about this page. Click for details."
```

2. **Collapse** — immediately below the header (not inside `content_for :header`):

```haml
.collapse.mb-4{id: page_help_id}
  = render "organizations/my_feature/page_help"
```

3. **Help partial** — `.alert.alert-light.border` with three `%h3` sections (Goal → Context → Specifics). See checklist below.

### Shared control (required)

Always use `shared/page_help/header_info_button` — do **not** inline a duplicate button.

That partial owns the standard icon CSS:

- `bi-info-circle`
- `fs-1 lh-1 align-middle`
- subtle `text-shadow`
- link-styled button (`btn btn-link p-0 text-body`)
- hover tooltip + click collapse (`aria-controls` / `aria-expanded` / `aria-label`)

---

## Expanded help structure (three H3 sections)

Every expanded help alert should use **three top-level sections** (`%h3.fw-semibold.mb-2`):

1. **Goal of this page** — one short paragraph: what success looks like on this screen.
2. **Context** — shared background when applicable:
   - `= render 'shared/maap/definition'` (subhead: `%h5` “What is MAAP?”)
   - `= render 'shared/check_ins/three_step_clarity_flow', organization:, teammate:` when the page is part of the clarity check-in rhythm
   - Or short product context (e.g. Gruuv Health / Engagement Health) when MAAP/clarity partials do not apply
3. **Specifics of this page** — only what differs on this route; use **`%h5`** subheads for subsections (e.g. “How to read each row”, “Status legend”, “Refresh”).

Do not put page-only bullets under Context. Do not duplicate the three-step flow outside Context.

Shell:

```haml
.alert.alert-light.border
  %h3.fw-semibold.mb-2 Goal of this page
  %p.mb-3 …

  %h3.fw-semibold.mb-2 Context
  %p.mb-3 …

  %h3.fw-semibold.mb-2 Specifics of this page
  %h5.fw-semibold.mb-2 …
```

---

## Anti-patterns (migrate when you touch the page)

| Variant | What it looks like | Replace with |
| --- | --- | --- |
| **A. Canonical** | `header_info_button` + `.alert.alert-light.border` + Goal/Context/Specifics | Keep |
| **B. Inline icon clone** | Same `fs-1` + text-shadow markup copied into the view instead of the shared partial | `render "shared/page_help/header_info_button"` |
| **C. Old blue help shell** | `.alert.alert-info` + `%h5 Ultimate goal` (or flat help without three H3s) | `.alert.alert-light.border` + three `%h3` sections |
| **D. Tiny/decorative info** | Small `bi-info-circle` (no `fs-1`), often only a tooltip or static hint — not a page explainer | Either upgrade to full page-help, or leave as a *field-level* hint (not page help) |

Fix pages opportunistically as you edit them; do not mass-migrate the whole app in one pass unless asked.

---

## Shared building blocks (DRY)

| Partial | Use for |
| --- | --- |
| `shared/page_help/header_info_button` | Info icon + tooltip + collapse target beside the page title |
| `shared/maap/definition` | MAAP reverse acronym when MAAP/clarity-related |
| `shared/check_ins/three_step_clarity_flow` | Linked three-step clarity rhythm when applicable |

Page-specific help partials live beside their views (e.g. `organizations/protect_flow/_page_help.html.haml`).

---

## Authoring Checklist

- [ ] Info icon via `shared/page_help/header_info_button` in the `h1` row
- [ ] Expanded help in `.collapse.mb-4` **below** the header
- [ ] Help body is `.alert.alert-light.border` (not `alert-info`)
- [ ] **Goal of this page** (`%h3`) with one-sentence ultimate goal
- [ ] **Context** (`%h3`) with shared background when useful
- [ ] **Specifics of this page** (`%h3`) with page-only copy under `%h5` subheads
- [ ] Concrete **example block** when it helps interpretation
- [ ] State legend(s) with visual color markers matching production colors (status-heavy pages)
- [ ] Guidance for refresh/recompute controls when they exist
- [ ] Tooltip + expand interaction accessible (`aria-controls`, `aria-expanded`, label)

## Copy Template

### Tooltip

`Quickly understand what needs attention on this page. Click for a full breakdown.`

(Or a one-line page purpose + “Click for details.”)

### State line format

- `<color dot> <State name> - <why it appears / what it means>`

## Notes for Reuse Across Pages

- Keep the interaction pattern constant (shared partial + tooltip + click-expand).
- Keep the **three H3 sections** constant; only Context partials and Specifics copy change per page.
- Prefer short, skimmable sections over long prose.

## Health dashboards (canonical set)

These five switcher pages should all follow the canonical pattern:

| Page | Help partial |
| --- | --- |
| Protect Flow | `organizations/protect_flow/_page_help.html.haml` |
| Check-ins Health | `organizations/check_ins_health/_page_help.html.haml` |
| Goals Health | `organizations/goals_health/_page_help.html.haml` |
| Abilities Health | `organizations/abilities_health/_page_help.html.haml` |
| Milestones Health | `organizations/milestones_health/_page_help.html.haml` |
| Observations Health | `organizations/observations_health/_page_help.html.haml` |
