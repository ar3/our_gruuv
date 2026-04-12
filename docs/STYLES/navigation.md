# Navigation Style Guide

This document defines the standard navigation patterns used throughout the OurGruuv application.

## Navigation Patterns

### View Switching
- Use dropdown buttons that show current state
- Button text should reflect current mode (e.g., "Management Mode", "Teammate Mode")
- Remove redundant labels - the button text IS the current state indicator

## Page context: return back vs hierarchy (authenticated v1)

Use `content_for :go_back_link` in layouts that yield it (authenticated vertical and horizontal navigation).

### When the app has an explicit return URL

Use **`nav_return_back`** — left arrow (`bi-arrow-left`) and muted `go-back-link` styling (same arrow vocabulary as hierarchy **Back**). This is for in-app destinations passed as `return_url` / `return_text` (or equivalent) so the label matches where the user actually came from.

```haml
- content_for :go_back_link do
  = nav_return_back(url: @return_url, text: @return_text)
```

If `text` is omitted but `url` is present, the label defaults to **Return**.

### When there is no explicit return URL

Use **`nav_hierarchy_with_previous`** — on one row: optional **Back** (left arrow + the word “Back”, runs `history.back()`), a **|** separator with even spacing, then a **Bootstrap breadcrumb** (place names only; no arrow on the trail). Stimulus (`navigation-previous`) only reveals the Back + divider group when `window.history.length > 1` (heuristic; not perfect).

```haml
- content_for :go_back_link do
  = nav_hierarchy_with_previous(organization: @organization, crumbs: [{ label: "Goals", url: nil }])
```

- **`organization:`** (required) — the first breadcrumb segment is always this org’s **display name** linking to **Start Here** (`organization_start_here_path`).
- **`crumbs:`** — tail only (everything after that first segment). Array of `{ label:, url: }`; **last** crumb is the current page (`url: nil`). At least one tail crumb is required.
- **`nav_organization_breadcrumb_crumb(organization)`** — optional if you build crumbs manually elsewhere; hierarchy nav prepends the same segment automatically.
- Use **`aria-label="Breadcrumb"`** (handled by the helper) and `aria-current="page"` on the active item.

### Branching pattern (return if present, else hierarchy)

```haml
- content_for :go_back_link do
  - if @return_url.present? && @return_text.present?
    = nav_return_back(url: @return_url, text: @return_text)
  - else
    = nav_hierarchy_with_previous(organization: @organization, crumbs: [...])
```

### Legacy note

Older examples used a single `go-back-link` with "Back to …" for logical parents even when the user did not come from that page. **Do not** use that pattern for hierarchy-only navigation; use **`nav_hierarchy_with_previous`** instead.

### Out of v1 scope

Overlay layout, public MAAP, and other layouts may still use older patterns until migrated.

## Implementation Checklist

When creating or updating navigation, ensure:
- [ ] **Return mode:** `nav_return_back` only with explicit in-app `return_url`
- [ ] **Hierarchy mode:** `nav_hierarchy_with_previous` with accurate crumb labels
- [ ] **Breadcrumb:** accessible structure (`nav`, `ol.breadcrumb`, current item marked)
- [ ] **Browser Back:** understand JS guard limitations (Turbo/history stack)
