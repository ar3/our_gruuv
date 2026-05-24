---
name: selection-pages-toolbar
description: >-
  Apply the selection pages toolbar UX (search, selected pills with remove,
  duplicate save) to multi-select checkbox pages. Use when updating manage
  observees, consumer assignments-style pages, or executing an item from
  docs/UX/selection-pages-rollout-plan.md.
---

# Selection pages toolbar

## Before coding

1. Read **`docs/UX/selection-pages-toolbar.md`** (pattern, markup, checklist).
2. If the user named a rollout item, read **`docs/UX/selection-pages-rollout-plan.md`** and implement **only that one page** unless they explicitly ask for more.
3. Read the **reference implementation:** `app/views/organizations/assignments/consumer_assignments/show.html.haml`.

## Rules

- **One page per session** after Phase A: implement, run request specs for that view, stop for manual review. Do not start the next rollout item until the user approves.
- Reuse **`shared/selection_pages/_toolbar`**, **`_save_button`**, controllers `selection-toolbar` + `options-filter`.
- Toolbar lives **inside the selection card**, below intro text.
- Pills: **title only** via `data: { selection_toolbar_label: ... }`; × unchecks; client-side sync.
- **Top and bottom save** with the same label; bottom save stays when the list is empty.
- Do not apply this pattern to customize-view filters, bulk sync, or single-select pages (see rollout plan “out of scope”).

## Implementation steps

1. Wrap toolbar + list: `data: { controller: "selection-toolbar options-filter" }`.
2. Render toolbar partial with `form`, `save_label`, `can_manage`, search placeholder/aria-label.
3. Mark each option `.filterable-option`; list container `data-options-filter-target="list"`.
4. Set `selection_toolbar_label` on each enabled checkbox.
5. Duplicate save at bottom via `_save_button`.
6. Run associated **`spec/requests/**`** specs; fix failures.

## After finishing

- Update **“Where it’s used”** in `docs/UX/selection-pages-toolbar.md` and check off the item in `docs/UX/selection-pages-rollout-plan.md` only if the user asked to mark progress.
- Remind the user to manually test and deploy before the next rollout item.
