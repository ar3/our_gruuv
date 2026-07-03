# Gruuv Health rollout plan

**Status:** Phase 0 complete. **Next:** Phase 1 (OG Scorecard).

Centralize engagement signal status on **Healthy / At Risk / Needs Attention** via `EngagementHealth` (calculator, thresholds, cache, daily + event-driven refresh). Retire overlapping health logic in other dashboards as each phase completes.

**Canonical code:**
- `app/services/engagement_health.rb` (+ `thresholds`, `calculator`, `refresher`)
- `app/models/engagement_health_status.rb` — **live** current-state cache (Overview, in-progress scorecard week)
- `app/models/engagement_health_weekly_rollup.rb` — **historical** category rollups per completed Sunday (scorecard, insights trends)
- `app/jobs/engagement_health_refresh_job.rb`, `daily_refresh_engagement_health_statuses_job.rb`
- `app/jobs/engagement_health_weekly_rollup_backfill_job.rb`, `snapshot_engagement_health_weekly_rollups_job.rb`

**Vocabulary:** deliberately *not* on/off track (that language stays on goals for outcome trajectory).

**Per-teammate UI (Phase 0):** 1:1 Hub → Overview (`overview_organization_company_teammate_one_on_one_link_path`)

---

## Progress summary

| Phase | Focus | Status |
|-------|--------|--------|
| 0 | Foundation + Overview tab | ✅ Done |
| 1 | OG Scorecard | 🔄 In progress (1.1 done) |
| 2 | Observations Health | ⬜ |
| 3 | Required clarity / percentage clear | ⬜ |
| 4 | Goals Health | ⬜ |
| 5 | Milestones Health (+ migrate check-ins milestone bars) | ⬜ |
| 6 | Check-ins Health (remainder) | ⬜ |
| 7 | Insights pages | ⬜ |
| 8 | 1:1 system (One Thing, etc.) | ⬜ |
| 9 | Cleanup — retire old caches/jobs | ⬜ |

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

**Note:** EH calculator accepts `reference_time` for historical Sundays (OGO, goal confidence, required clarity). Milestone category still uses *current* tenure/position — see Phase 1.6 if historical milestone status is needed.

### 1.1 — Add Gruuv Health population row group

- [x] New metric group **"Gruuv Health"** in `MetricRegistry` (15 rows: 3 statuses × 5 categories)
- [x] Per category, count teammates whose **category rollup** is Healthy / At Risk / Needs Attention as of each Sunday
- [x] **Performance:** `engagement_health_weekly_rollups` table for completed weeks; live `engagement_health_statuses` for current week; on-demand backfill job + page notice when history is building
- [x] Wire into `OgScorecardBuilder` with same department/manager filters as existing metrics
- [x] Yellow/green thresholds work on new population counts (existing `CellStatus` UX)

### 1.2 — Required clarity trio → EH-backed + rename

- [ ] Replace `CheckInClarityWeekCounts` / `ClarityLevel` rollup with EH `required_clarity` category counts
- [ ] Rename rows to **Healthy / At Risk / Needs Attention** (replace clear / blurred / obscured labels)
- [ ] Update `MetricRegistry` labels and `og_scorecard_clarity_check_ins_help` locale copy
- [ ] Remove or deprecate duplicated clarity logic once EH path is verified

### 1.3 — OGO 30-day rows → EH scopes

- [ ] Align **OGO Given 30-day** count with `Observations::HealthScopes.given_scope` (matches EH healthy threshold + scope)
- [ ] Align **OGO Received 30-day** with `Observations::HealthScopes.received_scope` (privacy rules)
- [ ] Rename rows to reflect **Healthy** on OGO Given / Received (optional: drop 30-day rows if 1.1 EH rows supersede them)
- [ ] Fix scope gaps: `.not_journal`, org hierarchy, received privacy

### 1.4 — Relabel activity rows (no logic change)

- [ ] Group **Goal activity** separately from Gruuv Health (active goals, association breakdowns, check-ins this week, completed 90d)
- [ ] Group **Milestone activity** separately (earned this week / 90d — velocity, not compliance status)
- [ ] Group **OGO weekly activity** separately (publishers/observees in that Mon–Sun week)
- [ ] Update page help (`og_scorecard.html.haml` info panel) to explain status vs activity metrics
- [ ] Link to 1:1 Overview as per-teammate drill-down

### 1.5 — Optional EH rows for remaining categories

- [ ] **Goal Confidence** population counts (Healthy / At Risk / Needs Attention) — if not fully covered in 1.1
- [ ] **Milestones** population counts from EH — if not fully covered in 1.1 (may be point-in-time only until 1.6)

### 1.6 — Point-in-time tenure for historical milestones (if needed)

- [ ] Extend `EngagementHealth::Calculator` to resolve position/assignment tenures **as of `reference_time`**
- [ ] Enable accurate Sunday snapshots for Milestones category in scorecard history
- [ ] Specs for as-of-date milestone required-ability set

### 1.7 — Phase 1 verification

- [ ] Specs for new scorecard count services
- [ ] Manual compare: sample teammates on Overview vs scorecard population counts for same Sunday
- [ ] Document any intentional differences in page help

**Phase 1 retire (when complete):** `Insights::OgScorecard::CheckInClarityWeekCounts`, `ClarityLevel` (scorecard-only usage), duplicated OGO 30-day logic in `ObservationsThirtyDayWeekCounts` (if superseded)

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

- [ ] Clarity popovers (`_clarity_popover_table.html.haml`) → EH item rows + status labels
- [ ] Check-in hub / single-item check-in header health popovers
- [ ] `CheckIns::RequiredCheckInUrgencySort` — align sort keys with EH severity
- [ ] Eligibility requirements views that show clarity % — document mapping or migrate display

**Retire when done:** 4-level clarity as *status* in `check_in_health_caches.required_check_ins` payload; `ClarityLevel` in non-scorecard paths

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

**Retire when done:** `check_in_health_cache_builder` milestone section, `CheckInHealthService#milestone_health`

**Gate:** Approval before Phase 6.

---

## Phase 6 — Check-ins Health (remainder)

- [ ] Required clarity section → already EH from Phase 3 (verify integrated)
- [ ] Milestone section → already EH from Phase 5 (verify integrated)
- [ ] **Keep:** 7-category completion bars (in-progress / acknowledgment — not in EH)
- [ ] Legacy employees index `displays/_check_ins_health.html.haml` — migrate or remove
- [ ] `CheckInsHealthSpotlightService` — completion rate + EH clarity/milestones where applicable

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

- [ ] **One Thing** — `PriorityCarouselBuilder` priorities driven by EH item/category status (replace inline 30/60/90 checks)
- [ ] **Work to Meet** — evaluate; likely stays goal/OGO *presence* logic (separate from Gruuv Health status)
- [ ] **Detailed hub** — no health scoring changes expected
- [ ] Teammate OGO sub-pages observation health cards → EH or link to Overview

**Gate:** Approval before Phase 9.

---

## Phase 9 — Cleanup

- [ ] Remove `observation_health_caches` table/jobs if fully superseded (retain only if kudos/rating needs separate cache)
- [ ] Remove or slim `check_in_health_caches` to completion-only payload
- [ ] Remove unused services: `Observations::HealthRecency`, legacy `CheckInHealthService`, old goal health calculators
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
| Required Clarity | Check-ins Health `required_check_ins`, OG Scorecard clarity trio, clarity popovers |
| Milestones | Check-ins Health milestone bars, OG Scorecard milestone activity, Priority carousel |
| (Org activity only) | OG Scorecard weekly OGO, milestones earned, goal check-ins this week |

---

## Working agreement

Execute **one phase (or one Phase 1 sub-phase) per session** unless you ask to batch. After each:

1. Implement + specs
2. You manually test
3. Check off items in this doc
4. Explicit approval before the next phase/sub-phase
