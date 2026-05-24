# Selection pages toolbar (search, pills, save)

Use this pattern on **multi-select “pick from a long list and save”** pages: a toolbar inside the selection card with **search → selected pills → save**, plus a **duplicate save** at the bottom of the form.

**Reference implementation:** Manage Consumer Assignments — `app/views/organizations/assignments/consumer_assignments/show.html.haml`

**Rollout plan (one phase at a time):** [selection-pages-rollout-plan.md](./selection-pages-rollout-plan.md)

---

## When to use

- User picks **many** entities (assignments, teammates, abilities, goals, etc.) via checkboxes
- List can be long enough to need client-side search
- Page submits a form to persist the selection set
- Overlay or full-page “manage X” flows with return URL/text

## When not to use

- **Filter / customize view** pages (saved index filters, small static enums)
- **Single-select** pickers (link cards, one radio per row) — use [options-filter](../STYLES/options-filter.md) only
- **Per-row extra fields** (e.g. position assignment energy %) — different UX
- **Bulk import review** tables (bulk sync) — keep existing select-all tables
- Pages where unauthorized users are **view-only on the same page** — these flows typically **redirect** instead

---

## Toolbar layout

Inside the **card body**, below intro copy, above the option list:

| Zone | Desktop (`md+`) | Mobile |
|------|-----------------|--------|
| Search | Left, `form-control-lg` | Full width, stacked first |
| Selected pills | Center, `flex-grow-1`, wrap | Full width, stacked second |
| Save | Right, primary submit | Full width, stacked third |

Stack using `flex-column flex-md-row` on `.selection-toolbar` (see partial).

**Empty selection:** show **“None selected”** (`text-muted small`) until at least one enabled checkbox is checked.

**Pills:**

- **Title only** on the pill (not subtitle/department) — set explicitly on the checkbox (see below)
- **Compact:** `badge bg-primary rounded-pill`, `fs-6`, `py-1 px-2`
- **Remove:** × button (`bi-x`) unchecks the checkbox; works even when the row is hidden by search
- **Order:** DOM order of checkboxes (same as sorted list), not click order
- **Disabled checkboxes** are excluded from pills and from pill-driven uncheck

**Save:**

- Same label and styling at **top** (toolbar) and **bottom** (separate card or card footer)
- Use `btn-lg` when the page already used large primary saves
- Bottom save remains when the option list is empty (toolbar hidden)

---

## Building blocks

| Piece | Location |
|-------|----------|
| Toolbar partial | `app/views/shared/selection_pages/_toolbar.html.haml` |
| Save button partial | `app/views/shared/selection_pages/_save_button.html.haml` |
| Pills + sync | `app/javascript/controllers/selection_toolbar_controller.js` |
| Search + filter rows | `app/javascript/controllers/options_filter_controller.js` — [options-filter](../STYLES/options-filter.md) |

Both Stimulus controllers go on **one wrapper** around the toolbar and the list:

```haml
.mb-3{ data: { controller: "selection-toolbar options-filter" } }
  = render "shared/selection_pages/toolbar", ...
  .row{ data: { options_filter_target: "list" } }
    -# options with .filterable-option
```

---

## Toolbar partial locals

| Local | Required | Notes |
|-------|----------|-------|
| `form` | yes | `form_with` builder |
| `save_label` | yes | Submit button text |
| `can_manage` | yes | Enables submit vs disabled + tooltip |
| `search_placeholder` | yes | e.g. `"Search assignments..."` |
| `search_aria_label` | yes | e.g. `"Filter assignments"` |
| `empty_selection_label` | no | Default `"None selected"` |
| `disabled_tooltip` | no | Tooltip when save disabled |
| `large_save` | no | Default `false`; use `true` for `btn-lg` |

---

## Checkbox markup

Each selectable row:

1. Wrapper with class **`filterable-option`** (search matches visible text in the row — title + subtitle if present).
2. Checkbox with stable **`id`**.
3. **`data: { selection_toolbar_label: "Title only" }`** for pill text (recommended when the label has extra lines).

```haml
.mb-2.filterable-option
  .form-check
    = check_box_tag "consumer_assignment_ids[]",
      assignment.id,
      checked,
      class: "form-check-input",
      id: "consumer_assignment_#{assignment.id}",
      disabled: !can_manage,
      data: { selection_toolbar_label: assignment.title }
    = label_tag "consumer_assignment_#{assignment.id}", class: "form-check-label" do
      %strong= assignment.title
      %br
      %small.text-muted= assignment.department&.display_name || assignment.company.name
```

If `selection_toolbar_label` is omitted, the controller uses the first `<strong>` in the associated label, then full label text, then the checkbox value.

---

## Full page checklist

1. **Single form** wraps toolbar, list, and bottom save.
2. Compute **`can_manage`** (or equivalent) once; pass to toolbar and both save buttons.
3. **Toolbar + list** only when `@items.any?` (or equivalent).
4. **Bottom save** always (or when save is meaningful with zero options).
5. Add **`filterable-option`** on each option wrapper; **`data-options-filter-target="list"`** on the list container.
6. Run **request specs** for that controller/view after changes (see `.cursor/rules/view-changes-request-specs.mdc`).
7. Manual test: search, check/uncheck, pill ×, save top and bottom, hidden-row uncheck via pill.

---

## Search behavior

Client-side only. `options-filter` hides options whose **`textContent`** does not include the query (case-insensitive). Subtitle text in the row is included automatically. No server round-trip.

---

## Permissions

For MAAP-style pages, users without permission are **redirected** — do not build a read-only toolbar on those routes. Disabled checkboxes + disabled save with tooltip only apply when the same page is shown but submit is blocked (rare; match existing page policy).

---

## Where it’s used

- **Manage Consumer Assignments** — `organizations/assignments/:id/consumer_assignments`
- **Manage Observees** — `organizations/observations/:id/manage_observees`

When you add this pattern to another page, add it here and in [selection-pages-rollout-plan.md](./selection-pages-rollout-plan.md).
