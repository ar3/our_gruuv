# Selection pages — showing and filtering by metadata (department, etc.)

Companion to [selection-pages-toolbar.md](./selection-pages-toolbar.md). Use when a multi-select list item has **primary label** (name/title) plus **secondary context** (department, tagline, position, etc.) that users need to **see** and often **filter** by.

**First page to apply:** Add Abilities to Observation (`observations/add_abilities`). Same rules apply to assignments, aspirations, and other ability/assignment multi-select pages in the [rollout plan](./selection-pages-rollout-plan.md).

---

## User goals

1. **Pick the right item** — disambiguate duplicate or similar names.
2. **Find items quickly** — by name and/or department (or equivalent).
3. **See what’s selected** — pills stay **short** (primary label only); full context stays in the list.

---

## Options compared

### A. Subtitle on each row (recommended default)

Each option shows **primary name** (`strong`) + **muted subtitle** (department, tagline, etc.).

| Pros | Cons |
|------|------|
| Works with existing **`options-filter`** — search matches all visible text (name + department) | No visual “chunking” when scrolling a very long flat list |
| No new Stimulus; matches **Manage Consumer Assignments** and **Manage Observees** | Company-wide / nil department needs a consistent label (e.g. “Company-wide”) |
| Pills stay name-only via `data-selection-toolbar-label` | |
| Easy to add in HAML on every rollout page | |

**Implementation sketch:**

Wrap options in `.selection-page-columns` (see [selection-pages-toolbar.md](./selection-pages-toolbar.md#column-layout-multi-select-lists)) — **1 / 2 / 3 columns** by breakpoint, no section headers required.

```haml
.selection-page-columns{ data: { options_filter_target: "list" } }
  .filterable-option
  .form-check
    = check_box_tag ..., data: { selection_toolbar_label: ability.name }
    = label_tag ..., class: "form-check-label" do
      %strong= ability.name
      %br
      %small.text-muted= ability.department&.display_name || "Company-wide"
```

**List order:** Sort in the controller with **nil department first** (company-wide bucket), then other departments alphabetically, then primary name within each bucket. Same sort key as `Abilities::AssignmentMilestonesController#load_assignments_in_hierarchy`: `[0, '']` for nil dept, `[1, display_name]` for others.

**Search placeholder:** Mention both dimensions, e.g. `"Search abilities by name or department..."`.

---

### B. Department section headers (grouped list)

Group options under headings (e.g. “Engineering”, “Sales”, “Company-wide”).

| Pros | Cons |
|------|------|
| Easy to scan when departments are few and lists are long | **Plain `options-filter` is awkward:** hiding all rows in a section leaves an **empty header** |
| Matches **abilities index** mental model | Headers are not selectable; filter logic must be **section-aware** to avoid clutter |
| | Collapsed sections + filter = more JS and state |
| | Selected pills don’t show department; user may forget which section an ability came from |

**When headers work well:** Read-only browse (index pages), not checkbox multi-select with a single search box.

**If you still want headers on selection pages:** Treat each section as a wrapper and extend filtering (see **Option D** below) — higher effort than A.

---

### C. Subtle dividers without full headers

Same as **A**, but insert a light `border-top` or spacing between department runs after sorting. No heading text.

| Pros | Cons |
|------|------|
| Slight visual grouping without header/filter mismatch | Empty “runs” possible when filter hides an entire department’s rows |
| Still one `filterable-option` per row | Marginal benefit over A alone |

Use only if A feels too flat after real data testing.

---

### D. Department control + search (two filters)

Toolbar adds a **department** `<select>` (or pills for departments) **and** the text search.

| Pros | Cons |
|------|------|
| “Show only Engineering” without typing | Extra control in an already busy toolbar |
| Good at very large orgs (many depts) | New Stimulus (or server round-trip); not needed if text search covers department names |
| | Two filters to explain and test on mobile |

**When to consider:** User research shows people always filter by department first, or dept count is large enough that typing department names is painful.

---

### E. Searchable metadata only in `data-*` (not shown)

Put department in a `data-search-text` attribute but don’t show it.

| Pros | Cons |
|------|------|
| Keeps rows visually minimal | **Fails the “view department” requirement** — do not use when users need to see dept |

---

## Recommendation (approved)

For **Add Abilities** and similar **selection toolbar** pages:

| Decision | Choice |
|----------|--------|
| **Display** | **Option A** — subtitle under name (`small.text-muted`) |
| **Nil department** | Label **`Company-wide`** in subtitle (search matches this text) |
| **Sort** | **Nil department first**, then department name A–Z, then primary name |
| **Filter** | **`options-filter`** on row text; placeholder mentions name and department |
| **Pills** | Primary name only (`selection_toolbar_label`) |
| **Section headers** | **Defer** unless you invest in section-aware filter (Option B + D-style JS) |

This is the same pattern already documented for assignments on consumer assignments (title + department in row, title-only pills).

**Not recommended for v1:** Department headers without section-aware filtering — it will look broken when search hides all items under a header.

---

## Section-aware filtering (future enhancement)

If grouped headers (B) are required later:

1. Wrap each department block in `.selection-group` with a non-filterable `.selection-group__heading`.
2. Extend `options_filter_controller` (or a thin wrapper) to hide a group when **no** `.filterable-option` inside it is visible.
3. Keep one search input; no orphan headers.

Document and implement only when a specific page fails user testing with Option A.

---

## Rollout checklist (abilities, assignments, aspirations)

When applying metadata to a selection page:

- [ ] Controller sorts **nil metadata first**, then metadata value, then primary name.
- [ ] Row: `filterable-option` + `strong` + `small.text-muted` subtitle.
- [ ] `data-selection-toolbar-label` = primary name only.
- [ ] Search `placeholder` / `aria-label` mention searchable fields.
- [ ] Consistent label for nil department: **`Company-wide`** on selection pages.
- [ ] Request spec: body includes department display name and company-wide label where applicable.

---

## Pages this applies to (from rollout plan)

| Entity | Pages |
|--------|--------|
| **Abilities** | Add abilities (observation) ✅ target; dept associate abilities; feedback select focus (abilities section) |
| **Assignments** | Add assignments (observation); consumer assignments (done); teammate assignment selection; dept associate assignments |
| **Aspirations** | Add aspirations (observation); dept associate aspirations; feedback select focus |
| **Teammates** | Manage observees (position/department already in card body — search already matches) |

Goals may use category/privacy in subtitle instead of department — same **Option A** pattern, different subtitle fields.

---

## Status

| Item | State |
|------|--------|
| UX decision doc | Approved (Option A, Company-wide, nil dept first) |
| Add Abilities implementation | Done |
| Add Assignments implementation | Done |
