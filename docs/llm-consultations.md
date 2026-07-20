# LLM consultations architecture

Three layers separate **cost**, **billing**, and **typed product output**. New Bedrock-backed product features should follow this shape rather than inventing parallel run tables.

## Layers

| Layer | Model | Role |
|---|---|---|
| Cost ledger | `LlmInvocation` | Every Bedrock call: tokens, `cost_micros`, timing, optional ActiveStorage request/response payloads |
| Billable event | `OgConsultation` | One append-only product “consultation” (who/when/status/kind/subject); Value Billing counts completed + billable rows |
| Typed result | Kind-specific tables | Display/parsed output for that kind (e.g. `AbilityClarityResult`, `OgoSearchResult`) |

```text
Subject (Ability / Assignment / Transcript / Slack search batch / …)
  └── has_many OgConsultation (append-only; show UI uses latest for subject+kind)
        ├── belongs_to result (polymorphic → kind table)
        └── has_many LlmInvocation (parent)
```

## Hub: Consult OG to Find OGOs (`PossibleObservationConsult`)

Org-nav under Observations (OGO). Phase 2: paste/upload → confirm teammates → one multi-teammate `ogo_search_consult` → review → draft OGOs. Google Meet import is a later phase; old Meeting transcripts retirement is later still.

**Check-in entry:** Assignment / Aspiration / Ability 1-by-1 pages can start a 90-day Slack search with `auto_extract_after_search`, then poll progressive ≥80% object-matched candidates via `CheckIns::SlackOgoConsult`.
**Not billable consultations:** HR enrich/match and teammate resolve still go through `Llm::Client` (invocations only).

### Payloads

Full prompts/responses live on ActiveStorage (`request_payload` / `response_payload`) with browsable S3 keys under `llm_invocations/org_{id}/…`. Result tables hold UI-facing fields only (e.g. markdown `output_text`, ratings, recommendation JSON). Do not duplicate multi-hundred-KB prompts onto result rows.

### Progress / ETA

`units_total` / `units_completed` on `OgConsultation` track multi-step work (OGO search chunks). Single-call Consult OG uses `1` / `0→1`. Invocation `duration_ms` supports ETA later; do not mirror chunk counts on `OgoSearchResult`.

## Kind registry

[`OgConsultations::Kinds`](../app/services/og_consultations/kinds.rb) maps each kind string to:

- result class
- job class
- runner class (nil when the job orchestrates chunks itself)
- `llm_purpose` for `Llm::Client`
- billable flag + human label

Look up with `OgConsultations::Kinds.fetch(kind)` (or `result_class_for` / `job_class_for` / `runner_class_for`). Ability clarity is wired through the registry as the reference path.

## Insights

Organization Insights includes an **OG Consultations** page (`/insights/og_consultations`) for volume by kind over time, kind mix, top runners, and status counts. Labels come from `OgConsultations::Kinds`.

## Wait / ETA polling

In-flight Consult OG and OGO search wait banners share `shared/og_consultations/status_banner` + Stimulus `og-consultation-status-poll`:

- elapsed count-up from status JSON
- **Last checked** formatted in the viewer’s profile timezone (IANA via `TimezoneService.iana_identifier`)
- ETA from `OgConsultations::EtaEstimator`: a **stable** `estimated_duration_seconds` (units × median unit duration, or median full-run wall time). The banner shows remaining as `max(0, estimate − elapsed)` so the countdown tracks elapsed without jumping on each poll. Cold start shows `Estimating…`. When remaining hits zero before completion: `Almost done…`.

## How to add a kind

1. Add `KIND_*` on `OgConsultation` and a row in `OgConsultations::Kinds::REGISTRY`.
2. Migration for the result table + model (`belongs_to :og_consultation`).
3. Job (+ runner if single-shot) that:
   - creates `OgConsultation` + result, sets `result` polymorphic
   - calls `Llm::Client` with `parent: consultation` and registry `llm_purpose`
   - completes/fails the consultation; bumps `units_completed` for multi-unit kinds
4. Controller/CTA + show page loading `OgConsultation.latest_for(subject:, kind:)`.
5. Specs for create → complete and Value Billing inclusion if `billable: true`.
6. Bump prompt version per [prompt-versioning](./RULES/prompt-versioning.md) when changing prompts.

## Shared entrypoint

All Bedrock calls go through `Llm::Client` (`Llm::BedrockPricing` + `Llm::BedrockCostCalculator`). Prefer parenting invocations on the consultation when the call is part of a billable run.
