# Object × Lens header actions (List / Show)

**Canonical list example:** Assignments index — `app/views/organizations/assignments/index.html.haml`.

**Cursor rule:** `.cursor/rules/object-lens-header-actions.mdc`.

When a page uses (or should use) `shared/object_lens_header/switchers`, keep the header cluster in this order:

1. **Object** dropdown  
2. **·**  
3. **Lens** dropdown (List / Health / Insights / Directory)  
4. **Page help** info icon (`shared/page_help/header_info_button`) — directly to the right of the lens  
5. **Primary action** — directly to the right of the info icon  

Pass (4) and (5) together via the switchers `trailing:` capture. Do **not** push the primary action to the far right with `justify-content-between` inside the header title column. Secondary chrome (Customize View, etc.) stays in `content_for :header_action`.

---

## List pages — plus button

- Control: primary `btn btn-primary` with `%i.bi.bi-plus` only (no text label on the button).
- Hover tooltip + `aria-label`: **`Add new {Object}`** using the **singular** object name.
  - Examples: `Add new Assignment`, `Add new Goal`, `Add new Observation`, `Add new Ability`
- Implement with Bootstrap tooltip:

```haml
= link_to new_path,
          class: "btn btn-primary",
          title: "Add new Assignment",
          "aria-label" => "Add new Assignment",
          data: { "bs-toggle" => "tooltip", "bs-placement" => "top" } do
  %i.bi.bi-plus
```

---

## Show pages — edit button

Same cluster as List, but the primary action is **Edit** instead of plus:

- Control: primary button that navigates to edit (icon and/or short label — match existing show chrome when migrating).
- Hover tooltip + `aria-label`: **`Edit {Object}`** (singular), e.g. `Edit Assignment`.

---

## Health / Insights lenses

Same trailing pattern for page help. Primary create/edit actions are usually List/Show only; do not invent a plus on Health/Insights unless the page already has a clear create affordance.

---

## Migrate when touching a page

If you edit a list or show view that still has:

- plus / edit separated from the title with `justify-content-between`, or  
- plus without `Add new {Object}` tooltip, or  
- page help not immediately after the lens / title  

…update it to this standard in the same change when practical.

Related: [page-help-pattern.md](../page-help-pattern.md), [object-lens-header-switchers-rollout-plan.md](object-lens-header-switchers-rollout-plan.md).
