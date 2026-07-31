# New assignment grace — UI brief

**Status:** Classification shipped; UI shipped (grey EH segments, popovers, Overview last-event, page help).  
**Related cache flag:** `inputs["new_assignment_grace"]` on Required Clarity **Assignment** item rows (also `tenure_chain_started_at`, `days_since_tenure_chain_start`, `new_assignment_grace_within_days`).

## Problem

A teammate who just started an assignment has no finalized check-in yet. Under the old rule that was **Needs Attention** immediately — false red on health bars, unfair rollups, and early nudges.

## Classification (already shipped)

| Condition | Status |
|---|---|
| Assignment, no finalize, consecutive &gt;0% tenure age **&lt; 60 days** | **Warning** + `new_assignment_grace: true` |
| Same, tenure age **≥ 60 days**, still no finalize | **Needs Attention** (`new_assignment_grace: false`) |
| Any finalized check-in | Normal 60/90 windows; grace keys omitted |

- **Assignments only** (Position / Aspirations unchanged).
- Tenure clock = start of consecutive **&gt;0%** energy chain; **calendar gap** resets; **0%** tenures excluded.
- Numbers / rollups / Up Next / One Thing / scorecard stay in the three-state vocabulary: these items count as **Warning**.

## Goal of the UI

1. At a glance on Check-ins Health, show how much of a team’s assignment bar is **new / not due yet** (grey), vs stale Warning (yellow) vs overdue Needs Attention (red).
2. On hover / drill-down, explain *why* so Warning doesn’t read as “already behind.”
3. Don’t invent a fourth Engagement Health status for calculations.

---

## In scope

### 1. Check-ins Health — grey EH bar segment (primary glance signal)

**Where:** Check-ins Health employee rows, **Assignments** column, **top** (EH) bar only.

**Behavior:**
- When `inputs["new_assignment_grace"] == true`, render the EH segment with a **distinct grey** class (not yellow Warning, not red NA).
- Stacked / by-manager assignment bars that aggregate EH statuses should expose grace as its own segment (or split Warning into “grace grey” vs “real Warning yellow”) so managers can see **how much of the bar is new assignments**.
- **Bottom action bar** stays as today (Warning → orange when no progress). Optional later: softer treatment; not required for v1 UI.

**Suggested CSS:** new class e.g. `check-in-health-eh-new-assignment-grace` (neutral grey, readable with initials). Reuse patterns near existing `.check-in-health-eh-*` / anomaly gray — do not reuse yellow/red.

**Counting:** Segment still represents a Warning **status** in EH data; grey is **display-only** driven by the cache flag.

### 2. Check-ins Health — segment popover

**Where:** Hover/focus popover on the grey (and any) assignment EH segment.

**Copy direction (finalize in implementation):**
- Status line can still say Warning (true classification), plus a clear grace line, e.g.  
  **New assignment — first check-in not due yet (day N of 60)**  
  using `days_since_tenure_chain_start` and `new_assignment_grace_within_days`.
- Avoid implying Healthy or “all clear”; the point is “not overdue yet.”

### 3. 1:1 Hub Overview — Required Clarity last-event row

**Where:** Overview engagement-health item list for assignments.

**Problem today:** Never-finalized shows a red **Never** badge even when status is Warning under grace.

**Behavior:**
- If `new_assignment_grace`, replace danger **Never** with a neutral treatment, e.g. badge/text **New — no check-in yet** (or “Grace · day N of 60”), not `text-bg-danger`.
- Status badge remains **Warning** (three-state honesty).
- Non-grace never stays red **Never**.

### 4. Page help / legend

**Check-ins Health** (`_page_help`): under how-to-read / color legend, add grey = new assignment (first 60 days, no finalize yet); still counted as Warning in rollups.

**1:1 Hub Overview** help: already documents the classification exception; add a one-liner that Overview may show “New — no check-in yet” instead of red Never during grace, and that Check-ins Health uses grey on the bar.

---

## Out of scope (this brief)

- Changing EH status enum or treating grace as anything other than Warning in calculations.
- Grey (or special labels) on Position / Aspiration / Goals / OGOs / Milestones.
- Changing Up Next / One Thing / Protect Flow urgency ranking (they correctly see Warning).
- Scorecard / CSV vocabulary changes (remain Healthy / Warning / Needs Attention).
- Softening action-bar orange for grace (optional follow-up).
- Employee check-in flow “new assignment” education beyond EH surfaces.

---

## Design rules

- **Three states in data; four looks on the Assignments EH bar:** green / yellow / **grey (grace)** / red.
- Grey must be visually distinct from empty/missing segments and from action-bar anomaly gray if those coexist on the same page.
- Prefer reading `new_assignment_grace` from cached `inputs` — do not re-query tenure chains in views.
- By-manager / stacked assignment summaries: grey share should be visible; tooltips should name “new assignments” vs “Warning” vs “Needs Attention.”

---

## Acceptance checks

- [x] New assignment (&lt; 60 days, no finalize) → grey segment on Check-ins Health Assignments EH bar.
- [x] Same item → popover explains grace with day N of 60.
- [x] Same item → Overview shows Warning + non-danger “new / no check-in” last-event treatment (not red Never).
- [x] Day 60+ still never finalize → red EH segment, Needs Attention, red Never (no grey, no grace copy).
- [x] After first finalize → normal green/yellow/red; no grace UI.
- [x] Spotlight / rollup **counts** still bucket grace items as Warning (grey is display-only).
- [x] Page help legend includes grey.

---

## Implementation sketch (for builders)

| Area | Likely touchpoints |
|---|---|
| Bar CSS | `application.bootstrap.scss` (`.check-in-health-eh-*`) |
| Segment building | `CheckInsHealthBarsHelper` (+ stacked/by-manager helpers that map status → CSS) |
| Popover | `check_ins_health_bar_popover_html` / healthy vs workflow bodies |
| Overview last event | `Organizations::OneOnOneLinksHelper#engagement_health_last_event_display` |
| Help | `check_ins_health/_page_help`, Overview help if needed |
| Specs | bars helper / request specs for check-ins health + Overview |

**Ship order suggestion:** (1) grey segment + popover on Check-ins Health, (2) Overview Never treatment, (3) page-help legend — all in one PR if small enough.
