# Options Filter (search bar for long option lists)

Use the **options filter** on pages that show many selectable items (single select, multi-select checkboxes, or link cards). It adds a search bar that hides options whose visible text doesn’t match the search, using only the content already on the page—no extra APIs or markup beyond a few attributes and a class.

## When to use

- Lists of dozens of options (teammates, abilities, positions, etc.)
- Single-select (e.g. “pick one” links/cards) or multi-select (checkboxes)
- You want minimal change to the page: one wrapper, one input, one target on the list, and a class on each option

## How it works

- **Stimulus controller:** `options_filter_controller.js`
- **Behavior:** On input, it filters elements with class `filterable-option` (or a custom selector) inside the list container by matching their **text content** (case-insensitive). Non-matching options are hidden with `display: none`.

## How to add it to a page

### 1. Wrap the section

Wrap the search input and the options list in an element that has the controller:

```haml
.mb-3{ data: { controller: "options-filter" } }
  %input.form-control.form-control-lg.mb-3{ type: "search", placeholder: "Search ...", "data-options-filter-target": "input", "aria-label": "Filter options" }
  .your-list-container{ "data-options-filter-target": "list" }
    - @items.each do |item|
      %div.filterable-option
        -# option content (link, checkbox row, card, etc.)
```

### 2. Required pieces

| Piece | What to do |
|-------|------------|
| **Controller** | `data: { controller: "options-filter" }` on the wrapper (e.g. a `div`) |
| **Search input** | Any `<input type="search">` (or text) with `data-options-filter-target="input"`. Set `placeholder` and `aria-label` to match the page (e.g. “Filter teammates”). |
| **List container** | The element that wraps all options, with `data-options-filter-target="list"`. |
| **Each option** | Add the class `filterable-option` to the element that represents one option (the card, row, or label/checkbox wrapper). |

### 3. Optional: custom option selector

By default the controller looks for `.filterable-option` inside the list. To use a different selector (e.g. another class or a tag):

```haml
.mb-3{ data: { controller: "options-filter", options_filter_options_selector_value: ".my-option" } }
```

Then add the class (or selector) you set to each option element instead of `filterable-option`.

## Example: link cards (e.g. Select Teammate)

```haml
- if @eligible_teammates.any?
  .mb-3{ data: { controller: "options-filter" } }
    %input.form-control.form-control-lg.mb-3{ type: "search", placeholder: "Search teammates...", "data-options-filter-target": "input", "aria-label": "Filter teammates" }
    .teammate-columns{ "data-options-filter-target": "list" }
      - @eligible_teammates.each do |teammate|
        = link_to some_path(teammate), class: "card text-decoration-none h-100 filterable-option" do
          .card-body
            %h6= teammate.person.display_name
```

## Example: checkbox list

```haml
.mb-3{ data: { controller: "options-filter" } }
  %input.form-control.mb-3{ type: "search", placeholder: "Search...", "data-options-filter-target": "input", "aria-label": "Filter options" }
  .list-group{ "data-options-filter-target": "list" }
    - @items.each do |item|
      %label.list-group-item.filterable-option
        = check_box_tag "ids[]", item.id
        = item.name
```

## Where it’s used

- **Select Teammate:** `/organizations/:org/teammate_milestones/select_teammate` — filters teammate cards by name, manager, position.

When you add the filter to another page, add that page to this “Where it’s used” section so we can keep the list current.

## Implementation details

- **Controller:** `app/javascript/controllers/options_filter_controller.js`
- **Targets:** `input` (search field), `list` (container of options)
- **Value:** `optionsSelector` (default `".filterable-option"`) — CSS selector for each option node
- Filtering is client-side only; it shows/hides nodes based on `element.textContent` and does not touch the server or form values.
