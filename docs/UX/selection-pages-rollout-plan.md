# Selection pages toolbar — rollout plan

**Status:** Phase A complete. **In progress:** B (partial), C (partial), D (partial). One item per session; you test/deploy and approve before the next.

Execute **one page (or one shared template) per session**. After each change:

1. Agent implements the page using [selection-pages-toolbar.md](./selection-pages-toolbar.md)
2. You manually test and deploy
3. You explicitly approve moving to the next item

Do **not** batch multiple pages unless you ask for it.

**Pattern doc:** [selection-pages-toolbar.md](./selection-pages-toolbar.md)  
**Agent skill:** `.cursor/skills/selection-pages-toolbar/SKILL.md`

---

## Phase A — Document pattern ✅

- [x] Reference implementation: Manage Consumer Assignments (`/organizations/:organization_id/assignments/:assignment_id/consumer_assignments`)
- [x] UX doc + agent skill + this plan

---

## Phase B — Teammates

| # | Page (route) | View | Notes |
|---|--------------|------|-------|
| B1 | Manage Observees ✅ (`GET/PATCH …/observations/:id/manage_observees`) | `observations/manage_observees` | Done |
| B2 | Manage Team Members (`GET/PATCH …/teams/:team_id/manage_members`) | `teams/manage_members` | Add search + pills |
| B3 | Share Observation Privately (`GET …/observations/:id/share_privately`) | `observations/share_privately` | Some checkboxes disabled |
| B4 | Observation review — notify (`GET …/observations/:id/review`) | `observations/review` | `notify_teammate_ids[]` on review flow |

**Gate:** Your approval after B4 before Phase C.

---

## Phase C — Assignments

| # | Page (route) | View | Notes |
|---|--------------|------|-------|
| C1 | Add Assignments to Observation ✅ (`GET …/observations/:id/add_assignments`, `POST …/add_rateables`) | `observations/add_assignments` | Done |
| C2 | Teammate assignment selection (`GET/POST …/company_teammates/:id/assignment_selection`) | `company_teammates/assignment_selection` | Required/assigned rows disabled |
| C3 | People assignment selection (`GET/POST …/company_teammates/:id/assignment_selection`) | `people/assignment_selection` | Same route as C2 if still separate view |
| C4 | Associate Assignments — department (`GET/PATCH …/departments/:id/associate_assignments`) | `departments/associate_assignments` | Table + select-all |
| — | Manage Consumer Assignments ✅ (`GET/PATCH …/assignments/:id/consumer_assignments`) | `assignments/consumer_assignments/show` | Reference (pre–Phase A) |

**Gate:** Your approval after C4 before Phase D.

---

## Phase D — Abilities & aspirations

| # | Page (route) | View | Notes |
|---|--------------|------|-------|
| D1 | Add Abilities to Observation ✅ (`GET …/observations/:id/add_abilities`, `POST …/add_rateables`) | `observations/add_abilities` | Done |
| D2 | Add Aspirations to Observation ✅ (`GET …/observations/:id/add_aspirations`, `POST …/add_rateables`) | `observations/add_aspirations` | Done |
| D3 | Associate Abilities — department (`GET/PATCH …/departments/:id/associate_abilities`) | `departments/associate_abilities` | |
| D4 | Associate Aspirations — department (`GET/PATCH …/departments/:id/associate_aspirations`) | `departments/associate_aspirations` | |

**Gate:** Your approval after D4 before Phase E.

---

## Phase E — Goals

| # | Page (route) | View | Notes |
|---|--------------|------|-------|
| E1 | Associate existing goals — shared (`GET/POST …/assignments\|abilities\|aspirations/:id/associate_existing_goals`) | `shared/associable_goals/associate_existing_goals` | High leverage; polymorphic entry |
| E2 | Associate existing goals — prompt (`GET/POST …/prompts/:id/associate_existing_goals`) | `prompts/associate_existing_goals` | Align with E1 |
| E3 | Goal links — incoming (`GET/POST …/goals/:goal_id/goal_links/associate_existing_incoming`) | `goal_links/associate_existing_incoming` | |
| E4 | Goal links — outgoing (`GET/POST …/goals/:goal_id/goal_links/associate_existing_outgoing`) | `goal_links/associate_existing_outgoing` | |

**Not in scope:** Create new goals (`…/manage_goals`) — bulk create, not pick-from-list.

**Gate:** Your approval after E4 before Phase F.

---

## Phase F — Edge cases

| # | Page (route) | View | Notes |
|---|--------------|------|-------|
| F1 | Select Focus — feedback request (`GET/PATCH …/feedback_requests/:id/select_focus`) | `feedback_requests/select_focus` | Three sections; toolbar design TBD |
| F2 | Acknowledge check-ins — audit (`GET/PATCH …/employees/:id/audit`) | `employees/audit` | Snapshot multi-select |
| F3 | Associate Titles — department (`GET/PATCH …/departments/:id/associate_titles`) | `departments/associate_titles` | Lower priority |
| F4 | Review feedback extractions (`GET …/possible_observation_transcripts/:id/review_feedback_requests`) | `possible_observation_transcripts/review_feedback_requests` | |

**Gate:** Your approval after F4; plan complete unless new pages are added.

---

## Route prefix

Unless noted otherwise, paths are under:

`/organizations/:organization_id`

Observation overlay pages use `…/observations/:id/…`. `add_rateables` is `POST …/observations/:id/add_rateables` (shared by add assignments, abilities, aspirations).

---

## Explicitly out of scope

| Area | Reason |
|------|--------|
| Customize view pages | Filter preferences, not entity selection |
| Bulk sync index / show | Import review tables |
| Select teammate / select ability (milestones) | Single-select or row actions |
| Position manage assignments (`…/positions/:id/manage_assignments`) | Per-row energy fields |
| Assignment ability milestones (`…/assignments/:id/ability_milestones`) | Radio per ability |

---

## How to start the next item

Tell the agent which **item ID** to do (e.g. “Do B2”). The agent implements **only that item**, runs request specs, and stops for your review.
