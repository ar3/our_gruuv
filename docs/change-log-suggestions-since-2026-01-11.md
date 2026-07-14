# Change Log Suggestions — since 2026-01-11

Draft entries for `/change_logs`, based on ~736 commits from **2026-01-11 → 2026-07-11**.

These are **candidates**, not a dump of every commit. Prefer shipping fewer, user-facing entries over logging refactors, cache work, or i18n renames.

---

## How change logs work in OurGruuv (match this)

| Field | Notes |
|--------|--------|
| `launched_on` | Display date (`July 11, 2026` style). Use roughly when the feature became usable, not the first WIP commit. |
| `change_type` | One of: `new_value`, `major_enhancement`, `minor_enhancement`, `bug_fix` |
| `description` | **Markdown only.** There is **no title field** — start with `## Headline`. |
| `image_url` | Optional. Upload via New Change Log form (S3 `change-logs/`), or paste a URL. Shown on index cards + show page. |

**Where they appear**

- Full index: `/change_logs`
- Also listed under **Help Improve OG** (`/interest`) as “Recent Changes”
- Admins create/edit at `/change_logs/new` (og_admin)

**Writing tips that match display**

1. Lead with `## Short headline` — that is the title users skim.
2. 1–3 short paragraphs max; bullets for “what / where / why.”
3. Prefer user language (Clarity Check-ins, 1:1 Hub, Healthy / Warning / Needs Attention) over internal names (`EngagementHealth`, caches).
4. Screenshots matter: index shows a left thumbnail; empty state is a placeholder. Aim for **one clear UI shot per entry**.
5. Spotlight on the index counts `change_type` for the last 90 days — mix types, but don’t invent bug_fix entries for every small fix.
6. Batch related work into one entry (e.g. “OG Health” not 20 cache commits).

**Screenshot capture tips (general)**

- Use a real org with enough data that bars/tables aren’t empty.
- Prefer desktop width (~1280–1440); crop chrome if needed but keep page header + primary content.
- Avoid PII when possible (use demo teammates / blur names if needed).
- Upload via the Change Log form’s **Upload Image** field (preferred over a random URL).

I cannot capture authenticated screenshots from here. For each entry below: **How to get the screenshot**.

---

## Suggested entries (priority order)

Rough launch dates are best-effort from commit history. Adjust to when you actually rolled each feature to users.

---

### 1. OG Health / Engagement Health (cross-app status language)

| | |
|--|--|
| **Suggested `launched_on`** | 2026-07-03 (core) → refine through 2026-07-11 |
| **`change_type`** | `new_value` |
| **Priority** | Highest — this is the spine of recent work |

**Suggested `description` (paste into form):**

```markdown
## OG Health: one status language across clarity, milestones, OGOs, and goals

We now track how "in the groove" someone is across four vectors — Clarity Check-ins, Ability Milestones, OGOs, and Goals — using a shared status: **Healthy**, **Warning**, and **Needs Attention**.

You’ll see this language on the OG Scorecard, Check-ins Health, Up Next, Manager Lite, and the 1:1 Overview. Banners and “what’s next” nudges use the same rules, so a teammate doesn’t look healthy on one page and at risk on another.
```

**How to get the screenshot**

1. Open a teammate’s **1:1 Hub → Overview**  
   Path pattern: `/organizations/:org_id/company_teammates/:id/one_on_one_link/overview`  
   Or: avatar menu → **My 1:1** (for yourself), then Overview.
2. Capture the Overview strip that shows Healthy / Warning / Needs Attention across the four vectors (and any summary bars under teammates if visible).
3. Optional second crop: **Insights → OG Scorecard** with red/yellow/green cells visible  
   Path: `/organizations/:org_id/insights/og_scorecard`  
   Nav: Insights (or equivalent) → OG Scorecard.

---

### 2. OG Scorecard

| | |
|--|--|
| **Suggested `launched_on`** | 2026-05-14 (introduced) → 2026-07-11 (health-aligned) |
| **`change_type`** | `new_value` |

**Suggested `description`:**

```markdown
## OG Scorecard

A weekly pulse on whether the organization is staying clear and engaged — Clarity Check-ins, Ability Milestones, Observations/OGOs, and Goals — with Healthy / Warning / Needs Attention coloring.

Filter by department or manager, switch timeframes, and (for admins) tune thresholds. Use it as the org-level companion to the per-teammate health views.
```

**How to get the screenshot**

1. Go to `/organizations/:org_id/insights/og_scorecard`.
2. Pick a timeframe with filled weeks (Last 90 days or Last Year).
3. Capture the metric table with colored weekly cells + a couple of row labels visible.
4. Tip: turn thresholds off for a cleaner marketing shot if the config panel clutters the frame.

---

### 3. Health dashboards (Check-ins, Observations, Goals)

| | |
|--|--|
| **Suggested `launched_on`** | ~2026-05-27 (Observations/OGO health) through mid-2026 for Check-ins Health polish |
| **`change_type`** | `major_enhancement` (or `new_value` if you never announced them) |

**Suggested `description`:**

```markdown
## Health dashboards for check-ins, observations, and goals

Three org-wide health views help leaders see who is fresh, who needs attention, and where to focus next:

- **Check-ins Health** — clarity / freshness across the org (and by manager)
- **Observations Health** — observation & OGO coverage
- **Goals Health** — goal engagement signals

Start Here and Manager Lite now lean on the same health thinking, so the “go do this” CTAs stay consistent.
```

**How to get the screenshot**

1. Nav → **Check-ins Health**: `/organizations/:org_id/check_ins_health`
2. Capture the main table/spotlight with status chips and at least one manager/employee row populated.
3. Optional: same framing on Observations Health (`/organizations/:org_id/observations_health`) or Goals Health (`/organizations/:org_id/goals_health`) if you want one entry per dashboard instead of a combined entry.

---

### 4. Opinionated 1:1 Hub + “The One Thing”

| | |
|--|--|
| **Suggested `launched_on`** | 2026-04-24 → 2026-04-25 (v1 carousel), refined through summer |
| **`change_type`** | `new_value` |

**Suggested `description`:**

```markdown
## 1:1 Hub with The One Thing

Your 1:1 page is now opinionated: it surfaces the single highest-leverage next conversation (“The One Thing”) and walks priorities with clear headers, tooltips, and deep links into the work (goals that need a check-in, feedback to give/get, reviews waiting, and more).

Profile navigation prioritizes **My 1:1** and **My Growth** over About Me so the growth conversation is one click closer.
```

**How to get the screenshot**

1. Open **My 1:1** from the user menu (or a report’s one_on_one_link show/overview).
2. Capture **The One Thing** / priority carousel with a real priority card expanded enough to read the header + link.
3. Good frame: carousel + first priority explanation, not the entire long page.

---

### 5. Work to Meet

| | |
|--|--|
| **Suggested `launched_on`** | 2026-05-29 |
| **`change_type`** | `new_value` |

**Suggested `description`:**

```markdown
## Work to Meet

A dedicated view for teammates whose assignments are **working to meet** expectations — so you can get real about coaching, goals, and OGOs in one place.

Includes distribution context (working to meet / meeting / exceeding) and OGO links where they help the conversation.
```

**How to get the screenshot**

1. Open a teammate’s 1:1 Hub → **Work to Meet**  
   Path: `/organizations/:org_id/company_teammates/:id/one_on_one_link/work_to_meet`
2. Prefer a teammate who has at least one WTM assignment so the table isn’t empty.
3. Capture the distribution graph (if shown) + the assignment table together if they fit; otherwise prioritize the table with status badges.

---

### 6. Clarity Check-ins as home + Up Next

| | |
|--|--|
| **Suggested `launched_on`** | 2026-05-24 / 2026-05-28 (Clarity naming + home), Up Next health-aligned ~2026-07 |
| **`change_type`** | `major_enhancement` |

**Suggested `description`:**

```markdown
## Clarity Check-ins, Up Next, and a smarter Start Here

“Check-in Hub” is now **Clarity Check-ins** everywhere. You can set Clarity Check-ins (or your 1:1) as your start page.

**Up Next** tells you the next clarity action with the same Healthy / Warning / Needs Attention language as OG Health. Start Here widgets highlight health pages and 1:1s so managers land on action, not archaeology.
```

**How to get the screenshot**

1. Open Clarity Check-ins hub for a teammate with pending items  
   (hub + Up Next: `/organizations/:org_id/company_teammates/:id/check_ins` and `.../check_ins/up_next`).
2. Capture **Up Next** with status/actions visible — best single shot for this entry.
3. Optional: **Start Here** (`/organizations/:org_id/start_here`) showing health / 1:1 widgets.

---

### 7. Notifications & digests overhaul

| | |
|--|--|
| **Suggested `launched_on`** | Digests ~2026-04-22; major UX 2026-06-12 |
| **`change_type`** | `major_enhancement` |

**Suggested `description`:**

```markdown
## Better notifications and digests

Notification settings are clearer and more configurable: choose what you get, see how digests are supposed to behave, and keep UI and delivery in sync.

Daily digests stay quiet when there’s nothing to say. Weekly digests and 1:1-related nudges are easier to find and understand from the teammate Notifications page.
```

**How to get the screenshot**

1. Open a teammate **Notifications** tab  
   Path: `/organizations/:org_id/company_teammates/:id/notifications`  
   (often via profile tabs on the teammate).
2. Capture the toggle sections (GSD / Interesting Things / digests) with labels readable — not the empty history table.
3. Tip: include the short page-help / intro copy in frame if it explains delivery time (8:00 AM / timezone).

---

### 8. My Growth (out of beta)

| | |
|--|--|
| **Suggested `launched_on`** | Beta 2026-03-26; out of beta ~2026-06-02 |
| **`change_type`** | `new_value` |

**Suggested `description`:**

```markdown
## My Growth

A focused place to drive growth conversations — experiences, abilities, goals, and position change — without digging through About Me.

My Growth and My 1:1 are now front-and-center in the profile menu. Bulk awarding and related growth flows are out of beta.
```

**How to get the screenshot**

1. User menu → **My Growth** (or teammate `my_growth/*` paths).
2. Capture the growth landing / experiences or abilities switcher with a teammate switcher visible.
3. Prefer a frame that shows the growth framing, not a blank empty state.

---

### 9. Assignment maps & accountability flow

| | |
|--|--|
| **Suggested `launched_on`** | ~2026-05-21–22 |
| **`change_type`** | `new_value` |

**Suggested `description`:**

```markdown
## Assignment maps and accountability flow

Visualize how assignments connect — on positions and across the full accountability flow — including saved layouts so you can revisit a map that makes sense for your team.

Use it when clarifying ownership, handoffs, and how work actually flows (not just how the hierarchy looks on paper).
```

**How to get the screenshot**

1. Open a **Position** that has assignment maps / network graph enabled  
   (routes include `full_network_graph` / accountability_flow graph kinds under positions).
2. Capture a zoomed graph with readable node labels (not a hairball).
3. If layout save UI is visible, a small inset showing “saved layout” is nice but optional — one clean graph shot is enough.

---

### 10. Bulk goal check-in & goal UX

| | |
|--|--|
| **Suggested `launched_on`** | Bulk goal check-in 2026-06-11; goals check-in / restricted-open earlier in spring |
| **`change_type`** | `major_enhancement` |

**Suggested `description`:**

```markdown
## Faster goal check-ins (including bulk)

Check in on goals without the one-at-a-time slog. Bulk goal check-in lets managers move a set of goals forward in one pass.

Goals also gained clearer headers, hierarchy sorting (including children), restricted vs open visibility, and safer date handling when you change the most-likely date.
```

**How to get the screenshot**

1. Find **bulk goal check-in** from the goals / grow-by-goals flows (manager context with multiple open goals).
2. Capture the multi-goal check-in UI with at least 2–3 goals listed and the primary action visible.
3. Alternate shot: goals index with hierarchy expand/collapse and status switcher if bulk UI is awkward to stage.

---

### 11. Modern multi-select UX (observees, observation add flows)

| | |
|--|--|
| **Suggested `launched_on`** | Plan/rollout from 2026-05-24; observation add flows ~2026-06-01 |
| **`change_type`** | `minor_enhancement` (or `major_enhancement` if you want to highlight the pattern) |

**Suggested `description`:**

```markdown
## Cleaner multi-select on assignment & observation flows

Selecting observees, assignments, abilities, and values uses a more modern selection pattern: search, selected pills you can remove, and less “checkbox sprawl.”

Manage observees and consumer-assignment style pages follow the same idea so bulk picks stay scannable.
```

**How to get the screenshot**

1. Open **Manage observees** (or add assignments/abilities/values on an observation) with several items selected so pills show.
2. Capture the search field + selected pills + list — that’s the whole story in one frame.
3. Avoid an empty select screen; the pills are the visual hook.

---

### 12. Sitemap / page search

| | |
|--|--|
| **Suggested `launched_on`** | 2026-06-12 |
| **`change_type`** | `minor_enhancement` |

**Suggested `description`:**

```markdown
## Sitemap: find any page fast

Lost in the app? Open the **Sitemap** (footer link) and search for pages by name. Handy when you remember the concept but not which menu hides it.
```

**How to get the screenshot**

1. Footer → **Sitemap** → `/organizations/:org_id/sitemap`
2. Type a search term that returns a few hits; capture the search box + results list.

---

### 13. Position ability milestones (clarity of required abilities)

| | |
|--|--|
| **Suggested `launched_on`** | 2026-02-11 (position milestones) → 2026-07-11 (required assignment abilities clarity) |
| **`change_type`** | `major_enhancement` |

**Suggested `description`:**

```markdown
## Clearer Ability Milestones on positions

Position ability milestones now make it obvious which **required assignment abilities** feed the milestone — so configuring growth paths and reading the OG Scorecard milestone row is less guesswork.

On-page help is available on the milestone configuration experience.
```

**How to get the screenshot**

1. Open a **Position → Ability Milestones** configuration that has required assignment abilities wired.
2. Capture the milestone config UI showing required abilities listed next to the milestone (click the page-help info icon if you want the help alert in frame — optional).
3. Alternate: OG Scorecard Ability Milestones row (from entry #2) if config screens are sparse.

---

### 14. Teammate feedback / OGOs page

| | |
|--|--|
| **Suggested `launched_on`** | 2026-06-08 |
| **`change_type`** | `major_enhancement` |

**Suggested `description`:**

```markdown
## Feedback requests & OGOs for the teammate

A clearer place for teammates to see feedback requests and OGOs — with links that take you straight to the OGO, not a scavenger hunt.
```

**How to get the screenshot**

1. Open teammate OGOs / feedback requests:  
   `/organizations/:org_id/company_teammates/:id/ogos/feedback_requests` (and related `ogos` / `ogos/from`).
2. Capture a list with at least one request/OGO row and a visible deep link.

---

### 15. Optional smaller / skip-or-batch entries

Use these only if you want denser history; otherwise fold into the entries above.

| Topic | Type | Suggested date | Screenshot path |
|--------|------|----------------|-----------------|
| Manager Lite promoting 1:1s + health CTAs | `minor_enhancement` | 2026-05–07 | Employees → Managers view → Manager Lite spotlight |
| Assignment energy / % meaning control on check-in finalize | `minor_enhancement` | 2026-06-02 | Finalize a check-in; capture the “what percentages mean” control |
| Sticky in-page nav on 1-by-1 check-ins | `minor_enhancement` | 2026-06-01 | Mid-scroll on a long 1-by-1 check-in page |
| Skip silent observations | `minor_enhancement` | 2026-05-07 | Observation create / silent flow with skip |
| Celebration automation (birthday / anniversary) | `new_value` | 2026-02-09 | Only if there’s a settings UI worth showing |
| AI observation transcripts / MAAP clarity consults | `new_value` | 2026-04–05 | Only if you want to announce AI publicly |
| Performance / cache work | — | — | **Skip** for change logs |
| Pure bug fixes / CSRF / digest send bugs | `bug_fix` | as needed | Only if users felt the pain publicly |

---

## Recommended publish set (keep it scannable)

If you only create **6–8** records, ship these:

1. OG Health (entry 1)  
2. OG Scorecard (2)  
3. Health dashboards (3)  
4. 1:1 Hub + One Thing (4)  
5. Work to Meet (5)  
6. Notifications & digests (7)  
7. My Growth (8)  
8. Clarity Check-ins / Up Next / Start Here (6) — or merge into (1) if you want fewer

Add 9–14 as capacity / storytelling needs allow.

---

## Admin checklist (create each entry)

1. Sign in as **og_admin**.
2. Go to `/change_logs/new` (or Change Logs → New).
3. Set **Launch Date** and **Change Type**.
4. Take the screenshot per instructions above → **Upload Image**.
5. Paste the Markdown `description` (keep the `##` headline).
6. Save → confirm it looks right on `/change_logs` and on `/interest` (“Recent Changes”).
7. Spot-check markdown: bold, bullets, and links render via Redcarpet.

---

## What we intentionally left out

- Internal refactors (check-in cache centralization, Scout/Sentry noise, naming refactors).
- Incomplete rollout notes from `docs/gruuv-health-rollout-plan.md` (e.g. Goals Health phase still open) — announce what’s **user-visible and stable**, not the roadmap.
- Uncommitted WIP on the current branch (About / ar3 pages, footer) until shipped.

---

## Quick reference — change_type badges

| Enum | UI label | Badge |
|------|----------|--------|
| `new_value` | New Value | primary |
| `major_enhancement` | Major Enhancement | success |
| `minor_enhancement` | Minor Enhancement | info |
| `bug_fix` | Bug Fix | warning |
