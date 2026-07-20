# OGO creation attribution

How to record **where an Observation came from** and **who excavated it**, without growing provider-specific foreign keys on `observations`.

## Do not add provider FKs on Observation

Do **not** add columns like:

- `possible_observation_slack_search_id`
- `possible_observation_zoom_search_id`
- `possible_observation_google_meet_search_id`
- …one per “Source from X” provider

Those belong on typed **run** tables (`PossibleObservationSlackSearch`, future Zoom/Meet siblings), not on every Observation row.

## What belongs on Observation

| Field / association | Purpose |
|---|---|
| `observer` (Person) | Who “said” the OGO (Slack speaker, FR responder, etc.) |
| `creator_company_teammate` | Who excavated / logged it (may differ from observer) |
| `company` | Tenant |
| `observation_trigger` | Generic provenance for external/source events |
| `observable_moment` / `feedback_request_question` | Existing first-class product sources (moments, FR answers) — not the “search from X” family |
| `goal` | Optional content link |
| `observees` / `observation_ratings` | Subjects and ratings (joins) |

`created_as_type` may record entry style (e.g. `slack_source`) for analytics; it is not a substitute for trigger provenance.

## Source-from-X (Slack, Zoom, Meet, …) and hub paste/upload

Use **`ObservationTrigger`**:

```ruby
ObservationTrigger.create!(
  trigger_source: "slack",           # or "zoom", "google_meet", "ogo_consult", …
  trigger_type: "ogo_source_search", # shared type for Find-Missing-OGOs-style excavation
  trigger_data: {
    # provider-specific keys…
    "possible_observation_slack_search_id" => 123,   # Slack run
    # or:
    "possible_observation_consult_id" => 456,        # hub paste/upload consult
    "extraction_item_id" => "uuid"
  }
)
```

Hub entry: **Consult OG to Find OGOs** (`PossibleObservationConsult`) — paste/upload/Zoom transcript import (Meet Coming soon), confirm teammates, one multi-teammate consultation, draft OGOs. Meet/Zoom provenance lives on `source_metadata` and is copied into `ObservationTrigger.trigger_data` when promoting.

Then set `observation.observation_trigger = trigger`.

### Soft-duplicate detection

Match on `trigger_source` + stable message/moment keys in `trigger_data` (e.g. Slack `channel_id` + `message_ts`). Do not require a column on `observations`.

### UI / helpers

- Resolve the Slack run with `observation.source_slack_search` (reads trigger_data; no FK).
- Prefer permalink + Source-from-X page links in the UI; keep raw IDs in a tooltip (`ObservationTrigger#tooltip_trigger_data_html`).

## When to add a polymorphic `source` later

Only if joins/reporting against run tables become painful. Until a second provider exists and needs real SQL joins, **trigger jsonb is enough**.

## History note

Phase 5 briefly added `observations.possible_observation_slack_search_id`. It was removed in favor of trigger-only attribution so Zoom/Meet/etc. do not copy a bad pattern.
