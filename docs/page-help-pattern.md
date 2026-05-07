# Page Help Pattern (Header Info Icon + Expandable Explainer)

Use this pattern when a page has dense or stateful UI and users benefit from in-context guidance.

## UX Contract

- Show an info icon directly to the right of the page title.
- On hover: show a short tooltip that explains purpose and says click for details.
- On click: expand/collapse a hidden full-width alert below the header.
- Keep help page-specific and practical.

## Authoring Checklist

- [ ] One-sentence **ultimate goal** at the top.
- [ ] "How to read this page" section with plain language.
- [ ] Concrete **example block** (mini table/card/row) that mirrors real UI.
- [ ] State legend(s) with visual color markers matching production colors.
- [ ] Guidance for action controls (refresh/recompute), including when not to use them.
- [ ] Tooltip + expand interaction present and accessible (`aria-controls`, `aria-expanded`, label).

## Suggested Structure (Expanded Alert)

1. **Ultimate goal**: what success looks like for this page.
2. **How to read this page**: interpretation of primary UI indicators.
3. **Example**: realistic mini sample + short callouts.
4. **State legend**:
   - Primary status colors and meanings.
   - Secondary/recency colors and meanings (if applicable).
5. **Operational note**: when to use refresh/manual actions.

## Copy Template

### Tooltip

`Quickly understand what needs attention on this page. Click for a full breakdown.`

### Expanded alert opening

- **Ultimate goal:** `<goal sentence>`
- **How to read this page:** `<one or two sentences>`
- **Example:** `<short interpretation sentence>`

### State line format

- `<color dot> <State name> - <why it appears / what it means>`

## Example Interpretation Pattern

- "If top status is `<state A>` and recency is `<state B>`, this usually means `<actionable interpretation>`."

## Notes for Reuse Across Pages

- Keep the interaction pattern constant (icon + tooltip + click-expand).
- Adapt only the content: examples, states, and action guidance should reflect the current page.
- Prefer short, skimmable sections over long prose.
