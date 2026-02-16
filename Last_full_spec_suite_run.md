# Last Full Spec Suite Run

## Run Information
- **Run Date**: 2026-02-16
- **Started**: 2026-02-16 11:55:06
- **Last Update**: (updated after each segment)
- **Total Duration**: Segments run separately; doc updated after each segment.

## Segment Results

### ✅ Phase 1: Model Specs (1794/1794 passing, 1 pending)
**Command**: `bundle exec rspec spec/models/`
- **Examples**: 1794
- **Failures**: 0 ✅
- **Pending**: 1
- **Status**: ALL PASSING
- **Duration**: ~50 seconds (50.15s)
- **Completed**: 2026-02-16 11:56:00

### ❌ Phase 2: Controller Specs (1474/1477 passing, 6 pending, 3 failures)
**Command**: `bundle exec rspec spec/controllers/`
- **Examples**: 1477
- **Failures**: 3 ❌
- **Pending**: 6
- **Status**: 3 FAILURES
- **Duration**: ~2 minutes 9 seconds (2m 8.8s)
- **Completed**: 2026-02-16 11:58:10
- **Failures**: insights_controller_spec.rb:237 (observations chart 52–53 categories, got 54); :319 (prompts chart same); :196 (goals total_goals expected 2 got nil)

### ❌ Phase 3: Request Specs (1486/1488 passing, 3 pending, 2 failures)
**Command**: `bundle exec rspec spec/requests/`
- **Examples**: 1488
- **Failures**: 2 ❌
- **Pending**: 3
- **Status**: 2 FAILURES
- **Duration**: ~3 minutes 9 seconds (3m 8.7s)
- **Completed**: 2026-02-16 12:01:20
- **Failures**: prompt_templates_spec.rb:17 and :22 — GET prompt_templates returns 302 redirect instead of success, does not render index

### ❌ Phase 4: Policy Specs (593/595 passing, 2 failures)
**Command**: `bundle exec rspec spec/policies/`
- **Examples**: 595
- **Failures**: 2 ❌
- **Status**: 2 FAILURES
- **Duration**: ~49 seconds (48.87s)
- **Completed**: 2026-02-16 12:02:10
- **Failures**: assignment_flow_policy_spec.rb:83 (deadlock creating organization); prompt_goal_policy_spec.rb:47 (create? expected true got false)

### ✅ Phase 5: Service Specs (1067/1067 passing, 4 pending)
**Command**: `bundle exec rspec spec/services/`
- **Examples**: 1067
- **Failures**: 0 ✅
- **Pending**: 4
- **Status**: ALL PASSING
- **Duration**: ~1 minute (60.29s)
- **Completed**: 2026-02-16 12:03:10

### ✅ Phase 6: Job Specs (156/156 passing)
**Command**: `bundle exec rspec spec/jobs/`
- **Examples**: 156
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~15 seconds (15.29s)
- **Completed**: 2026-02-16 12:03:26

### ✅ Phase 7: Helper Specs (367/367 passing)
**Command**: `bundle exec rspec spec/helpers/`
- **Examples**: 367
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~22 seconds (22.14s)
- **Completed**: 2026-02-16 12:03:48

### ✅ Phase 8: Form Specs (172/172 passing)
**Command**: `bundle exec rspec spec/forms/`
- **Examples**: 172
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~17 seconds (17.1s)
- **Completed**: 2026-02-16 12:04:15

### ✅ Phase 9: Decorator Specs (99/99 passing)
**Command**: `bundle exec rspec spec/decorators/`
- **Examples**: 99
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~12 seconds (11.56s)
- **Completed**: 2026-02-16 12:04:27

### ✅ Phase 10: Query Specs (338/338 passing)
**Command**: `bundle exec rspec spec/queries/`
- **Examples**: 338
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~1m 13s (72.79s)
- **Completed**: 2026-02-16 12:05:40

### ✅ Phase 11: Integration Specs (9/9 passing)
**Command**: `bundle exec rspec spec/integrations/`
- **Examples**: 9
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~4.6 seconds
- **Completed**: 2026-02-16 12:06:24

### ✅ Phase 12: Route Specs (46/46 passing)
**Command**: `bundle exec rspec spec/routes/`
- **Examples**: 46
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~4.5 seconds
- **Completed**: 2026-02-16 12:06:09

### ❌ Phase 13: View Specs (139/142 passing, 3 failures)
**Command**: `bundle exec rspec spec/views/`
- **Examples**: 142
- **Failures**: 3 ❌
- **Status**: 3 FAILURES (deadlocks)
- **Duration**: ~38 seconds (37.76s)
- **Completed**: 2026-02-16 12:06:58
- **Failures**: organizations/kudos/index.html.haml_spec.rb — 3 deadlocks (link display, truncates long stories, does not include GIFs)

---

## System Specs (each folder/file run separately)

### ✅ System: Abilities (2/2 passing)
**Command**: `bundle exec rspec spec/system/abilities/`
- **Examples**: 2
- **Failures**: 0 ✅
- **Duration**: ~14 seconds (13.83s)
- **Completed**: 2026-02-16 12:08:15

### ✅ System: Aspirations (7/7 passing, 5 pending)
**Command**: `bundle exec rspec spec/system/aspirations/`
- **Examples**: 7
- **Failures**: 0 ✅
- **Pending**: 5
- **Duration**: ~13 seconds (13.47s)
- **Completed**: 2026-02-16 12:08:38

### ❌ System: Assignments (1/2 passing, 1 failure)
**Command**: `bundle exec rspec spec/system/assignments/`
- **Examples**: 2
- **Failures**: 1 ❌
- **Duration**: ~12 seconds (11.54s)
- **Completed**: 2026-02-16 12:08:59
- **Failure**: assignments_core_flow_spec.rb:17 — duplicate key organizations_pkey (department factory)

### ✅ System: Audit (3/3 passing, 3 pending)
**Command**: `bundle exec rspec spec/system/audit/`
- **Examples**: 3
- **Failures**: 0 ✅
- **Pending**: 3
- **Duration**: ~1.9 seconds
- **Completed**: 2026-02-16 12:09:10

### ❌ System: Check-in Observations (0/1 passing, 1 failure)
**Command**: `bundle exec rspec spec/system/check_in_observations/`
- **Examples**: 1
- **Failures**: 1 ❌
- **Duration**: ~10 seconds (9.6s)
- **Completed**: 2026-02-16 12:09:30
- **Failure**: check_in_observations_flow_spec.rb:23 — deadlock (create organization)

### ❌ System: Check-ins (13/14 passing, 1 failure, 13 pending)
**Command**: `bundle exec rspec spec/system/check_ins/`
- **Examples**: 14
- **Failures**: 1 ❌
- **Pending**: 13
- **Duration**: ~14 seconds (13.82s)
- **Completed**: 2026-02-16 12:09:54
- **Failure**: check_ins_complete_flow_spec.rb:43 — duplicate key organizations_pkey

### ❌ System: check_ins_save_and_redirect_spec.rb (0/2 passing, 1 failure)
**Command**: `bundle exec rspec spec/system/check_ins_save_and_redirect_spec.rb`
- **Examples**: 2
- **Failures**: 1 ❌
- **Duration**: ~35s
- **Completed**: 2026-02-16 12:19:55
- **Failure**: deadlock (position_check_ins insert)

### ❌ System: Finalization (2/3 passing, 1 failure)
**Command**: `bundle exec rspec spec/system/finalization/`
- **Examples**: 3
- **Failures**: 1 ❌
- **Duration**: ~21 seconds (20.59s)
- **Completed**: 2026-02-16 12:10:24
- **Failure**: finalization_complete_flow_spec.rb:145 — deadlock (create organization)

### ✅ System: Get Shit Done (1/1 passing)
**Command**: `bundle exec rspec spec/system/get_shit_done/`
- **Examples**: 1
- **Failures**: 0 ✅
- **Duration**: ~14 seconds (14.28s)
- **Completed**: 2026-02-16 12:10:48

### ✅ System: Goals (58/58 passing, 7 pending)
**Command**: `bundle exec rspec spec/system/goals/`
- **Examples**: 58
- **Failures**: 0 ✅
- **Pending**: 7
- **Duration**: ~2m 2s (2m 1.7s)
- **Completed**: 2026-02-16 12:12:56

### ✅ System: Huddles (6/6 passing, 1 pending)
**Command**: `bundle exec rspec spec/system/huddles/`
- **Examples**: 6
- **Failures**: 0 ✅
- **Pending**: 1
- **Duration**: ~29 seconds (28.53s)
- **Completed**: 2026-02-16 12:13:26

### ❌ System: Misc (12/21 passing, 9 failures)
**Command**: `bundle exec rspec spec/system/misc/`
- **Examples**: 21
- **Failures**: 9 ❌
- **Duration**: ~2m 40s
- **Completed**: 2026-02-16 12:14:38
- **Failures**: deadlocks (Dashboard redirect, Timezone); Slack — "Manage Channel & Group Associations" not shown (permission), field not found, tr[data-organization-id] not found

### ❌ System: Observable Moments (5/7 passing, 2 failures, 4 pending)
**Command**: `bundle exec rspec spec/system/observable_moments/`
- **Examples**: 7
- **Failures**: 2 ❌
- **Pending**: 4
- **Duration**: ~27 seconds (26.72s)
- **Completed**: 2026-02-16 12:15:05
- **Failures**: goal_check_in_moment_flow (deadlock); check_in_moment_flow (pg_search_documents_pkey)

### ❌ System: Observations (42/48 passing, 6 failures)
**Command**: `bundle exec rspec spec/system/observations/`
- **Examples**: 48
- **Failures**: 6 ❌
- **Duration**: ~2m 22s (2m 22.4s)
- **Completed**: 2026-02-16 12:17:20
- **Failures**: archive_restore (deadlocks, teammates_pkey); show_page (ambiguous "Publish" button)

### ❌ System: Organizations (29/30 passing, 1 failure)
**Command**: `bundle exec rspec spec/system/organizations/`
- **Examples**: 30
- **Failures**: 1 ❌
- **Duration**: ~1m 22s (1m 21.88s)
- **Completed**: 2026-02-16 12:18:43
- **Failure**: position_update_spec.rb:268 — people_pkey duplicate

### ❌ System: People (0/2 passing, 2 failures)
**Command**: `bundle exec rspec spec/system/people/`
- **Examples**: 2
- **Failures**: 2 ❌
- **Duration**: ~17 seconds (17.45s)
- **Completed**: 2026-02-16 12:19:01
- **Failures**: people_pkey; deadlocks (employment_tenure/position_major_level)

### ✅ System: Positions and Seats (3/3 passing, 3 pending)
**Command**: `bundle exec rspec spec/system/positions_and_seats/`
- **Examples**: 3
- **Failures**: 0 ✅
- **Pending**: 3
- **Duration**: ~3.4 seconds
- **Completed**: 2026-02-16 12:19:15

### ✅ System: Teammates (3/3 passing, 3 pending)
**Command**: `bundle exec rspec spec/system/teammates/`
- **Examples**: 3
- **Failures**: 0 ✅
- **Pending**: 3
- **Duration**: ~3.4 seconds
- **Completed**: 2026-02-16 12:19:28

### ❌ System: teammate_profile_links_spec.rb (1/5 passing, 4 failures)
**Command**: `bundle exec rspec spec/system/teammate_profile_links_spec.rb`
- **Examples**: 5
- **Failures**: 4 ❌
- **Duration**: ~41 seconds (41.35s)
- **Completed**: 2026-02-16 12:20:50
- **Failures**: deadlocks, pg_search_documents_pkey, organizations_pkey

### ❌ System: vertical_navigation_spec.rb (3/8 passing, 5 failures)
**Command**: `bundle exec rspec spec/system/vertical_navigation_spec.rb`
- **Examples**: 8
- **Failures**: 5 ❌
- **Duration**: ~41 seconds (40.94s)
- **Completed**: 2026-02-16 12:21:31
- **Failures**: deadlocks; InFailedSqlTransaction (lock button); pg_search_documents

---

## Phase 14: ENM Specs

### ❌ Phase 14: ENM Specs (103/106 passing, 3 failures)
**Command**: `bundle exec rspec spec/enm/`
- **Examples**: 106
- **Failures**: 3 ❌
- **Status**: 3 FAILURES (deadlocks)
- **Duration**: ~40 seconds (40.43s)
- **Completed**: 2026-02-16 12:07:50
- **Failures**: enm_assessment_wizard_flow_spec.rb — deadlocks in Complete 3-phase flow, Partnership analysis flow, Error handling (lines 5, 167, 201)

### (legacy) Phase 14: ENM Specs (106/106 passing)

**Command**: `bundle exec rspec spec/enm/`
- **Examples**: 106
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~31 seconds (31.48s)
- **Updated**: 2026-02-03 15:40:41

### Phase 15: System Specs (Refactor-related fixes applied)

**Command**: `bundle exec rspec spec/system/`
- **Targeted fixes**: Abilities, Aspirations, Assignments, Position Update, Huddles (participant/view), Finalization (manager_completed_by_teammate), Slack (department/team parent removal).
- **Updated**: Tuesday, February 03, 2026

**Fixes applied**:
- **Abilities**: TeammateMilestone certifying_teammate use existing `company_teammate`; add `published_at`/`published_by_teammate_id` so milestone appears on celebrate page.
- **Assignments**: `department` = `create(:organization, :department)` (no parent); add `department_teammate`; sign_in_as(person, department) for CRUD on department.
- **Aspirations**: `department` = `create(:organization, :department)`; aspiration index view `aspiration.organization` → `aspiration.company`; department CRUD sign_in_as(maap_user, department); "same name in different orgs" use other_company + sign_in_as(other_company); "handles department selection" use `create(:department, company: company)`.
- **Position Update**: `department` = `create(:department, company: company)`, title `company: company, department: department` for dropdown grouping.
- **Huddles**: `department`/`team` = Department/Team factories (no parent); `existing_team`/`department_as_team` = `create(:team, company: company)`; `team.special_session_name` → `team.name`; app/views/huddles/show.html.haml `joins(:teammate)` → `joins(:company_teammate)`, find_by(teammates: { person: ... }) (table name teammates); HuddleFeedback same join fix.
- **Finalization**: `manager_completed_by: manager_person` → `manager_completed_by_teammate: manager_teammate`; employment_tenure `manager:` → `manager_teammate:`.
- **Slack (Channel & Group)**: `department1`/`department2` = `create(:department, company: company)`; `team1`/`team2` = `create(:team, company: company)`.

**Still failing (form/UI or unrelated)**: Goal Link "Add Child Goal", Slack "Company" select, Finalization "removes items" assertion, Huddles "Create huddle from existing company/department/team" (form/routing).

#### ✅ System: Abilities (2/2 passing)
**Command**: `bundle exec rspec spec/system/abilities/` — Examples: 2, Failures: 0 ✅, Duration: ~12s (12.24s) — **Updated**: 2026-02-03 15:41:04

#### ✅ System: Aspirations (7/7 passing)
**Command**: `bundle exec rspec spec/system/aspirations/` — Examples: 7, Failures: 0 ✅, Duration: ~25s (24.59s) — **Updated**: 2026-02-03 15:41:51

#### ✅ System: Assignments (2/2 passing)
**Command**: `bundle exec rspec spec/system/assignments/` — Examples: 2, Failures: 0 ✅, Duration: ~14s (14.22s) — **Updated**: 2026-02-03 15:42:22

#### ✅ System: Audit (3/3 passing, 3 pending)
**Command**: `bundle exec rspec spec/system/audit/` — Examples: 3, Failures: 0 ✅, Pending: 3, Duration: ~0.6s — **Updated**: 2026-02-03 15:42:37

#### ✅ System: Check-in Observations (1/1 passing)
**Command**: `bundle exec rspec spec/system/check_in_observations/` — Examples: 1, Failures: 0 ✅, Duration: ~36s (36.12s) — **Updated**: 2026-02-03 15:43:27

#### ✅ System: Check-ins (14/14 passing)
**Command**: `bundle exec rspec spec/system/check_ins/` — Examples: 14, Failures: 0 ✅, Duration: ~37s (36.66s) — **Updated**: 2026-02-03 15:44:20

#### ❌ System: Finalization (2/3 passing, 1 failure)
**Command**: `bundle exec rspec spec/system/finalization/` — Examples: 3, Failures: 1 ❌, Duration: ~10s — **Updated**: 2026-02-03 15:44:35
**Failure**: `finalization_complete_flow_spec.rb:144` — Manager view "removes items from to be finalized list when manager saves".

#### ❌ System: Get Shit Done (1/8 passing, 7 failures)
**Command**: `bundle exec rspec spec/system/get_shit_done/` — Examples: 8, Failures: 7 ❌, Duration: ~39s — **Updated**: 2026-02-03 15:45:32
**Failures**: dashboard display (all pending items, MAAP snapshots, observation drafts, observable moments, goals needing check-in); navigation badge (count, links to dashboard — redirects to about_me).

#### ❌ System: Goals (56/57 passing, 1 failure, 7 pending)
**Command**: `bundle exec rspec spec/system/goals/` — Examples: 57, Failures: 1 ❌, Pending: 7, Duration: ~1m 48s — **Updated**: 2026-02-03 15:47:35
**Failure**: `goals_crud_flow_spec.rb:876` — "links to goals check-in view from about_me page" — expected link "Manage Goals & Confidence Ratings" not found.

#### ❌ System: Huddles (3/6 passing, 3 failures, 1 pending)
**Command**: `bundle exec rspec spec/system/huddles/` — Examples: 6, Failures: 3 ❌, Pending: 1, Duration: ~28s — **Updated**: 2026-02-03 15:48:20
**Failures**: Create huddle from existing company/department/team — Ambiguous match, found 2 elements matching `.card` with org name.

#### ❌ System: Misc (17/21 passing, 4 failures)
**Command**: `bundle exec rspec spec/system/misc/` — Examples: 21, Failures: 4 ❌, Duration: ~1m 8s — **Updated**: 2026-02-03 15:49:46
**Failures**: Slack integration — Huddle creation ambiguous `.card` (2); Channel & Group Associations — edits kudos/group, clearing kudos/group (2).

#### ❌ System: Observable Moments (3/7 passing, 4 failures)
**Command**: `bundle exec rspec spec/system/observable_moments/` — Examples: 7, Failures: 4 ❌, Duration: ~29s — **Updated**: 2026-02-03 15:50:31
**Failures**: check_in_moment_flow — creates moment when position check-in rating improved; new_hire_moment_flow — "New Hire" text not visible, Ignore button/Reassign link not found.

#### ❌ System: Observations (52/54 passing, 2 failures)
**Command**: `bundle exec rspec spec/system/observations/` — Examples: 54, Failures: 2 ❌, Duration: ~2m 17s — **Updated**: 2026-02-03 15:53:05
**Failures**: archive_restore_spec — Archive from get shit done page: expected button "Archive" not found (2).

#### ✅ System: Organizations (30/30 passing)
**Command**: `bundle exec rspec spec/system/organizations/` — Examples: 30, Failures: 0 ✅, Duration: ~1m 34s — **Updated**: 2026-02-03 15:55:15

#### ✅ System: People (2/2 passing)
**Command**: `bundle exec rspec spec/system/people/` — Examples: 2, Failures: 0 ✅, Duration: ~13s — **Updated**: 2026-02-03 15:55:36

#### ✅ System: Positions and Seats (3/3 passing, 3 pending)
**Command**: `bundle exec rspec spec/system/positions_and_seats/` — Examples: 3, Failures: 0 ✅, Pending: 3, Duration: ~1s — **Updated**: 2026-02-03 15:55:45

#### ✅ System: Teammates (3/3 passing, 3 pending)
**Command**: `bundle exec rspec spec/system/teammates/` — Examples: 3, Failures: 0 ✅, Pending: 3, Duration: ~1s — **Updated**: 2026-02-03 15:55:54

#### ✅ System: vertical_navigation_spec.rb (8/8 passing)
**Command**: `bundle exec rspec spec/system/vertical_navigation_spec.rb` — Examples: 8, Failures: 0 ✅, Duration: ~19s — **Updated**: 2026-02-03 15:56:51

#### ✅ System: check_ins_save_and_redirect_spec.rb (2/2 passing)
**Command**: `bundle exec rspec spec/system/check_ins_save_and_redirect_spec.rb` — Examples: 2, Failures: 0 ✅, Duration: ~9s — **Updated**: 2026-02-03 15:56:18

#### ✅ System: teammate_profile_links_spec.rb (5/5 passing)
**Command**: `bundle exec rspec spec/system/teammate_profile_links_spec.rb` — Examples: 5, Failures: 0 ✅, Duration: ~14s — **Updated**: 2026-02-03 15:56:32

## Overall Summary

### Run Summary (2026-02-16 11:55–12:21)
- **Unit/Integration**: Model ✅, Controller ❌ (3), Request ❌ (2), Policy ❌ (2), Service ✅, Job ✅, Helper ✅, Form ✅, Decorator ✅, Query ✅, Integration ✅, Route ✅, View ❌ (3), ENM ❌ (3)
- **System**: Abilities ✅, Aspirations ✅, Assignments ❌ (1), Audit ✅, Check-in Observations ❌ (1), Check-ins ❌ (1), check_ins_save_and_redirect ❌ (1), Finalization ❌ (1), Get Shit Done ✅, Goals ✅, Huddles ✅, Misc ❌ (9), Observable Moments ❌ (2), Observations ❌ (6), Organizations ❌ (1), People ❌ (2), Positions and Seats ✅, Teammates ✅, teammate_profile_links ❌ (4), vertical_navigation ❌ (5)
- **Total failures this run**: **55** (unit: 13; system: 42)

---

## All Failures (2026-02-16) and Plan of Action

### Unit/Integration Failures (13)

| Segment | File / Location | Failure |
|--------|------------------|--------|
| **Controllers** | insights_controller_spec.rb:237 | Chart categories expected 52–53, got 54 (observations) |
| **Controllers** | insights_controller_spec.rb:319 | Chart categories expected 52–53, got 54 (prompts) |
| **Controllers** | insights_controller_spec.rb:196 | GET #goals: assigns(:total_goals) expected 2, got nil |
| **Requests** | prompt_templates_spec.rb:17, :22 | GET prompt_templates returns 302 redirect, does not render index |
| **Policies** | assignment_flow_policy_spec.rb:83 | Deadlock creating organization |
| **Policies** | prompt_goal_policy_spec.rb:47 | create? expected true, got false |
| **Views** | organizations/kudos/index.html.haml_spec.rb (3) | Deadlocks in link display, truncates long stories, does not include GIFs |
| **ENM** | enm_assessment_wizard_flow_spec.rb (3) | Deadlocks in 3-phase flow, Partnership analysis, Error handling |

### System Spec Failures (42)

| Folder / File | Count | Cause |
|---------------|-------|--------|
| **assignments** | 1 | organizations_pkey duplicate (department factory) |
| **check_in_observations** | 1 | Deadlock (create organization) |
| **check_ins** | 1 | organizations_pkey duplicate |
| **check_ins_save_and_redirect_spec** | 1 | Deadlock (position_check_ins insert) |
| **finalization** | 1 | Deadlock (create organization) |
| **misc** | 9 | Deadlocks (Dashboard, Timezone); Slack permission / Channel & Group (no "Manage Channel & Group Associations", field/tr not found) |
| **observable_moments** | 2 | Deadlock (UserPreference); pg_search_documents_pkey |
| **observations** | 6 | Deadlocks, teammates_pkey; ambiguous "Publish" button (show_page) |
| **organizations** | 1 | people_pkey duplicate (position_update_spec) |
| **people** | 2 | people_pkey; deadlocks (employment_tenure / position_major_level) |
| **teammate_profile_links_spec** | 4 | Deadlocks, pg_search_documents_pkey, organizations_pkey |
| **vertical_navigation_spec** | 5 | Deadlocks; InFailedSqlTransaction (lock button); pg_search_documents |

---

### Plan of Action to Fix Failures

1. **Deterministic IDs and shared DB state (high impact)**  
   - **Duplicate key (organizations_pkey, people_pkey, teammates_pkey, pg_search_documents_pkey)**: System specs and Capybara use a shared DB; sequences can collide when tests run in parallel or cleanup is inconsistent.  
   - **Fix**: Ensure system specs use `DatabaseCleaner` (or equivalent) in a way that avoids sharing IDs across examples (e.g. truncation vs deletion, or non-parallel system runs). Consider disabling parallelization for system specs or using a single connection so sequences are not shared across threads.  
   - **Alternative**: Use `create` with explicit non-conflicting attributes so IDs are not reused (e.g. avoid reusing id=1 for organization/person in nested factories).

2. **Deadlocks (DB locking)**  
   - **Cause**: Multiple threads/processes (RSpec + Capybara server) touching same tables (organizations, pg_search_documents, user_preferences, teammates, etc.) in different order.  
   - **Fix**: Run system/ENM/view specs that use JS with a single thread (`PARALLEL=0` or equivalent); or ensure DatabaseCleaner strategy and connection sharing (e.g. `config.shared_connection_for_tests`) are set so only one DB connection is used.  
   - **Doc**: See testing-strategy.md (shared database connection for system tests). Re-check `spec/rails_helper.rb` and Capybara config so the app server and test process share one DB connection and cleanup order is deterministic.

3. **Controllers – Insights**  
   - **Chart categories 54 vs 52–53**: Update expectations to allow 54 (e.g. `be_between(52, 54)`) or change the insight builder to cap at 53.  
   - **total_goals nil**: Ensure GET #goals sets `@total_goals` in the controller (or fix the example to match current behavior).

4. **Requests – Prompt templates**  
   - **302 instead of 200**: Unauthenticated or unauthorized request; ensure the request spec signs in and uses a user with access to prompt_templates, or adjust the spec to expect redirect when not allowed.

5. **Policies**  
   - **AssignmentFlowPolicy deadlock**: Same as (2); run in single-threaded mode or fix factory/cleanup so organization creation does not deadlock.  
   - **PromptGoalPolicy create?**: Update policy or spec so that “user can update the prompt” implies create? is true (e.g. fix policy rule or test setup).

6. **Views – Kudos index**  
   - **Deadlocks**: Same as (2); run view specs without parallelization and with shared DB connection if they touch the same tables as other threads.

7. **ENM – Wizard flow**  
   - **Deadlocks**: Same as (2); run ENM system specs with a single process/thread and shared DB.

8. **System – Slack / Misc**  
   - **“Manage Channel & Group Associations” not shown**: User in spec may lack permission; ensure test user has Slack config access (e.g. admin or proper role).  
   - **tr[data-organization-id] / field not found**: DOM or permissions changed; update selectors or ensure page under test is the Channel & Group page with expected markup.

9. **System – Observations**  
   - **Ambiguous "Publish" button**: Use a more specific selector (e.g. within a section, or data attribute) so exactly one "Publish" button is matched.

10. **System – Vertical navigation**  
    - **InFailedSqlTransaction**: Avoid leaving the DB in a failed transaction (e.g. after a prior failure in the same example); ensure sign_in or previous steps don’t trigger a rollback that leaves the connection bad for teammate.reload.

---

### Run Summary (2026-02-03 15:26–15:57) (legacy)
- **Unit/Integration**: Model ✅, Controller ✅, Request ✅, Policy ✅, Service ✅, Job ✅, Helper ✅, Form ✅, Decorator ✅, Query ✅, Integration ✅, Route ✅, View ✅, ENM ✅ — **0 failures**
- **System**: Abilities ✅, Aspirations ✅, Assignments ✅, Audit ✅, Check-in Observations ✅, Check-ins ✅, Finalization ❌ (1), Get Shit Done ❌ (7), Goals ❌ (1), Huddles ❌ (3), Misc ❌ (4), Observable Moments ❌ (4), Observations ❌ (2), Organizations ✅, People ✅, Positions and Seats ✅, Teammates ✅, check_ins_save_and_redirect ✅, teammate_profile_links ✅, vertical_navigation ✅
- **Total failures that run**: **22**

### Total Spec Counts (2026-02-03)
- **Models**: 1,535 examples (0 failures) ✅
- **Controllers**: 1,276 examples (0 failures) ✅
- **Requests**: 1,243 examples (0 failures) ✅
- **Policies**: 538 examples (0 failures) ✅
- **Services**: 922 examples (0 failures) ✅
- **Jobs**: 150 examples (0 failures) ✅
- **Helpers**: 299 examples (0 failures) ✅
- **Forms**: 165 examples (0 failures) ✅
- **Decorators**: 99 examples (0 failures) ✅
- **Queries**: 332 examples (0 failures) ✅
- **Integrations**: 9 examples (0 failures) ✅
- **Routes**: 34 examples (0 failures) ✅
- **Views**: 113 examples (0 failures) ✅
- **ENM**: 106 examples (0 failures) ✅
- **System**: 240 examples (22 failures) ❌

**Total**: ~6,051 unit/integration examples (0 failures); 240 system examples (22 failures).

### Passing Rate
- **Unit/Integration Specs**: 100% passing (all segments run separately; doc updated after each segment).
- **System Specs**: 218/240 passing (~91%); 22 failures in Finalization, Get Shit Done, Goals, Huddles, Misc, Observable Moments, Observations.

## Critical Issues Identified

Failures are concentrated in the **person → teammate** and **employee → company_teammate** (and related route/term) migration:

1. **Wall view / profile images (Controllers, Models)**  
   - `employee_identities` used on `CompanyTeammate`; association lives on `Person` (e.g. `TeammateIdentity`).  
   - **Fix**: In observations wall view (and any code passing “employees” as teammates), use teammate → person then person’s identities, or introduce a shared interface (e.g. `latest_profile_image_url` on teammate that delegates to `person`).

2. **Person model (Models)**  
   - `slack_identities` and `latest_profile_image_url` assume Person/identity naming; specs and code still reference old “employee” identity names.  
   - **Fix**: Align Person with TeammateIdentity (and any renames); ensure `latest_profile_image_url` works for both Person and CompanyTeammate (or only for Person when called from a person).

3. **Seat#team (Models)**  
   - `Seat` expects `Team` (STI); spec assigns plain `Organization`.  
   - **Fix**: In Seat spec (and app code), use `Organization` with `type: 'Team'` (or factory that creates a Team).

4. **Policies (root_company, company, teammate)**  
   - PositionPolicy, SeatPolicy, PromptPolicy, GoalLinkPolicy, PromptTemplatePolicy, PromptGoalPolicy expect company/teammate context.  
   - **Fix**: Pass `CompanyTeammate` (and company) where policies expect them; update any remaining Person/employee references in policy specs.

5. **Requests (routes, company_teammates, public_maap, vertical_navigation)**  
   - Route renames (e.g. employees → company_teammates), assignment_tenure_check_in_bypass, public_maap assignments, vertical_navigation.  
   - **Fix**: Update request specs to use new routes and new param names (organization_id, company_teammate_id, etc.); fix any `root_company` / company hierarchy expectations.

6. **Services / Jobs / Helpers / Forms / Decorators / Queries / Views**  
   - UnassignedEmployeeUploadProcessor, ObservableMoments, GetShitDoneQueryService, Goals::BulkCreateUnlinkedService, Slack::ProcessHuddleCommandService; Comments::PostNotificationJob; TeammateHelper; AspirationForm, GoalForm, FormSemanticVersionable; query and view specs.  
   - **Fix**: Replace “employee”/“person” with “company_teammate”/“teammate” and “organization” with “company” where the domain now uses company; update factories and stubs to build CompanyTeammate and Company.

7. **System specs**  
   - Abilities, Aspirations, Assignments, Check-ins, Finalization, Get Shit Done, Goals, Huddles, Misc, Observable Moments, Observations, Organizations, Vertical Navigation.  
   - **Fix**: Align with new routes and UI (company teammates, positions, employment); fix selectors and expectations for renamed links/IDs and teammate vs employee language.

## Plan of Action to Fix Failures

1. **Core domain (high impact)**  
   - Fix **observations wall view** and **Person#latest_profile_image_url** so they work with CompanyTeammate (use `.person` and Person’s identities, or add delegation on teammate).  
   - Fix **Seat** association: ensure `team` is a `Team` (STI) in specs and in code.  
   - Fix **Person** slack_identities / identity specs and implementation for TeammateIdentity naming.

2. **Policies**  
   - Audit all 11 failing policy specs; pass CompanyTeammate and company; replace root_company/employee with current policy API (root_company/company/teammate).

3. **Requests**  
   - Bulk-update request specs: route helpers (company_teammates, positions, etc.), params, and any expectations for redirects/JSON.  
   - Fix assignment_tenure_check_in_bypass and public_maap/assignments request specs.

4. **Services, Jobs, Helpers**  
   - Replace employee/person with company_teammate/teammate in services (UnassignedEmployeeUploadProcessor, ObservableMoments, GetShitDone, Goals::BulkCreateUnlinked, Slack::ProcessHuddleCommand), jobs (Comments::PostNotification, TrackMissingResource), and TeammateHelper.  
   - Align factories and build args with CompanyTeammate and Company.

5. **Forms, Decorators, Queries, Views**  
   - Update form validations and attributes (organization_id, version_type, owner); decorator and query specs for company/teammate; view specs for new partials and instance variable names.

6. **System specs**  
   - Update one folder at a time (e.g. abilities, aspirations, assignments, then check_ins, finalization, get_shit_done, goals, huddles, misc, observable_moments, observations, organizations, vertical_navigation).  
   - Use current routes, link text, and data attributes; fix any “employee”/“person” UI expectations to “teammate”/“company teammate”.
