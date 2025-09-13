# Mission-Hypothesis Framework - Entity Relationship Diagram

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
                                        │ 1:N
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
                                        │
                                        │ N:1
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
                                        │ 1:1
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           OUTCOME_ACHIEVEMENTS                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│ PK: id                                                                          │
│     outcome_id (bigint) → outcomes.id                                          │
│     reporter_id (bigint) → people.id                                           │
│     status (string) - "hit" | "miss" | "partial"                               │
│     proof_of_completion (text)                                                  │
│     achieved_at (date)                                                          │
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
                                        │ N:M
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          HYPOTHESIS_CONDITIONS                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│ PK: id                                                                          │
│     hypothesis_id (bigint) → hypotheses.id                                     │
│     condition_id (bigint) → conditions.id                                       │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        │ N:1
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                               CONDITIONS                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│ PK: id                                                                          │
│     description (text) - "If I do X..."                                        │
│     condition_type (string) - "activity" | "output" | "outcome"                 │
│     owner_type (string) - "Person" | "Organization"                             │
│     owner_id (bigint)                                                           │
│     created_by_id (bigint) → people.id                                         │
│     updated_by_id (bigint) → people.id                                         │
│     deleted_at (datetime)                                                      │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        │ 1:N
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           HYPOTHESIS_TEMPLATES                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│ PK: id                                                                          │
│     name (string) - "Learning Hypothesis"                                      │
│     description (text)                                                         │
│     condition_template (text)                                                  │
│     outcome_template (text)                                                     │
│     condition_type (string)                                                    │
│     outcome_type (string)                                                       │
│     owner_type (string) - "Person" | "Organization"                            │
│     owner_id (bigint)                                                           │
│     is_public (boolean)                                                        │
│     created_by_id (bigint) → people.id                                        │
│     updated_by_id (bigint) → people.id                                         │
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
└─────────────────┘    └─────────────────┘
         │                       │
         │ hypothesis_outcomes   │ hypothesis_outcomes
         ▼                       ▼
┌─────────────────────────────────────────────────┐
│              HYPOTHESIS                        │
│ "React Mastery Hypothesis"                     │
│                                                │
│ Primary Reporter: John                         │
│ Target Date: 2024-03-15                        │
│ Status: Active                                 │
└─────────────────────────────────────────────────┘
         │
         │ hypothesis_conditions
         ▼
┌─────────────────┐
│   CONDITION     │
│ "If I complete  │
│ React Advanced  │
│ course"         │
└─────────────────┘
```

## Key Relationships Summary

1. **Mission** → **Outcome** (through outcome_connections)
2. **Hypothesis** → **Condition** (many-to-many)
3. **Hypothesis** → **Outcome** (many-to-many)
4. **Outcome** → **Mission** or **Hypothesis** (through outcome_connections)
5. **Outcome** → **Confidence Ratings** (weekly tracking)
6. **Outcome** → **Achievement** (hit/miss tracking)
7. **Outcome** → **OurGruuv Tables** (milestones, assignments, positions, aspirations)
