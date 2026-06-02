# Selection pages toolbar — rollout plan

**Status:** Phase A complete (pattern documented). **Phases B–F are not started.**

Execute **one page (or one shared template) per session**. After each change:

1. Agent implements the page using [selection-pages-toolbar.md](./selection-pages-toolbar.md)
2. You manually test and deploy
3. You explicitly approve moving to the next item

Do **not** batch multiple pages unless you ask for it.

**Pattern doc:** [selection-pages-toolbar.md](./selection-pages-toolbar.md)  
**Agent skill:** `.cursor/skills/selection-pages-toolbar/SKILL.md`

---

## Phase A — Document pattern ✅

- [x] Reference implementation: Manage Consumer Assignments
- [x] UX doc + agent skill + this plan

---

## Phase B — Teammates

| # | Page | View | Route (approx.) | Notes |
|---|------|------|-----------------|-------|
| B1 | Manage Observees ✅ | `observations/manage_observees` | `manage_observees_organization_observation_path` | Done |
| B2 | Manage Team Members | `teams/manage_members` | `update_members` on team | Save top/bottom today; add search + pills |
| B3 | Share Observation Privately | `observations/share_privately` | notify teammates on observation | Some checkboxes disabled |
| B4 | Observation review — notify | `observations/review` | `notify_teammate_ids[]` | Part of review flow |

**Gate:** Your approval after B4 before Phase C.

---

## Phase C — Assignments

| # | Page | View | Notes |
|---|------|------|-------|
| C1 | Add Assignments to Observation ✅ | `observations/add_assignments` | Done |
| C2 | Teammate assignment selection | `company_teammates/assignment_selection` | Table; required/assigned rows disabled — pills only for changeable rows |
| C3 | People assignment selection | `people/assignment_selection` | Mirror C2 if still separate |
| C4 | Associate Assignments (department) | `departments/associate_assignments` | Table + select-all; consider keeping bulk-select |

**Gate:** Your approval after C4 before Phase D.

---

## Phase D — Abilities & aspirations

| # | Page | View | Notes |
|---|------|------|-------|
| D1 | Add Abilities to Observation ✅ | `observations/add_abilities` | Done |
| D2 | Add Aspirations to Observation | `observations/add_aspirations` | Same shape as C1 |
| D3 | Associate Abilities (department) | `departments/associate_abilities` | |
| D4 | Associate Aspirations (department) | `departments/associate_aspirations` | |

**Gate:** Your approval after D4 before Phase E.

---

## Phase E — Goals

| # | Page | View | Notes |
|---|------|------|-------|
| E1 | Associate existing goals (shared) | `shared/associable_goals/associate_existing_goals` | **High leverage** — many associable entry points |
| E2 | Associate existing goals (prompt) | `prompts/associate_existing_goals` | Align with E1 / extract shared partial if duplicated |
| E3 | Goal links — incoming | `goal_links/associate_existing_incoming` | |
| E4 | Goal links — outgoing | `goal_links/associate_existing_outgoing` | |

**Not in scope:** `shared/associable_goals/manage_goals` (bulk create, not pick-from-list).

**Gate:** Your approval after E4 before Phase F.

---

## Phase F — Edge cases

| # | Page | View | Notes |
|---|------|------|-------|
| F1 | Select Focus (feedback request) | `feedback_requests/select_focus` | Three checkbox sections — decide: toolbar per card vs one combined |
| F2 | Acknowledge check-ins (audit) | `employees/audit` | Snapshot multi-select; primary action may differ from “Save” label |
| F3 | Associate Titles (department) | `departments/associate_titles` | Lower priority |
| F4 | Review feedback extractions | `possible_observation_transcripts/review_feedback_requests` | |

**Gate:** Your approval after F4; plan complete unless new pages are added.

---

## Explicitly out of scope

| Area | Reason |
|------|--------|
| Customize view pages (observations, employees, goals, seats, abilities, assignments) | Filter preferences, not entity selection |
| Bulk sync index / show | Import review tables, not selection toolbar UX |
| Select teammate / select ability (milestones) | Single-select or row actions, not checkbox multi-select |
| Position manage assignments | Per-row energy fields |
| Assignment ability milestones | Radio per ability, not multi-select list |

---

## How to start the next phase

Tell the agent which **item ID** to do (e.g. “Do B1” or “Phase B, Manage Observees”). The agent should read the pattern doc and skill, implement **only that item**, run relevant request specs, and stop for your review.
