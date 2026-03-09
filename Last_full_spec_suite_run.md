# Last Full Spec Suite Run

## Run Information
- **Run Date**: 2026-03-09
- **Started**: 2026-03-09 07:42:57
- **Last Update**: 2026-03-09 (updated after each segment)
- **Total Duration**: Segments run separately; doc updated after each segment.

## Segment Results

### ✅ Phase 1: Model Specs (1844/1844 passing, 1 pending)
**Command**: `bundle exec rspec spec/models/`
- **Examples**: 1844
- **Failures**: 0 ✅
- **Pending**: 1
- **Status**: ALL PASSING
- **Duration**: ~1m 12s (72.56s)
- **Completed**: 2026-03-09 07:44:10

### ✅ Phase 2: Controller Specs (1526/1526 passing, 6 pending)
**Command**: `bundle exec rspec spec/controllers/`
- **Examples**: 1526
- **Failures**: 0 ✅
- **Pending**: 6
- **Status**: ALL PASSING
- **Duration**: ~4m 3s (4m 3.1s)
- **Completed**: 2026-03-09 07:49:00

### ❌ Phase 3: Request Specs (1597/1601 passing, 3 pending, 4 failures)
**Command**: `bundle exec rspec spec/requests/`
- **Examples**: 1601
- **Failures**: 4 ❌
- **Pending**: 3
- **Status**: 4 FAILURES
- **Duration**: ~5m 43s
- **Completed**: 2026-03-09
- **Failures**: eligibility_requirements_spec.rb:64; manage_eligibility_spec.rb:50; assignments_spec.rb:77, :375

### ✅ Phase 4: Policy Specs (604/604 passing)
**Command**: `bundle exec rspec spec/policies/`
- **Examples**: 604
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~52s (52.23s)
- **Completed**: 2026-03-09

### ❌ Phase 5: Service Specs (1123/1125 passing, 4 pending, 2 failures)
**Command**: `bundle exec rspec spec/services/`
- **Examples**: 1125
- **Failures**: 2 ❌
- **Pending**: 4
- **Status**: 2 FAILURES
- **Duration**: ~1m 50s
- **Completed**: 2026-03-09
- **Failures**: check_in_finalization_service_spec.rb:281, :443 (observable moment when rating improved)

### ❌ Phase 6: Job Specs (166/167 passing, 1 failure)
**Command**: `bundle exec rspec spec/jobs/`
- **Examples**: 167
- **Failures**: 1 ❌
- **Status**: 1 FAILURE
- **Duration**: ~26s
- **Completed**: 2026-03-09
- **Failure**: application_job_spec.rb:12 (perform_now vs perform_and_get_result)

### ✅ Phase 7: Helper Specs (405/405 passing)
**Command**: `bundle exec rspec spec/helpers/`
- **Examples**: 405
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~39s
- **Completed**: 2026-03-09

### ✅ Phase 8: Form Specs (173/173 passing)
**Command**: `bundle exec rspec spec/forms/`
- **Examples**: 173
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~15s
- **Completed**: 2026-03-09

### ✅ Phase 9: Decorator Specs (99/99 passing)
**Command**: `bundle exec rspec spec/decorators/`
- **Examples**: 99
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~12 seconds (11.56s)
- **Completed**: 2026-02-16 12:04:27

### ✅ Phase 10: Query Specs (359/359 passing)
**Command**: `bundle exec rspec spec/queries/`
- **Examples**: 359
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~1m 5s
- **Completed**: 2026-03-09

### ✅ Phase 11: Integration Specs (9/9 passing)
**Command**: `bundle exec rspec spec/integrations/`
- **Examples**: 9
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~5s
- **Completed**: 2026-03-09

### ✅ Phase 12: Route Specs (46/46 passing)
**Command**: `bundle exec rspec spec/routes/`
- **Examples**: 46
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~6s
- **Completed**: 2026-03-09

### ❌ Phase 13: View Specs (142/143 passing, 1 failure)
**Command**: `bundle exec rspec spec/views/`
- **Examples**: 143
- **Failures**: 1 ❌
- **Status**: 1 FAILURE
- **Duration**: ~26s
- **Completed**: 2026-03-09
- **Failure**: organizations/observations/share_privately.html.haml_spec.rb:124 (includes JavaScript for Bootstrap tooltips; deadlock in setup)

---

## System Specs (each folder/file run separately) — 2026-03-09

### ✅ System: Abilities (2/2 passing)
**Command**: `bundle exec rspec spec/system/abilities/`
- **Examples**: 2, **Failures**: 0 ✅, **Duration**: ~42s — **Completed**: 2026-03-09

### ❌ System: Aspirations (6/7 passing, 1 failure, 5 pending)
**Command**: `bundle exec rspec spec/system/aspirations/`
- **Examples**: 7, **Failures**: 1 ❌ — **Completed**: 2026-03-09
- **Failure**: aspiration_crud_flow_spec.rb:65 — unique constraint index_people_on_unique_textable_phone_number

### ❌ System: Assignments (1/2 passing, 1 failure)
**Command**: `bundle exec rspec spec/system/assignments/`
- **Examples**: 2, **Failures**: 1 ❌ — **Completed**: 2026-03-09
- **Failure**: assignments_core_flow_spec.rb:70 — deadlock

### ✅ System: Audit (3/3 passing, 3 pending)
**Command**: `bundle exec rspec spec/system/audit/`
- **Examples**: 3, **Failures**: 0 ✅ — **Completed**: 2026-03-09

### System: Bugs (0 examples)
**Command**: `bundle exec rspec spec/system/bugs/` — 0 examples — **Completed**: 2026-03-09

### ❌ System: Check-in Observations (0/1 passing, 1 failure)
**Command**: `bundle exec rspec spec/system/check_in_observations/`
- **Failure**: check_in_observations_flow_spec.rb:23 — index_people_on_unique_textable_phone_number — **Completed**: 2026-03-09

### ❌ System: Check-ins (13/14 passing, 1 failure, 13 pending)
**Command**: `bundle exec rspec spec/system/check_ins/`
- **Failure**: check_ins_complete_flow_spec.rb:43 — Key (id)=(1) already exists — **Completed**: 2026-03-09

### ❌ System: check_ins_save_and_redirect_spec.rb (0/2 passing, 2 failures)
**Command**: `bundle exec rspec spec/system/check_ins_save_and_redirect_spec.rb`
- **Failures**: 2 ❌ (displays check-ins page / form fields) — **Completed**: 2026-03-09

### ❌ System: Finalization (suite error — deadlock)
**Command**: `bundle exec rspec spec/system/finalization/` — 0 examples, before(:suite) deadlock — **Completed**: 2026-03-09

### ❌ System: Get Shit Done (1/2 passing, 1 failure)
**Command**: `bundle exec rspec spec/system/get_shit_done/`
- **Failure**: dashboard_spec.rb:15 — deadlock (user_preferences) — **Completed**: 2026-03-09

### ❌ System: Goals (suite error — deadlock)
**Command**: `bundle exec rspec spec/system/goals/` — 0 examples, before(:suite) deadlock — **Completed**: 2026-03-09

### ❌ System: Huddles (3/6 passing, 3 failures, 1 pending)
**Command**: `bundle exec rspec spec/system/huddles/`
- **Failures**: huddles_core_flow_spec.rb:18, :87, :165 (create from company/team, feedback form) — **Completed**: 2026-03-09

### ❌ System: Misc (22/24 passing, 2 failures)
**Command**: `bundle exec rspec spec/system/misc/`
- **Failures**: organization_dashboard_spec.rb:13 (redirect to about_me); slack_integration_spec.rb:255 (navigates to Slack dashboard) — **Completed**: 2026-03-09

### ❌ System: Observable Moments (5/7 passing, 2 failures, 3 pending)
**Command**: `bundle exec rspec spec/system/observable_moments/`
- **Failures**: check_in_moment_flow_spec.rb:33; goal_check_in_moment_flow_spec.rb:46 (pg_search_documents_pkey) — **Completed**: 2026-03-09

### ❌ System: Observations (45/49 passing, 4 failures)
**Command**: `bundle exec rspec spec/system/observations/`
- **Failures**: archive_restore_spec.rb:24, :36, :59, :74 (pg_search_documents_pkey / archive-restore) — **Completed**: 2026-03-09

### ❌ System: Organizations (suite error — deadlock)
**Command**: `bundle exec rspec spec/system/organizations/` — 0 examples, before(:suite) deadlock — **Completed**: 2026-03-09

### ✅ System: People (2/2 passing)
**Command**: `bundle exec rspec spec/system/people/` — **Completed**: 2026-03-09

### ✅ System: Positions and Seats (3/3 passing, 3 pending)
**Command**: `bundle exec rspec spec/system/positions_and_seats/` — **Completed**: 2026-03-09

### ✅ System: Teammates (3/3 passing, 3 pending)
**Command**: `bundle exec rspec spec/system/teammates/` — **Completed**: 2026-03-09

### ❌ System: teammate_profile_links_spec.rb (suite error — deadlock)
**Command**: `bundle exec rspec spec/system/teammate_profile_links_spec.rb` — 0 examples — **Completed**: 2026-03-09

### ❌ System: vertical_navigation_spec.rb (7/8 passing, 1 failure)
**Command**: `bundle exec rspec spec/system/vertical_navigation_spec.rb`
- **Failure**: vertical_navigation_spec.rb:115 — switches to vertical layout from user menu — **Completed**: 2026-03-09

---

## Phase 14: ENM Specs — 2026-03-09

### ✅ Phase 14: ENM Specs (106/106 passing)
**Command**: `bundle exec rspec spec/enm/`
- **Examples**: 106, **Failures**: 0 ✅, **Duration**: ~52s — **Completed**: 2026-03-09

---

## Phase 14: ENM Specs (legacy 2026-02-16)

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

### Run Summary (2026-03-09)
- **Unit/Integration**: Model ✅, Controller ✅, Request ❌ (4), Policy ✅, Service ❌ (2), Job ❌ (1), Helper ✅, Form ✅, Decorator ✅, Query ✅, Integration ✅, Route ✅, View ❌ (1), ENM ✅
- **System**: Abilities ✅, Aspirations ❌ (1), Assignments ❌ (1), Audit ✅, Check-in Observations ❌ (1), Check-ins ❌ (1), check_ins_save_and_redirect ❌ (2), Finalization (suite deadlock), Get Shit Done ❌ (1), Goals (suite deadlock), Huddles ❌ (3), Misc ❌ (2), Observable Moments ❌ (2), Observations ❌ (4), Organizations (suite deadlock), People ✅, Positions and Seats ✅, Teammates ✅, teammate_profile_links (suite deadlock), vertical_navigation ❌ (1)
- **Total failures this run**: **Unit 8** (Request 4, Service 2, Job 1, View 1) + **System ~20+** (varies with deadlocks)

### Run Summary (2026-02-16 11:55–12:21)
- **Unit/Integration**: Model ✅, Controller ❌ (3), Request ❌ (2), Policy ❌ (2), Service ✅, Job ✅, Helper ✅, Form ✅, Decorator ✅, Query ✅, Integration ✅, Route ✅, View ❌ (3), ENM ❌ (3)
- **System**: Abilities ✅, Aspirations ✅, Assignments ❌ (1), Audit ✅, Check-in Observations ❌ (1), Check-ins ❌ (1), check_ins_save_and_redirect ❌ (1), Finalization ❌ (1), Get Shit Done ✅, Goals ✅, Huddles ✅, Misc ❌ (9), Observable Moments ❌ (2), Observations ❌ (6), Organizations ❌ (1), People ❌ (2), Positions and Seats ✅, Teammates ✅, teammate_profile_links ❌ (4), vertical_navigation ❌ (5)
- **Total failures this run**: **55** (unit: 13; system: 42)

---

## All Failures (2026-03-09) and Plan of Action

### Unit/Integration Failures (8)

| Segment | File / Location | Failure |
|--------|------------------|--------|
| **Requests** | eligibility_requirements_spec.rb:64 | Renders section (1) managerial hierarchy and section (2) business need cards |
| **Requests** | manage_eligibility_spec.rb:50 | Handles position with no eligibility requirements |
| **Requests** | assignments_spec.rb:77 | Shows disabled edit and delete options for non-admin users |
| **Requests** | assignments_spec.rb:375 | Renders view switcher with all options enabled (admin) |
| **Services** | check_in_finalization_service_spec.rb:281, :443 | Creates observable moment when position check-in rating improved |
| **Jobs** | application_job_spec.rb:12 | perform_now vs perform_and_get_result expectation (value comparison) |
| **Views** | share_privately.html.haml_spec.rb:124 | Includes JavaScript for Bootstrap tooltips (deadlock in setup) |

### System Spec Failures (2026-03-09)

| Folder / File | Failure cause |
|---------------|----------------|
| **aspirations** | aspiration_crud_flow_spec.rb:65 — index_people_on_unique_textable_phone_number |
| **assignments** | assignments_core_flow_spec.rb:70 — deadlock |
| **check_in_observations** | check_in_observations_flow_spec.rb:23 — index_people_on_unique_textable_phone_number |
| **check_ins** | check_ins_complete_flow_spec.rb:43 — Key (id)=(1) already exists |
| **check_ins_save_and_redirect_spec** | 2 failures — displays check-ins page / form fields |
| **finalization** | Suite deadlock (before :suite) |
| **get_shit_done** | dashboard_spec.rb:15 — deadlock (user_preferences) |
| **goals** | Suite deadlock (before :suite) |
| **huddles** | huddles_core_flow_spec.rb:18, :87, :165 — create from company/team, feedback form |
| **misc** | organization_dashboard_spec.rb:13 (redirect to about_me); slack_integration_spec.rb:255 (Slack dashboard nav) |
| **observable_moments** | check_in_moment_flow_spec:33; goal_check_in_moment_flow_spec:46 — pg_search_documents_pkey |
| **observations** | archive_restore_spec:24, :36, :59, :74 — pg_search_documents_pkey / archive-restore |
| **organizations** | Suite deadlock |
| **teammate_profile_links_spec** | Suite deadlock |
| **vertical_navigation_spec** | vertical_navigation_spec.rb:115 — switches to vertical layout from user menu |

### Plan of Action to Fix Failures (2026-03-09)

1. **Duplicate key / sequence collisions (high impact)**  
   - **pg_search_documents_pkey**, **Key (id)=(1) already exists** (organizations/check_ins), **index_people_on_unique_textable_phone_number**: Shared DB between RSpec and Capybara server causes ID/unique-index collisions when cleanup or ordering is inconsistent.  
   - **Fix**: Ensure DatabaseCleaner runs with truncation in a deterministic order; run system specs one folder at a time with no parallel workers; or use `config.shared_connection_for_tests` so app and test share one DB connection (see testing-strategy.md). Consider resetting sequences after truncation for tables that use serial IDs and are created in both app and test processes.

2. **Deadlocks (before :suite or mid-test)**  
   - **Finalization, Goals, Organizations, teammate_profile_links**: Suite-level deadlock (DatabaseCleaner.clean_with :truncation) when another process (e.g. previous Capybara server) still holds locks.  
   - **Get Shit Done, Assignments, Misc**: Mid-test deadlocks (user_preferences, Slack nav).  
   - **Fix**: Run each system segment in a fresh terminal with no other rspec/capybara running; ensure only one DB connection for system tests (shared_connection_for_tests); avoid running system specs in parallel.

3. **Requests — eligibility_requirements and manage_eligibility**  
   - **Fix**: Inspect response body/status and view changes; adjust expectations for section (1)/(2) and “position with no eligibility requirements” to match current controller/view behavior.

4. **Requests — assignments_spec (77, 375)**  
   - **Fix**: Update expectations for “disabled edit/delete for non-admin” and “view switcher with all options enabled” to match current assignment show view and authorization (e.g. correct buttons/links and visibility).

5. **Services — CheckInFinalizationService**  
   - **Fix**: Align “creates observable moment when rating improved” with current logic (e.g. how “improved” is determined and when ObservableMoment is created); fix spec setup (previous check-in rating) or service logic.

6. **Jobs — ApplicationJob**  
   - **Fix**: Spec expects “value != result”; adjust expectation (e.g. compare relevant keys or use a matcher that allows for return value structure) so perform_now vs perform_and_get_result is correctly asserted.

7. **Views — share_privately**  
   - **Fix**: Isolate spec from deadlock (e.g. avoid creating searchable records in let blocks that conflict with truncation); or run view specs with single-threaded DB access.

8. **System — Huddles**  
   - **Fix**: “Creates huddle from existing company/team” and “feedback form” — resolve ambiguous `.card` or selector; ensure company/team/department factories and sign-in context match current routes/UI.

9. **System — vertical_navigation**  
   - **Fix**: “Switches to vertical layout from user menu” — update selector or flow (e.g. user menu item text or DOM) to match current layout switching implementation.

10. **System — Misc (dashboard redirect, Slack nav)**  
    - **Fix**: Dashboard redirect spec — ensure expected path/redirect for “about_me”; Slack nav — ensure test user has permission and page loads without deadlock; stabilize setup so no cross-process lock contention.

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
