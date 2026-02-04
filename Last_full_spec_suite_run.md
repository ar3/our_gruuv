# Last Full Spec Suite Run

## Run Information
- **Run Date**: 2026-02-03
- **Started**: 2026-02-03 18:23:46
- **Last Update**: (updated after each segment)
- **Total Duration**: Segments run separately; doc updated after each segment.

## Segment Results

### ✅ Phase 1: Model Specs (1535/1535 passing, 1 pending)
**Command**: `bundle exec rspec spec/models/`
- **Examples**: 1535
- **Failures**: 0 ✅
- **Pending**: 1
- **Status**: ALL PASSING
- **Duration**: ~58 seconds (58.13s)
- **Completed**: 2026-02-03 18:25:03

### ✅ Phase 2: Controller Specs (1276/1276 passing, 6 pending)
**Command**: `bundle exec rspec spec/controllers/`
- **Examples**: 1276
- **Failures**: 0 ✅
- **Pending**: 6
- **Status**: ALL PASSING
- **Duration**: ~2 minutes 25 seconds (2m 25.1s)
- **Completed**: 2026-02-03 18:27:56

### ✅ Phase 3: Request Specs (1246/1246 passing, 3 pending)
**Command**: `bundle exec rspec spec/requests/`
- **Examples**: 1246
- **Failures**: 0 ✅
- **Pending**: 3
- **Status**: ALL PASSING
- **Duration**: ~3 minutes 18 seconds (3m 18s)
- **Completed**: 2026-02-03 18:31:33

### ✅ Phase 4: Policy Specs (538/538 passing)
**Command**: `bundle exec rspec spec/policies/`
- **Examples**: 538
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~47 seconds (47.11s)
- **Completed**: 2026-02-03 18:32:46

### ✅ Phase 5: Service Specs (922/922 passing, 4 pending)
**Command**: `bundle exec rspec spec/services/`
- **Examples**: 922
- **Failures**: 0 ✅
- **Pending**: 4
- **Status**: ALL PASSING
- **Duration**: ~54 seconds (54.26s)
- **Completed**: 2026-02-03 18:33:57

### ✅ Phase 6: Job Specs (150/150 passing)
**Command**: `bundle exec rspec spec/jobs/`
- **Examples**: 150
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~15 seconds (14.59s)
- **Completed**: 2026-02-03 18:34:30

### ❌ Phase 7: Helper Specs (298/299 passing, 1 failure)
**Command**: `bundle exec rspec spec/helpers/`
- **Examples**: 299
- **Failures**: 1 ❌
- **Status**: 1 FAILURE
- **Duration**: ~21 seconds (21.06s)
- **Completed**: 2026-02-03 18:35:07
- **Failure**: `spec/helpers/organizations/public_maap_helper_spec.rb:31` — Organizations::PublicMaapHelper#build_organization_hierarchy excludes teams — expected [2, 3] not to include 2

### ✅ Phase 8: Form Specs (165/165 passing)
**Command**: `bundle exec rspec spec/forms/`
- **Examples**: 165
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~8 seconds (7.9s)
- **Completed**: 2026-02-03 18:35:34

### ✅ Phase 9: Decorator Specs (99/99 passing)
**Command**: `bundle exec rspec spec/decorators/`
- **Examples**: 99
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~4.5 seconds (4.46s)
- **Completed**: 2026-02-03 18:35:54

### ✅ Phase 10: Query Specs (332/332 passing)
**Command**: `bundle exec rspec spec/queries/`
- **Examples**: 332
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~60 seconds (59.84s)
- **Completed**: 2026-02-03 18:37:02

### ✅ Phase 11: Integration Specs (9/9 passing)
**Command**: `bundle exec rspec spec/integrations/`
- **Examples**: 9
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~0.9 seconds
- **Completed**: 2026-02-03 18:37:09

### ✅ Phase 12: Route Specs (34/34 passing)
**Command**: `bundle exec rspec spec/routes/`
- **Examples**: 34
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~0.8 seconds
- **Completed**: 2026-02-03 18:37:24

### ✅ Phase 13: View Specs (113/113 passing)
**Command**: `bundle exec rspec spec/views/`
- **Examples**: 113
- **Failures**: 0 ✅
- **Status**: ALL PASSING
- **Duration**: ~11 seconds (10.85s)
- **Completed**: 2026-02-03 18:38:04

---

## System Specs (each folder/file run separately)

### ✅ System: Abilities (2/2 passing)
**Command**: `bundle exec rspec spec/system/abilities/`
- **Examples**: 2
- **Failures**: 0 ✅
- **Duration**: ~14 seconds (14.13s)
- **Completed**: 2026-02-03 18:38:36

### ✅ System: Aspirations (7/7 passing, 5 pending)
**Command**: `bundle exec rspec spec/system/aspirations/`
- **Examples**: 7
- **Failures**: 0 ✅
- **Pending**: 5
- **Duration**: ~13 seconds (12.57s)
- **Completed**: 2026-02-03 18:39:04

### ✅ System: Assignments (2/2 passing)
**Command**: `bundle exec rspec spec/system/assignments/`
- **Examples**: 2
- **Failures**: 0 ✅
- **Duration**: ~14 seconds (14.01s)
- **Completed**: 2026-02-03 18:39:30

### ✅ System: Audit (3/3 passing, 3 pending)
**Command**: `bundle exec rspec spec/system/audit/`
- **Examples**: 3
- **Failures**: 0 ✅
- **Pending**: 3
- **Duration**: ~0.7 seconds
- **Completed**: 2026-02-03 18:39:36

### ✅ System: Check-in Observations (1/1 passing)
**Command**: `bundle exec rspec spec/system/check_in_observations/`
- **Examples**: 1
- **Failures**: 0 ✅
- **Duration**: ~36 seconds (36.42s)
- **Completed**: 2026-02-03 18:40:29

### ✅ System: Check-ins (14/14 passing, 13 pending)
**Command**: `bundle exec rspec spec/system/check_ins/`
- **Examples**: 14
- **Failures**: 0 ✅
- **Pending**: 13
- **Duration**: ~7 seconds (6.95s)
- **Completed**: 2026-02-03 18:40:42

### ✅ System: check_ins_save_and_redirect_spec.rb (2/2 passing)
**Command**: `bundle exec rspec spec/system/check_ins_save_and_redirect_spec.rb`
- **Examples**: 2
- **Failures**: 0 ✅
- **Duration**: ~7 seconds (6.74s)
- **Completed**: 2026-02-03 18:41:04

### ❌ System: Finalization (2/3 passing, 1 failure)
**Command**: `bundle exec rspec spec/system/finalization/`
- **Examples**: 3
- **Failures**: 1 ❌
- **Duration**: ~10 seconds (10.43s)
- **Completed**: 2026-02-03 18:41:27
- **Failure**: `finalization_complete_flow_spec.rb:145` — Manager view "manager finalizes one check-in and sees success" — unexpected alert open: "This row will not be saved if this stays unchecked"

### ✅ System: Get Shit Done (1/1 passing)
**Command**: `bundle exec rspec spec/system/get_shit_done/`
- **Examples**: 1
- **Failures**: 0 ✅
- **Duration**: ~5 seconds (4.66s)
- **Completed**: 2026-02-03 18:41:54

### ✅ System: Goals (57/57 passing, 8 pending)
**Command**: `bundle exec rspec spec/system/goals/`
- **Examples**: 57
- **Failures**: 0 ✅
- **Pending**: 8
- **Duration**: ~1m 47s (1m 46.97s)
- **Completed**: 2026-02-03 18:44:03

### ❌ System: Huddles (3/6 passing, 3 failures, 1 pending)
**Command**: `bundle exec rspec spec/system/huddles/`
- **Examples**: 6
- **Failures**: 3 ❌
- **Pending**: 1
- **Duration**: ~27 seconds (27.27s)
- **Completed**: 2026-02-03 18:44:30
- **Failures**: huddles_core_flow_spec.rb — "Start Huddle" button not found (not disabled) for company/department/team (lines 18, 52, 83)

### ❌ System: Misc (17/21 passing, 4 failures)
**Command**: `bundle exec rspec spec/system/misc/`
- **Examples**: 21
- **Failures**: 4 ❌
- **Duration**: ~1m 12s (1m 12.29s)
- **Completed**: 2026-02-03 18:45:42
- **Failures**: slack_integration_spec — Start Huddle button not found (2); Channel & Group edits kudos/group for department (2) — kudos_channel_id expectations

### ✅ System: Observable Moments (7/7 passing, 4 pending)
**Command**: `bundle exec rspec spec/system/observable_moments/`
- **Examples**: 7
- **Failures**: 0 ✅
- **Pending**: 4
- **Duration**: ~8 seconds (8.39s)
- **Completed**: 2026-02-03 18:46:38

### ✅ System: Observations (48/48 passing)
**Command**: `bundle exec rspec spec/system/observations/`
- **Examples**: 48
- **Failures**: 0 ✅
- **Duration**: ~2m 0s (2m 0.1s)
- **Completed**: 2026-02-03 18:49:08

### ✅ System: Organizations (30/30 passing)
**Command**: `bundle exec rspec spec/system/organizations/`
- **Examples**: 30
- **Failures**: 0 ✅
- **Duration**: ~1m 53s (1m 53.43s)
- **Completed**: 2026-02-03 18:51:22

### ✅ System: People (2/2 passing)
**Command**: `bundle exec rspec spec/system/people/`
- **Examples**: 2
- **Failures**: 0 ✅
- **Duration**: ~15 seconds (14.56s)
- **Completed**: 2026-02-03 18:51:49

### ✅ System: Positions and Seats (3/3 passing, 3 pending)
**Command**: `bundle exec rspec spec/system/positions_and_seats/`
- **Examples**: 3
- **Failures**: 0 ✅
- **Pending**: 3
- **Duration**: ~1.3 seconds
- **Completed**: 2026-02-03 18:52:22

### ✅ System: Teammates (3/3 passing, 3 pending)
**Command**: `bundle exec rspec spec/system/teammates/`
- **Examples**: 3
- **Failures**: 0 ✅
- **Pending**: 3
- **Duration**: ~1.4 seconds
- **Completed**: 2026-02-03 18:52:40

### ✅ System: teammate_profile_links_spec.rb (5/5 passing)
**Command**: `bundle exec rspec spec/system/teammate_profile_links_spec.rb`
- **Examples**: 5
- **Failures**: 0 ✅
- **Duration**: ~18 seconds (17.82s)
- **Completed**: 2026-02-03 18:52:58

### ❌ System: vertical_navigation_spec.rb (5/8 passing, 3 failures)
**Command**: `bundle exec rspec spec/system/vertical_navigation_spec.rb`
- **Examples**: 8
- **Failures**: 3 ❌
- **Duration**: ~22 seconds (22.46s)
- **Completed**: 2026-02-03 18:53:34
- **Failures**: vertical_navigation_spec.rb — invalid session id / browser closed (lines 15, 147, 154)

---

## Phase 14: ENM Specs

### ⏳ Phase 14: ENM Specs (Running...)
**Command**: `bundle exec rspec spec/enm/`
- **Started**: 2026-02-03 18:53:34

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

### Run Summary (2026-02-03 15:26–15:57)
- **Unit/Integration**: Model ✅, Controller ✅, Request ✅, Policy ✅, Service ✅, Job ✅, Helper ✅, Form ✅, Decorator ✅, Query ✅, Integration ✅, Route ✅, View ✅, ENM ✅ — **0 failures**
- **System**: Abilities ✅, Aspirations ✅, Assignments ✅, Audit ✅, Check-in Observations ✅, Check-ins ✅, Finalization ❌ (1), Get Shit Done ❌ (7), Goals ❌ (1), Huddles ❌ (3), Misc ❌ (4), Observable Moments ❌ (4), Observations ❌ (2), Organizations ✅, People ✅, Positions and Seats ✅, Teammates ✅, check_ins_save_and_redirect ✅, teammate_profile_links ✅, vertical_navigation ✅
- **Total failures this run**: **22** (all in system specs: Finalization 1, Get Shit Done 7, Goals 1, Huddles 3, Misc 4, Observable Moments 4, Observations 2)

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
