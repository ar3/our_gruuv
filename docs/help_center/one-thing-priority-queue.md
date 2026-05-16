# One Thing Priority Queue (1:1 Hub)

The **One Thing Priority Queue** is the carousel on a teammate’s **1:1 Hub**. It walks managers and employees through twelve checks in a fixed order. The first item that **needs attention** is the recommended focus for the 1:1.

## Needs-attention card structure

Every priority in **needs attention** mode should present three parts:

1. **Explanation** — Why this matters for the 1:1 and what kind of action closes it (not only a symptom).
2. **Action items** — A bulleted list of specific entities (assignments, abilities, goals, Asana tasks, etc.) or rich suggestion copy (e.g. feedback opportunities). No generic advice bullets.
3. **Primary action** — One primary button linking to the best place to start (hub section, check-ins, goals, observation flow, etc.).

**All set** and **N/A** states are documented separately; this guide focuses on needs attention.

## Priority stack (highest first)

| # | Question | Needs attention when |
|---|----------|----------------------|
| 1 | Are there overdue or due-soon Asana tasks? | Asana 1:1 project has urgent incomplete tasks (N/A if not Asana-linked) |
| 2 | Are any position, assignment, or aspiration check-ins blurred (check-in 60+ days old) or obscured (check-in 90+ days old)? | Any required check-in is blurred or obscured |
| 3 | Are any WTM assignments or aspirations missing active goals? | WTM rating without an active goal on that area |
| 4 | Are any current-position ability milestones below target missing active goals? | Ability gap on current position without a covering goal |
| 5 | Has the teammate given a published observation to someone else in 30 days? | None given |
| 6 | Has the teammate received a published observation in 30 days? | None received |
| 7 | Have all WTM assignments/aspirations received an observation in 30 days? | Any WTM area missing recent observation |
| 8 | Do all active goals have a check-in for this week? | Any active goal missing this week’s check-in |
| 9 | Does the teammate have at least one active goal? | Zero active goals |
| 10 | Are target-position ability milestones below target missing active goals? | Target-only ability gap without goal |
| 11 | Are there incomplete tasks in the linked Asana project? | Any incomplete tasks remain (N/A if not Asana-linked) |
| 12 | Are target-position-only required assignments missing active goals? | Target-only required assignment without goal |

Lower numbers win: only the **first** needs-attention item is “the one thing” on the hub and in the digest header.

## Implementation notes

- **Builder:** `OneOnOne::PriorityCarouselBuilder` — sets `reason` (explanation), `items` (structured bullets), and CTA fields per priority.
- **Renderer:** `OneOnOne::PriorityRenderer` — turns structured `items` into links/HTML, resolves primary-action URLs, and formats Slack copy.
- **Legacy `concrete_items`:** Deprecated for new work; prefer `items` + `data_kind`. Still supported in the carousel for older paths.

## Slack About Me digest

- **Main message:** Weekly 1:1 header, **Top 1:1 focus** (title + explanation + primary action link), divider, bullet list for that top priority, divider, About Me summary.
- **First thread reply:** All needs-attention priorities (title + explanation + primary action each), separated clearly. No per-entity bullets in this thread.
- **Second thread reply:** About Me section breakdown (healthy / yellow / red), unchanged.

Digest assumes the **employee** is the audience for CTAs (e.g. “Start an observation”).

## Audit reference (needs attention)

| # | Explanation (P4 bar) | Entity/suggestion bullets | Primary CTA |
|---|----------------------|---------------------------|-------------|
| 1 | Yes (after copy pass) | Asana tasks via `items` | Sync / open tasks |
| 2 | Yes | Check-in links | Open top check-in |
| 3 | Yes | WTM areas | Check-in status |
| 4 | Yes (reference) | Abilities + add goal | Ability milestones |
| 5 | Yes | Suggestions or empty | Start observation |
| 6 | Yes | Suggestions or empty | Request feedback |
| 7 | Yes | WTM areas | Request feedback |
| 8 | Yes | Stale goals | Grow by goals |
| 9 | Yes | Empty when no goals | Create goals |
| 10 | Yes | Abilities + add goal | Ability milestones |
| 11 | Yes | Asana tasks | Open remaining / sync |
| 12 | Yes | Assignments + add goal | Grow by experiences |
