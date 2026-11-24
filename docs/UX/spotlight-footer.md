# Spotlight footer (index pages)

**Status:** Pattern locked. **Canonical example:** Goals index (`organizations/goals/index` spotlight `.card-footer`). Adopt on other indexes when that page is the focus—do not batch-migrate unless asked.

**Style guide:** `docs/STYLES/index-pages.md` (Spotlight footer)  
**Cursor rule:** `.cursor/rules/spotlight-footer.mdc`  
**View-only pointer (legacy):** `docs/UX/spotlight-footer-view-switcher.md` → redirects readers here

## Layout

Two columns inside `.card-footer.bg-light`:

| Side | Content (top → bottom) |
|------|-------------------------|
| **Left** | `Filters:` + grey display-only pills · on-page quick filters (if any) · short caption / Customize View hint |
| **Right** (end-aligned) | **View** · **Sort** · **Direction** · **Spotlight** — each a link-style dropdown |

```
Filters:  [pill] [pill] [pill]
          [Only Draft | Only Active | Draft + Active]   ← page-specific quick control
          Same status filter can be set in Customize View

                         View: Hierarchical collapsible ▾
                         Sort: Most Likely Date ▾
                         Direction: Ascending ▾
                         Spotlight: Goals overview ▾
```

## Left: filter pills (display-only)

- Label: muted `Filters:` (funnel icon optional).
- Pills: Bootstrap grey/secondary rounded pills (`badge rounded-pill text-bg-secondary` or equivalent muted grey)—**not** primary/info colored, **not** interactive (no ×, no dropdown on the pill).
- **Source of truth:** query params (what the filter engine actually received), not the header “for …” dropdown’s synthetic “Customized view” label.
- **Do not** emit a “Customized view” pill. Multi structural owners appear as **one pill per owner key**, each with a human name (company / department / team)—never raw ids.
- Every applied filter param that is not chrome (see skip list) should become one or more pills via a **display helper/class**.
- Empty state: if no filter params remain after skips, show a single muted pill or text like `None` / `All` (page may choose; Goals uses `All`).

### Display helper / class (required)

Each resource should expose something like `Goals::IndexFilterDisplay` (or a shared pattern) that:

1. **Accepts** the same filter inputs the index query uses (query params / filter hash the engine understands).
2. **Returns** an ordered list of human-readable pill labels (and optional stable keys for specs).
3. **Never** surfaces bare numeric ids or `Type_123` tokens in the UI.
4. Skips non-filter chrome params:

   `view`, `sort`, `direction`, `spotlight`, `page`, `controller`, `action`, `organization_id`, `id`, `return_url`, `return_text`, authenticity / form noise.

Multi-value params (`status[]`, `goal_type[]`, `owner_keys[]`) → **separate pill per value**, each labeled clearly (e.g. status values prefixed or worded so “Draft” isn’t confused with a person named Draft).

## Left: on-page quick filters + caption

Below the pills, keep **page-specific** controls that already live on the index (Goals: Draft / Active / Draft+Active button group). These are **not** the same as the grey pills—they are interactive presets.

Under that, keep the short caption that points at Customize View when relevant (Goals: “Same status filter can be set in Customize View”).

## Right: link-style dropdowns (View, Sort, Direction, Spotlight)

Same interaction as the Goals View switcher:

- Muted label (`View:` / `Sort:` / `Direction:` / `Spotlight:`) + underlined `btn-link` toggle showing the **current** human label.
- `dropdown-menu` (use `dropdown-menu-end` when right-aligned); `dropdown-item active` on the current value.
- Each option is a `link_to` that **preserves** other query params and changes only that one key (`view`, `sort`, `direction`, or `spotlight`).
- Optional `dropdown-header` groups when the option list is large (e.g. View style families).

**Sort** and **Direction** are separate lines (not combined into one control).

## Out of scope (unless product asks)

- Making grey filter pills interactive (dropdown or removable)—deferred; too many on-page filter surfaces already.
- Batch-migrating every index in one change.
- Replacing Customize View; footer switches are shortcuts for single-select chrome (view/sort/direction/spotlight).

## Checklist when upgrading another index

1. Read this doc + `docs/STYLES/index-pages.md` spotlight footer section.
2. Add or reuse a **FilterDisplay** helper/class for that resource’s query params → pill labels.
3. Rebuild spotlight `.card-footer`: left pills + existing on-page filters/caption; right View → Sort → Direction → Spotlight link-dropdowns.
4. Request spec: pills show human labels (no `Type_id`); each right-side control is a dropdown that changes only its param.
5. Leave other indexes alone until focused.
