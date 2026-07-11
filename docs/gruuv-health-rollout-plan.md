# Gruuv Health rollout plan

**Status:** Phase 0 complete. Phase 1.1–1.5 done (all five EH category population trios on the scorecard). Phase 3/6/8 partial. **Open leftovers:** item-healthy % aggregates; Phase 1.6 confirm / 1.7. **Next:** Phase 2 (Observations Health), or quick 1.6/1.7 closeout first.

Centralize engagement signal status on **Healthy / At Risk / Needs Attention** via `EngagementHealth` (calculator, thresholds, cache, daily + event-driven refresh). Retire overlapping health logic in other dashboards as each phase completes.

**Canonical code:**
- `app/services/engagement_health.rb` (+ `thresholds`, `calculator`, `refresher`)
- `app/models/engagement_health_status.rb` — **live** current-state cache (Overview, in-progress scorecard week)
- `app/models/engagement_health_weekly_rollup.rb` — **historical** category rollups per completed Sunday (scorecard, insights trends)
- `app/jobs/engagement_health_refresh_job.rb`, `daily_refresh_engagement_health_statuses_job.rb`
- `app/jobs/engagement_health_weekly_rollup_backfill_job.rb`, `snapshot_engagement_health_weekly_rollups_job.rb`

**Vocabulary:** deliberately *not* on/off track (that language stays on goals for outcome trajectory).

**Per-teammate UI (Phase 0):** 1:1 Hub → Overview (`overview_organization_company_teammate_one_on_one_link_path`)

**Canonical `% clear` UI:** `shared/clarity_action_slots/summary` + `EngagementHealth::ClarityActionMetrics` (action-slot math; hover = action-slot popover). Do not reintroduce `shared/clarity_popover_table` or item-healthy `%` as the per-teammate clear headline.

---

## Progress summary

| Phase | Focus | Status |
|-------|--------|--------|
| 0 | Foundation + Overview tab | ✅ Done |
| 1 | OG Scorecard | 🔄 In progress (1.1–1.5 done) |
| 2 | Observations Health | ⬜ |
| 3 | Required clarity / percentage clear | 🔄 In progress (action-slot `% clear` everywhere that used the old component) |
| 4 | Goals Health | ⬜ |
| 5 | Milestones Health (+ migrate check-ins milestone bars) | ⬜ |
| 6 | Check-ins Health (remainder) | 🔄 Style 2 + `CheckInHealthService` removed |
| 7 | Insights pages | ⬜ — dept `% healthy` still item-healthy math |
| 8 | 1:1 system (One Thing, hub next-up, etc.) | ✅ threshold alignment done (all-fresh, hub next-up, One Thing) |
| 9 | Cleanup — retire old caches/jobs | ⬜ |

### Open threshold-alignment leftovers (from required-clarity migration)

These still use 30/60/90 `clarity_level` / old green buckets and can disagree with Gruuv Health (Healthy = 60 days):

- [x] **One Thing / priority carousel** — `PriorityCarouselBuilder` + `RequiredCheckInUrgencySort` use EH Warning / Needs Attention (60/90), not blurred/obscured `clarity_level`
- [x] **All-fresh “100% clear” banner** — `CheckIns::AllFreshBannerService` uses EH Healthy (`REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS` = 60)
- [x] **Hub “next up” CTA** — `SingleItemCheckInNextItemService` urgency buckets map to EH Healthy / Warning / Needs Attention (60/90), not crystal-clear (30)

### Old `% clear` component retirement

**Deleted (ready / done):**
- [x] `shared/_clarity_popover_table.html.haml` + view spec
- [x] `ClarityMetrics.popover_table_data` / workflow popover helpers
- [x] Helper wrappers: `engagement_health_clarity_breakdown*`, `engagement_health_clarity_popover_table*`, `check_in_health_clarity_popover_caption`, `check_in_health_rate_text_class`
- [x] Terminology: `no_clarity_check_in_health_data`

**Migrated to action-slot summary (`shared/clarity_action_slots/summary`):**
- [x] Clarity check-in hub
- [x] Single-item check-in header switcher
- [x] Check-ins Health employee column + Manager Lite
- [x] Start Here check-in status / beta check-in history widgets
- [x] Start Here My Employees overall `% clear` (action-slot ok % across reports)

**Still using item-healthy % (not the deleted UI; track for Phase 3/7 cleanup):**
- [ ] Check-ins Health by Manager `completion_rate` / `% employees are healthy`
- [ ] Insights Check-ins Progress dept `completion_rate` / `% healthy`
- [ ] `CheckInsHealthEmployeeSummaryCsvBuilder` overall completion via `ClarityMetrics.breakdown`
- [ ] Keep `ClarityMetrics.breakdown` / `average_healthy_percentage_for_teammates` until those migrate or are explicitly kept as “% items healthy” (distinct from `% clear` action slots)

**Done recently (required clarity):**
- [x] Check-ins Health page + Start Here widget + action-slot `% clear` + Manager Lite `% clear`
- [x] Up Next status/actions from EH
- [x] About Me position/assignment/aspiration clarity icons + merge copy → EH status
- [x] Removed employees Check-ins Health Style 2 view/spotlight + `CheckInHealthService`
- [x] All-fresh banner → EH Healthy window
- [x] Retired old hub/header `% clear` + Employee/Manager/Together popover table

---

## Phase 0 — Foundation + Overview tab ✅

- [x] `engagement_health_statuses` table + model
- [x] `EngagementHealth::Thresholds`, `Calculator`, `Refresher` (single source of truth)
- [x] Event-driven refresh injected in services/controllers (no model callbacks)
- [x] Daily scheduled refresh (`DailyRefreshEngagementHealthStatusesJob`, `recurring.yml`)
- [x] 1:1 Hub → **Overview** tab (Gruuv Health spotlight, section detail, recalculate-now debug)
- [x] Status vocabulary: **Healthy / At Risk / Needs Attention**

---

## Phase 1 — OG Scorecard

**Goal:** Align org-level weekly scorecard with Gruuv Health where rows represent the same signals; keep activity/velocity rows separate.

**Key files:** `app/services/insights/og_scorecard_builder.rb`, `metric_registry.rb`, `check_in_clarity_week_counts.rb`, `observations_thirty_day_week_counts.rb`, `app/views/organizations/insights/og_scorecard.html.haml`

**Note:** EH calculator accepts `reference_time` for historical Sundays (OGO, goal confidence, required clarity, milestones via `ReferenceTime` tenure helpers). Phase 1.6 was originally written assuming milestones used *current* tenure — confirm that’s obsolete before spending a full sub-phase on it.

### 1.1 — Add Gruuv Health population row group

- [x] New metric group **"Gruuv Health"** in `MetricRegistry` (15 rows: 3 statuses × 5 categories)
- [x] Per category, count teammates whose **category rollup** is Healthy / At Risk / Needs Attention as of each Sunday
- [x] **Performance:** `engagement_health_weekly_rollups` table for completed weeks; live `engagement_health_statuses` for current week; on-demand backfill job + page notice when history is building
- [x] Wire into `OgScorecardBuilder` with same department/manager filters as existing metrics
- [x] Yellow/green thresholds work on new population counts (existing `CellStatus` UX)

### 1.2 — Required clarity trio → EH-backed + rename ✅

- [x] Replace `CheckInClarityWeekCounts` / `ClarityLevel` rollup with EH `required_clarity` category counts (`GruuvHealthWeekCounts`; old clear/blurred/obscured keys removed)
- [x] Rename rows to **Healthy / Warning / Needs Attention** (replaces clear / blurred / obscured)
- [x] Update `MetricRegistry` labels and `og_scorecard_clarity_check_ins_help` locale copy (activity vs status)
- [x] Remove duplicated clarity status logic (`ClarityLevel`, `CheckInClarityWeekCounts`); keep `ClarityCheckInWeekCounts` for activity-only this-week / all-time rows; prune stale threshold rows for retired metric keys

### 1.3 — OGO 30-day rows → EH scopes ✅

- [x] **OGO Given / Received Healthy** on the scorecard already use `Observations::HealthScopes` via EH category rollups (30-day Healthy window)
- [x] Dropped orphaned `ObservationsThirtyDayWeekCounts` (was not wired into MetricRegistry; superseded by Healthy rows)
- [x] Scorecard OGO activity this-week / all-time scopes aligned: `HealthScopes.published_non_journal_scope` (`.not_journal` + company ids)
- [x] `HealthScopes.company_ids_for` uses `self_and_descendants`; received privacy remains on EH Received (not activity “named as observee” rows); page help clarifies Healthy = 30-day signal

### 1.4 — Relabel activity rows (no logic change) ✅

- [x] Group **Goal activity** separately from Gruuv Health (activity first, then Goal Confidence EH)
- [x] Group **Milestone activity** separately (velocity rows under Activity, then EH Milestones)
- [x] Group **OGO weekly activity** separately (Activity label, then Gruuv Health Given/Received)
- [x] Update page help to explain status vs activity; link toward 1:1 Hub Overview drill-down via Managers View
- [x] Labeled `Activity` / `Gruuv Health` subsection separators in the scorecard table

### 1.5 — Optional EH rows for remaining categories ✅

- [x] **Goal Confidence** population counts — already covered in 1.1 (`gruuv_health_entries` under Goals → Gruuv Health); locked in registry + builder specs
- [x] **Milestones** population counts — already covered in 1.1 under Ability Milestones → Gruuv Health; locked in registry + builder specs
- [x] Page help: Goals locale notes Gruuv Health Goal Confidence matches Overview; Milestones help already did

**Note:** Calculator + weekly snapshotter already pass Sunday `reference_time` into milestone tenure resolution (`ReferenceTime` helpers). Phase 1.6 is likely already satisfied — confirm with a historical-week spot-check before skipping.
### 1.6 — Point-in-time tenure for historical milestones (if needed)

- [ ] Extend `EngagementHealth::Calculator` to resolve position/assignment tenures **as of `reference_time`**
- [ ] Enable accurate Sunday snapshots for Milestones category in scorecard history
- [ ] Specs for as-of-date milestone required-ability set

### 1.7 — Phase 1 verification

- [ ] Specs for new scorecard count services
- [ ] Manual compare: sample teammates on Overview vs scorecard population counts for same Sunday
- [ ] Document any intentional differences in page help

**Phase 1 retire (when complete):** scorecard-only `ClarityLevel` / `CheckInClarityWeekCounts` (**already removed**); `ObservationsThirtyDayWeekCounts` (**removed** — superseded by EH Healthy OGO Given/Received). Keep `ClarityCheckInWeekCounts` for check-in activity velocity rows.

**Gate:** Your approval before Phase 2.

---

## Phase 2 — Observations Health dashboard

- [ ] OGO Given / Received columns read from `engagement_health_statuses` (or EH calculator)
- [ ] Map display: Healthy / At Risk / Needs Attention (replace green/yellow/red + Stale/Never)
- [ ] CSV exports use new vocabulary
- [ ] `ObservationsHealthSpotlightService` uses EH category rollups
- [ ] Start Here widget (`insights_observations_health_widget`) aligned
- [ ] Teammate OGO pages (`_observation_health.html.haml`, `PriorityCarouselBuilder` OGO checks) — defer detailed work to Phase 8 if preferred

**Keep separate (not EH):** kudos mix, rating intensity bands

**Retire when done:** `Observations::HealthRecency` (2-tier OGO), OGO portion of `observation_health_caches` + related refresh for given/received only

**Gate:** Approval before Phase 3.

---

## Phase 3 — Required clarity / percentage clear

- [x] Clarity popovers (`_clarity_popover_table.html.haml`) → **deleted**; replaced by action-slot popover on hub/header/Check-ins Health / Manager Lite / Start Here
- [x] Check-in hub / single-item check-in header → `shared/clarity_action_slots/summary`
- [x] About Me check-in sections — clarity icons + merge messaging from EH Required Clarity
- [x] Start Here check-in status + My Employees overall `% clear` → action-slot math
- [x] `CheckIns::RequiredCheckInUrgencySort` — EH severity (Needs Attention → Warning → Healthy); legacy blurred/obscured keys still map
- [ ] Org aggregates still on item-healthy `%` (by-manager, Insights Check-ins Progress, employee summary CSV) — migrate to action slots or keep as explicit “% items healthy”

**Retire when done:** 4-level clarity as *status* in `check_in_health_caches.required_check_ins` payload; `ClarityLevel` in non-scorecard paths; `ClarityMetrics.breakdown` if no remaining consumers

**Gate:** Approval before Phase 4.

---

## Phase 4 — Goals Health dashboard

- [ ] Per-teammate rollup from EH `goal_confidence` category
- [ ] Replace 14-day week logic in `Goals::HealthStatusCalculator` for dashboard display
- [ ] `GoalsHealthSpotlightService` + compact partial aligned
- [ ] CSV exports updated
- [ ] `ManagersViewCardDataService` goals axis uses EH

**Retire when done:** `Goals::HealthStatusCalculator` / `Goals::HealthThresholds` for dashboard paths (keep goal on/off track pills on goal pages — different concept)

**Gate:** Approval before Phase 5.

---

## Phase 5 — Milestones Health page + check-ins milestone bars

- [ ] **New:** Milestones Health dashboard page (mirror Observations/Goals/Check-ins Health pattern)
- [ ] Per-teammate EH `milestones` category + ability item rows
- [ ] Migrate check-ins health milestone stacked bars to EH data
- [ ] Insights Abilities page — keep event counts; link to Milestones Health where appropriate

**Retire when done:** `check_in_health_cache_builder` milestone section (`CheckInHealthService#milestone_health` removed with Style 2)

**Gate:** Approval before Phase 6.

---

## Phase 6 — Check-ins Health (remainder)

- [x] Required clarity section → EH (bars, action slots, spotlight, Start Here widget)
- [ ] Milestone section → already EH from Phase 5 (verify integrated) — N/A on current Check-ins Health page (no milestone bars)
- [ ] **Keep:** 7-category completion bars (in-progress / acknowledgment — not in EH) — superseded by EH + action bars on dedicated page
- [x] Legacy employees index `displays/_check_ins_health.html.haml` — **removed** (Style 2)
- [x] `CheckInHealthService` — **removed** (only consumer was Style 2)
- [x] `CheckInsHealthSpotlightService` — EH clarity rollups + action-slot stats

**Retire when done:** overlapping portions of `check_in_health_caches`; evaluate whether full cache can shrink to completion-only

**Gate:** Approval before Phase 7.

---

## Phase 7 — Insights pages

- [ ] **Check-ins Progress** dept table → EH aggregates (required clarity + milestones)
- [ ] **Observations Insights** — keep culture ratios (kudos/ratings); not EH
- [ ] **Goals Insights** charts — link to Goals Health / EH; no duplicate threshold logic
- [ ] **Abilities Insights** — event-based milestone charts stay; cross-link Milestones Health

**Gate:** Approval before Phase 8.

---

## Phase 8 — 1:1 system

- [x] **One Thing** — `PriorityCarouselBuilder` priorities driven by EH Warning / Needs Attention (replace blurred/obscured `clarity_level`)
- [x] **All-fresh banner** — `CheckIns::AllFreshBannerService` / `_all_fresh_banner.html.haml` use EH Healthy (60d) instead of crystal-clear (30d)
- [x] **Hub next-up CTA** — `SingleItemCheckInNextItemService` urgency buckets use EH Healthy / Warning / Needs Attention (60/90) so hub “fully up to date” matches Up Next
- [ ] **Work to Meet** — evaluate; likely stays goal/OGO *presence* logic (separate from Gruuv Health status)
- [ ] **Detailed hub** — no health scoring changes expected
- [ ] Teammate OGO sub-pages observation health cards → EH or link to Overview

**Gate:** Approval before Phase 9.

---

## Phase 9 — Cleanup

- [ ] Remove `observation_health_caches` table/jobs if fully superseded (retain only if kudos/rating needs separate cache)
- [ ] Remove or slim `check_in_health_caches` to completion-only payload
- [ ] Remove unused services: `Observations::HealthRecency`, old goal health calculators (`CheckInHealthService` already removed)
- [ ] Consolidate spotlight services on EH vocabulary + shared aggregation helper
- [ ] Remove duplicate refresh scheduling where EH refresh covers the same events
- [ ] Update `docs/` and agent context so new work never reintroduces parallel threshold logic

**Done when:** No production UI reads parallel health definitions for the five Gruuv Health categories.

---

## Reference: five categories → legacy systems

| EH category | Primary legacy homes |
|-------------|----------------------|
| OGO Given / Received | Observations Health, OG Scorecard 30d OGO, Priority carousel |
| Goal Confidence | Goals Health (14d), OG Scorecard goal activity rows |
| Required Clarity | Check-ins Health `required_check_ins`, OG Scorecard clarity trio, action-slot `% clear` |
| Milestones | Check-ins Health milestone bars, OG Scorecard milestone activity, Priority carousel |
| (Org activity only) | OG Scorecard weekly OGO, milestones earned, goal check-ins this week |

---

## Working agreement

Execute **one phase (or one Phase 1 sub-phase) per session** unless you ask to batch. After each:

1. Implement + specs
2. You manually test
3. Check off items in this doc
4. Explicit approval before the next phase/sub-phase
