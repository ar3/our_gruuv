# Spotlight footer View switcher

**Status:** Pattern locked (Goals index is the reference). Other index pages should adopt this when next touched—do not batch-migrate unless asked.

**Cursor rule:** `.cursor/rules/spotlight-footer-view-switcher.mdc`  
**Style guide:** `docs/STYLES/index-pages.md` (Spotlight → footer View switcher)

## Why

Index spotlights already show current View in the footer. Making that line a link-style dropdown lets people change view without opening Customize View, using the same “underlined link → pick an option” feel as other chrome (e.g. Goals “for …” owner, show-page child goal type).

## Canonical example

`app/views/organizations/goals/index.html.haml` — spotlight `.card-footer`, right column:

- Label: muted `View:`
- Toggle: underlined `btn-link` / `dropdown-toggle` showing `goal_index_view_style_label(@view_style)`
- Menu: grouped options via `goal_index_view_style_groups`; each item links through `goal_index_path_with_view(...)` so filters/owner/spotlight/sort stay put
- Active style gets `dropdown-item active`

Helpers live in `GoalsHelper` (`GOAL_INDEX_VIEW_STYLE_LABELS`, `goal_index_view_style_label`, `goal_index_view_style_groups`, `goal_index_path_with_view`).

## Checklist when upgrading another index

1. Find spotlight `.card-footer` `View:` (static text or native select).
2. Replace with link-style dropdown matching Goals (muted underline toggle, not an outline button / ugly select).
3. Preserve existing query params; only change the view param.
4. Use human labels (helper or equivalent); mark current selection active.
5. Add/extend a request spec that hits the index and asserts the toggle + at least one view option link.
6. Leave Customize View alone unless that page’s view radios are wrong/outdated for another reason.

## Known indexes still on static View (upgrade when focused)

- Observations (`organizations/observations/index`)
- Assignments (`organizations/assignments/index`) — often `View: Table`
- Abilities (`organizations/abilities/index`) — often `View: Table`
- Other indexes with spotlight footers that print View without a dropdown

## Explicitly not this pattern

- Header primary filters (owner / “for …”)
- Customize View settings pages (radios/checkboxes stay fine)
- Sort / Filters / Spotlight footer lines (unless product asks to match View later)
