# Object × Lens header switchers — rollout plan

**Status:** Phase 2 complete (Observations, Check-ins, Abilities wired). Health domain switchers kept. Gate: manual test full v1 matrix; approve before Phase 3.

**Pattern:** Two H1-style dropdowns in `content_for :header` (same interaction as `shared/teammate_context/title_dropdown`):

1. **Object** — which domain (noun)
2. **Lens** — how you look at it (List / Health / Insights)

Changing one axis preserves the other when a destination exists; otherwise fall back Insights → List → first available.

**Related:** Replaces ad-hoc “View Analytics” / Health “Other actions” / Health domain btn-group for pages in this matrix. Does **not** replace teammate `title_dropdown` or `people/view_switcher`.

**Trailing actions (locked):** After the lens dropdown → page-help info icon → List plus (`Add new {Object}` tooltip) or Show edit (`Edit {Object}` tooltip). Spec: [object-lens-header-actions.md](object-lens-header-actions.md).

---

## Locked menus (v1)

### Object dropdown

| # | Label | Notes |
|---|-------|-------|
| 1 | **Overall** | Rollup row |
| — | *divider* | |
| 2 | **Goals** | |
| 3 | **Observations** | |
| 4 | **Check-ins** | |
| 5 | **Abilities** | Health → Milestones Health |
| — | *divider* | Person-scoped objects above; org catalog below |
| 6 | **Assignments** | Health → Expectation Alignment; not person-specific |

### Lens dropdown

Show only lenses that exist for the current object (no disabled stubs).

| Label | When | Meaning |
|-------|------|---------|
| **Directory** | Object = **Overall** only | Sitemap — browse every reachable page |
| **List** | Typed objects | Browse / act on records |
| **Health** | When a Health page exists | Who needs attention now |
| **Insights** | When an Insights page exists | Trends / scoreboard over time |

For typed objects the first lens stays **List**. For Overall it is labeled **Directory** (same slot, honest name).

### Object × Lens → destination (v1)

| Object | Directory / List | Health | Insights |
|--------|------------------|--------|----------|
| **Overall** | Sitemap (**Directory**) | Protect Flow | OG Scorecard |
| **Goals** | All Goals (`/goals`) | Goals Health | Insights: Goals |
| **Observations** | All observations | Observations Health | Insights: Observations |
| **Check-ins** | Own clarity check-in hub (`…/company_teammates/:me/check_ins`) | Check-ins Health | Check-ins Progress |
| **Abilities** | Milestones & Abilities | Milestones Health | Insights: Abilities |
| **Assignments** | Assignments index | Assignments Health | Insights: Assignments |

Closed header reads like: `Overall · Directory`, `Overall · Health`, `Goals · List`, `Check-ins · List`, `Abilities · Insights`, `Assignments · Health`.

---

## Phase 0 — Spec & shared partial ✅ (design)

- [x] Agree Object set: Overall + Goals, Observations, Check-ins, Abilities
- [x] Agree Overall ultimates: Sitemap / Protect Flow / OG Scorecard
- [x] Overall first lens labeled **Directory** (→ Sitemap)
- [x] Check-ins · List → viewer’s own clarity check-in hub
- [x] This rollout plan

---

## Phase 1 — Shared chrome + Overall + Goals (pilot)

Ship the dual header on the smallest useful matrix, prove preserve-lens navigation.

| # | Work | Notes |
|---|------|-------|
| 1.1 | Shared partial(s) + helper ✅ | `ObjectLensHeaderHelper` + `shared/object_lens_header/_switchers` |
| 1.2 | Wire **Overall** triad ✅ | Sitemap, Protect Flow, OG Scorecard |
| 1.3 | Wire **Goals** triad ✅ | Goals index, Goals Health, Goals Insights |
| 1.4 | Remove Goals-local ad-hoc cross-links ✅ | Insights outline buttons; Health “My goals” / Insights other-actions |
| 1.5 | Drop Health domain btn-group on Goals Health (+ Protect Flow) ✅ | `show_switcher: false` on Goals Health; removed switcher from Protect Flow |

**Gate:** Manual test Overall ↔ Goals across all three lenses; approve before Phase 2.

---

## Phase 2 — Observations, Check-ins, Abilities

| # | Object | Pages to wire |
|---|--------|----------------|
| 2.1 | Observations ✅ | Index, Observations Health, Observations Insights |
| 2.2 | Check-ins ✅ | Own clarity check-in hub (List), Check-ins Health, Check-ins Progress |
| 2.3 | Abilities ✅ | Abilities index, Milestones Health, Abilities Insights |
| 2.4 | Cleanup (partial) ✅ | Removed Insights-duplicate Other actions / View Analytics / Milestones Health outline btn. **Health domain switchers kept.** |

**Gate:** Full v1 matrix works; main Insights nav can stay as alternate entry.

---

## Phase 3 — Assignments ✅

List + Health + Insights.

| Object | List | Health | Insights |
|--------|------|--------|----------|
| **Assignments** | Assignments index | Assignments Health (Expectation Alignment) | Insights: Assignments |

- [x] Add Assignments to Object menu (after Abilities)
- [x] Wire dual header on List, Health, Insights
- [x] Remove “View Analytics” on Assignments index (lens covers it)
- [x] Assignments · Health v1: distribution, 10 best/worst, refresh missing & stale

**Gate:** Approve before Phase 4.

---

## Phase 4 — Feedback requests & Prompts

List + Insights only.

| Object | List | Health | Insights |
|--------|------|--------|----------|
| **Feedback requests** | Feedback requests list (org / my — pick canonical List) | — | Insights: Feedback Requests |
| **Prompts** | My Growth Plans / prompts index | — | Insights: Prompts |

**Gate:** Approve before Phase 5.

---

## Phase 5 — Values

| Object | List | Health | Insights |
|--------|------|--------|----------|
| **Values** | Aspirational Values (admin list) | — | Insights: Values |

**Note:** List is config-ish; confirm product comfort before shipping.

**Gate:** Approve before Phase 6.

---

## Phase 6 — Seats, Titles & Positions (needs product call)

One Object row, awkward List (three indexes, one Insights page).

| Option | Approach |
|--------|----------|
| **A** | Object label **Seats & titles**; List → Seats index (or Titles); Insights → Seats, Titles, Positions |
| **B** | Three Object rows (Seats / Titles / Positions); each List → own index; all three Insights → same combined page |
| **C** | Insights only in hub; never add to Object menu |

Default recommendation: **A** or **C**. Do not start until A/B/C chosen.

---

## Explicitly out of scope (no phase)

These stay in main nav / Insights hub / teammate chrome only:

- Who is doing what
- OG Consultations Insights
- Acknowledgements / Acknowledgement nudges
- Insights hub (meta)
- Start Here, GSD, Search, OG Academy
- Teammate pages / `people/view_switcher`
- Kudos Points Center
- Huddles (unless later given a real triad)

---

## Fallback when lens missing

Prefer **Insights → List → first available** for the newly selected object.

Example: on Goals · Health, switch Object → Assignments → Assignments · Health (or Insights / List if Health were unavailable).
