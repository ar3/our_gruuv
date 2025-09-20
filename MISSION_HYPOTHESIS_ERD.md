# Mission-Hypothesis Framework - Entity Relationship Diagram (Simplified)

## Core Entities and Relationships

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                MISSIONS                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│ PK: id                                                                          │
│     statement (string) - "We pursue a world where..."                          │
│     description (text)                                                          │
│     version (string) - "1.0.0"                                                 │
│     owner_type (string) - "Person" | "Organization"                             │
│     owner_id (bigint)                                                           │
│     created_by_id (bigint) → people.id                                          │
│     updated_by_id (bigint) → people.id                                         │
│     deleted_at (datetime)                                                      │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        │ outcome_connections
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                OUTCOMES                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│ PK: id                                                                          │
│     description (text) - "Then Y will happen..."                              │
│     outcome_type (string) - "easier" | "achieved" | "closer" | "milestone" |   │
│                            "assignment" | "position" | "aspiration"            │
│     owner_type (string) - "Person" | "Organization"                            │
│     owner_id (bigint)                                                           │
│     achievement_status (string) - "pending" | "hit" | "miss" | "partial"        │
│     proof_of_completion (text)                                                  │
│     achieved_at (date)                                                          │
│     achieved_by_id (bigint) → people.id                                        │
│     created_by_id (bigint) → people.id                                          │
│     updated_by_id (bigint) → people.id                                         │
│     deleted_at (datetime)                                                      │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        │ 1:N
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         OUTCOME_CONFIDENCE_RATINGS                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│ PK: id                                                                          │
│     outcome_id (bigint) → outcomes.id                                          │
│     reporter_id (bigint) → people.id                                           │
│     confidence_percentage (integer) - 0-100                                    │
│     rating_date (date) - Monday of the week                                    │
│     notes (text)                                                               │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        │ N:M
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            HYPOTHESIS_OUTCOMES                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│ PK: id                                                                          │
│     hypothesis_id (bigint) → hypotheses.id                                     │
│     outcome_id (bigint) → outcomes.id                                          │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        │ N:1
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              HYPOTHESES                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│ PK: id                                                                          │
│     title (string) - "React Mastery Hypothesis"                                │
│     description (text)                                                         │
│     condition_description (text) - "If I do X..."                             │
│     owner_type (string) - "Person" | "Organization"                            │
│     owner_id (bigint)                                                           │
│     primary_reporter_id (bigint) → people.id                                  │
│     backup_reporter_id (bigint) → people.id                                   │
│     target_completion_date (date)                                              │
│     activated_at (datetime)                                                     │
│     paused_at (datetime)                                                        │
│     completed_at (datetime)                                                     │
│     archived_at (datetime)                                                      │
│     created_by_id (bigint) → people.id                                        │
│     updated_by_id (bigint) → people.id                                         │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        │ outcome_connections
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              OUTCOME_CONNECTIONS                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│ PK: id                                                                          │
│     outcome_id (bigint) → outcomes.id                                          │
│     connected_type (string) - "Mission" | "Hypothesis"                           │
│     connected_id (bigint)                                                       │
│     mission_version (string) - version when connected                           │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Integration with Existing OurGruuv Tables

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              EXISTING TABLES                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐             │
│  │   ABILITIES     │    │  ASSIGNMENTS    │    │   POSITIONS     │             │
│  │                 │    │                 │    │                 │             │
│  │ • name          │    │ • title         │    │ • position_type │             │
│  │ • milestones    │    │ • handbook      │    │ • position_level │             │
│  │ • organization   │    │ • company       │    │ • summary       │             │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘             │
│           │                       │                       │                     │
│           │                       │                       │                     │
│           ▼                       ▼                       ▼                     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐             │
│  │PERSON_MILESTONES │    │ASSIGNMENT_TENURES│    │EMPLOYMENT_TENURES│             │
│  │                 │    │                 │    │                 │             │
│  │ • person_id     │    │ • person_id     │    │ • person_id     │             │
│  │ • ability_id    │    │ • assignment_id │    │ • position_id   │             │
│  │ • milestone_level│   │ • started_at    │    │ • started_at    │             │
│  │ • attained_at   │    │ • ended_at      │    │ • ended_at      │             │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘             │
│                                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                                   │
│  │   ASPIRATIONS   │    │ASSIGNMENT_CHECK_INS│                                  │
│  │                 │    │                 │                                   │
│  │ • name          │    │ • person_id     │                                   │
│  │ • description   │    │ • assignment_id │                                   │
│  │ • organization  │    │ • ratings       │                                   │
│  │ • sort_order    │    │ • notes         │                                   │
│  └─────────────────┘    └─────────────────┘                                   │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        │ Integration Points
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           OUTCOME TYPES                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  • milestone → connects to person_milestones                                    │
│  • assignment → connects to assignment_tenures                                  │
│  • position → connects to employment_tenures                                    │
│  • aspiration → connects to aspirations                                        │
│  • generic → user-defined outcomes                                              │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Visual Flow Example

```
┌─────────────────┐
│   MISSION       │
│ "We pursue a   │
│  world where    │
│  everyone       │
│  grows"         │
└─────────────────┘
         │
         │ outcome_connections
         ▼
┌─────────────────┐    ┌─────────────────┐
│   OUTCOME       │    │   OUTCOME       │
│ "Then I'll be   │    │ "Then I'll      │
│ closer to       │    │ understand      │
│ Senior Dev      │    │ React patterns" │
│ eligibility"    │    │                 │
│ Status: pending │    │ Status: pending │
└─────────────────┘    └─────────────────┘
         │                       │
         │ hypothesis_outcomes   │ hypothesis_outcomes
         ▼                       ▼
┌─────────────────────────────────────────────────┐
│              HYPOTHESIS                        │
│ "React Mastery Hypothesis"                     │
│                                                │
│ Condition: "If I complete React Advanced course"│
│ Primary Reporter: John                          │
│ Target Date: 2024-03-15                        │
│ Status: Active                                 │
└─────────────────────────────────────────────────┘
```

## Key Relationships Summary

1. **Mission** → **Outcome** (through outcome_connections)
2. **Hypothesis** → **Outcome** (many-to-many through hypothesis_outcomes)
3. **Outcome** → **Mission** or **Hypothesis** (through outcome_connections)
4. **Outcome** → **Confidence Ratings** (weekly tracking)
5. **Outcome** → **Achievement Status** (hit/miss tracking - stored on outcome)
6. **Outcome** → **OurGruuv Tables** (milestones, assignments, positions, aspirations)

## Key Simplifications Made

1. **Removed separate CONDITIONS table** - conditions are now stored as `condition_description` on hypotheses
2. **Moved achievement tracking to OUTCOMES table** - no separate outcome_achievements table
3. **Removed HYPOTHESIS_TEMPLATES table** - focus on core functionality first
4. **Simplified Mission-Outcome connection** - only outcomes connect to missions, not vice versa


