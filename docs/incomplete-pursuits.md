# Incomplete pursuits

Work we built or started but left unfinished or disabled — usually blocked by external setup, not by missing product code. Revisit when the blocker is cleared.

## Meeting transcript auto-ingest (Google Meet & Zoom)

**Goal:** Per-user OAuth so [Consult OG to Find OGOs](./llm-consultations.md#hub-consult-og-to-find-ogos-possibleobservationconsult) can list and auto-import meeting transcripts (Google Meet organizer transcripts; Zoom hosted cloud-recording transcripts).

**Status:** Connect UI is **Coming soon**. Paste/upload on Consult OG New is the live path. Backend OAuth and import services remain in the codebase for re-enable.

Both providers hit **configuration / Marketplace OAuth issues**, not application-logic bugs in OurGruuv:

| Provider | What we built | What blocked live connect |
|----------|---------------|---------------------------|
| **Google Meet** | `google_meet` TeammateIdentity, Meet REST + Drive Meet-readonly scopes, list/download into `PossibleObservationConsult` | Sensitive/restricted scopes + consent/setup friction |
| **Zoom** | `zoom` TeammateIdentity, cloud recording list/download, redirect via ngrok | After Zoom login, Marketplace showed generic “Something went wrong” despite matching redirect URI + allow list (Development credentials, user-managed General app) |

**Re-enable when:** provider OAuth is verified end-to-end (local + production redirect/allow-list, Development vs Production credentials, required scopes, Local Test install).
