# One Thing Priority Queue (1:1 Hub)

The **One Thing Priority Queue** is the carousel on a teammate’s **1:1 Hub**. It walks managers and employees through thirteen checks in a fixed order. The first item that **needs attention** is the recommended focus for the 1:1.

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
| 2 | Are there check-ins ready for review together? | Any position, assignment, or aspiration check-in is `ready_for_finalization` (both sides reflected; joint review not done) |
| 3 | Are any position, assignment, or aspiration clarity check-ins Warning (61+ days) or Needs Attention (90+ days / never)? | Any required clarity item is Warning or Needs Attention on Gruuv Health |
| 4 | Are any WTM assignments or aspirations missing active goals? | WTM rating without an active goal on that area |
| 5 | Are any current-position ability milestones below target missing active goals? | Ability gap on current position without a covering goal |
| 6 | Has the teammate given a published observation to someone else in 30 days? | None given |
| 7 | Has the teammate received a published observation in 30 days? | None received |
| 8 | Have all WTM assignments/aspirations received an observation in 30 days? | Any WTM area missing recent observation |
| 9 | Do all active goals have a confidence check for this week? | Any active goal missing this week’s confidence check |
| 10 | Does the teammate have at least one active goal? | Zero active goals |
| 11 | Are target-position ability milestones below target missing active goals? | Target-only ability gap without goal |
| 12 | Are there incomplete tasks in the linked Asana project? | Any incomplete tasks remain (N/A if not Asana-linked) |
| 13 | Are target-position-only required assignments missing active goals? | Target-only required assignment without goal |

Lower numbers win: only the **first** needs-attention item is “the one thing” on the hub and in the digest header.

## Implementation notes

- **Builder:** `OneOnOne::PriorityCarouselBuilder` — sets `reason` (explanation), `items` (structured bullets), and CTA fields per priority.
- **Renderer:** `OneOnOne::PriorityRenderer` — turns structured `items` into links/HTML, resolves primary-action URLs, and formats Slack copy.
- **Legacy `concrete_items`:** Deprecated for new work; prefer `items` + `data_kind`. Still supported in the carousel for older paths.

## Slack weekly digests (two separate messages)

When both are enabled, the employee and manager receive **two root messages** in the same group DM on the configured weekday.

### 1:1 guide digest

- **Main message:** Weekly 1:1 link, **Top 1:1 focus** (title + explanation + primary action), divider, action-item bullets for that top priority only, “time for your weekly 1:1” line.
- **Thread reply:** Count of priorities needing attention (of 13), then the **2nd and 3rd** needs-attention priorities (title + explanation + primary action each). No per-entity bullets in the thread.

### About Me reminder digest

- **Main message:** About Me summary (healthy / yellow / red section counts) with link to About Me.
- **Thread reply:** About Me section breakdown (healthy / yellow / red lists).

Both digests assume the **employee** is the audience for CTAs (e.g. “Start an observation”).

## Audit reference (needs attention)

| # | Explanation (P4 bar) | Entity/suggestion bullets | Primary CTA |
|---|----------------------|---------------------------|-------------|
| 1 | Yes | Asana tasks via `items` | Sync / open tasks |
| 2 | Yes | Aspirations → assignments → position (alpha within group) | Review N check-ins together (finalization) |
| 3 | Yes | Check-in links | Open top check-in |
| 4 | Yes | WTM areas | Check-in status |
| 5 | Yes (reference) | Abilities + add goal | Ability milestones |
| 6 | Yes | Suggestions or empty | Start observation |
| 7 | Yes | Suggestions or empty | Request feedback |
| 8 | Yes | WTM areas | Request feedback |
| 9 | Yes | Stale goals | Grow by goals |
| 10 | Yes | Empty when no goals | Create goals |
| 11 | Yes | Abilities + add goal | Ability milestones |
| 12 | Yes | Asana tasks | Open remaining / sync |
| 13 | Yes | Assignments + add goal | Grow by experiences |
