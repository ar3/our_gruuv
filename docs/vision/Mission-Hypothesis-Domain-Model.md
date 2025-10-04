# Mission-Hypothesis Framework Domain Model

## Core Philosophy
"Every hypothesis is a learning experiment" - This framework forces explicit causal thinking and creates natural learning loops.

## Database Tables

### 1. missions
```ruby
create_table "missions" do |t|
  t.string "statement", null: false                    # "We pursue a world where..."
  t.text "description"                                  # Optional elaboration
  t.string "version", default: "1.0.0", null: false   # Semantic versioning
  t.string "owner_type", null: false                    # "Person" or "Organization"
  t.bigint "owner_id", null: false                     # References person or organization
  t.bigint "created_by_id", null: false                # Person who created it
  t.bigint "updated_by_id", null: false                # Person who last updated it
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.datetime "deleted_at"                              # Soft delete

  t.index ["owner_type", "owner_id"], name: "index_missions_on_owner"
  t.index ["owner_type", "owner_id", "version"], name: "index_missions_on_owner_version"
  t.index ["created_by_id"], name: "index_missions_on_created_by_id"
  t.index ["updated_by_id"], name: "index_missions_on_updated_by_id"
  t.index ["deleted_at"], name: "index_missions_on_deleted_at"
end
```

### 2. hypotheses
```ruby
create_table "hypotheses" do |t|
  t.string "title", null: false                        # Human-readable title
  t.text "description"                                 # Optional elaboration
  t.string "owner_type", null: false                   # "Person" or "Organization"
  t.bigint "owner_id", null: false                    # References person or organization
  t.bigint "primary_reporter_id", null: false         # Person responsible for updates
  t.bigint "backup_reporter_id"                       # Optional backup reporter
  t.date "target_completion_date"                      # When hypothesis should be complete
  t.datetime "activated_at"                           # When hypothesis became active
  t.datetime "paused_at"                              # When hypothesis was paused
  t.datetime "completed_at"                           # When hypothesis was completed
  t.datetime "archived_at"                            # When hypothesis was archived
  t.bigint "created_by_id", null: false              # Person who created it
  t.bigint "updated_by_id", null: false              # Person who last updated it
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false

  t.index ["owner_type", "owner_id"], name: "index_hypotheses_on_owner"
  t.index ["primary_reporter_id"], name: "index_hypotheses_on_primary_reporter_id"
  t.index ["backup_reporter_id"], name: "index_hypotheses_on_backup_reporter_id"
  t.index ["target_completion_date"], name: "index_hypotheses_on_target_completion_date"
  t.index ["activated_at"], name: "index_hypotheses_on_activated_at"
  t.index ["paused_at"], name: "index_hypotheses_on_paused_at"
  t.index ["completed_at"], name: "index_hypotheses_on_completed_at"
  t.index ["archived_at"], name: "index_hypotheses_on_archived_at"
  t.index ["created_by_id"], name: "index_hypotheses_on_created_by_id"
  t.index ["updated_by_id"], name: "index_hypotheses_on_updated_by_id"
end
```

### 3. conditions
```ruby
create_table "conditions" do |t|
  t.text "description", null: false                   # "If I do X..."
  t.string "condition_type", null: false              # "activity", "output", "outcome"
  t.string "owner_type", null: false                  # "Person" or "Organization"
  t.bigint "owner_id", null: false                   # References person or organization
  t.bigint "created_by_id", null: false             # Person who created it
  t.bigint "updated_by_id", null: false              # Person who last updated it
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.datetime "deleted_at"                            # Soft delete

  t.index ["owner_type", "owner_id"], name: "index_conditions_on_owner"
  t.index ["condition_type"], name: "index_conditions_on_condition_type"
  t.index ["created_by_id"], name: "index_conditions_on_created_by_id"
  t.index ["updated_by_id"], name: "index_conditions_on_updated_by_id"
  t.index ["deleted_at"], name: "index_conditions_on_deleted_at"
end
```

### 4. outcomes
```ruby
create_table "outcomes" do |t|
  t.text "description", null: false                  # "Then Y will happen..."
  t.string "outcome_type", null: false               # "easier", "achieved", "closer", "milestone", "assignment", "position"
  t.string "owner_type", null: false                # "Person" or "Organization"
  t.bigint "owner_id", null: false                  # References person or organization
  t.bigint "created_by_id", null: false            # Person who created it
  t.bigint "updated_by_id", null: false            # Person who last updated it
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.datetime "deleted_at"                           # Soft delete

  t.index ["owner_type", "owner_id"], name: "index_outcomes_on_owner"
  t.index ["outcome_type"], name: "index_outcomes_on_outcome_type"
  t.index ["created_by_id"], name: "index_outcomes_on_created_by_id"
  t.index ["updated_by_id"], name: "index_outcomes_on_updated_by_id"
  t.index ["deleted_at"], name: "index_outcomes_on_deleted_at"
end
```

### 5. hypothesis_conditions (Many-to-Many)
```ruby
create_table "hypothesis_conditions" do |t|
  t.bigint "hypothesis_id", null: false
  t.bigint "condition_id", null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false

  t.index ["hypothesis_id", "condition_id"], name: "index_hypothesis_conditions_unique", unique: true
  t.index ["hypothesis_id"], name: "index_hypothesis_conditions_on_hypothesis_id"
  t.index ["condition_id"], name: "index_hypothesis_conditions_on_condition_id"
end
```

### 6. hypothesis_outcomes (Many-to-Many)
```ruby
create_table "hypothesis_outcomes" do |t|
  t.bigint "hypothesis_id", null: false
  t.bigint "outcome_id", null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false

  t.index ["hypothesis_id", "outcome_id"], name: "index_hypothesis_outcomes_unique", unique: true
  t.index ["hypothesis_id"], name: "index_hypothesis_outcomes_on_hypothesis_id"
  t.index ["outcome_id"], name: "index_hypothesis_outcomes_on_outcome_id"
end
```

### 7. outcome_connections (Connects outcomes to missions or other hypotheses)
```ruby
create_table "outcome_connections" do |t|
  t.bigint "outcome_id", null: false
  t.string "connected_type", null: false            # "Mission" or "Hypothesis"
  t.bigint "connected_id", null: false              # References mission or hypothesis
  t.string "mission_version"                        # Version of mission when connected
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false

  t.index ["outcome_id"], name: "index_outcome_connections_on_outcome_id"
  t.index ["connected_type", "connected_id"], name: "index_outcome_connections_on_connected"
  t.index ["outcome_id", "connected_type", "connected_id"], name: "index_outcome_connections_unique", unique: true
end
```

### 8. outcome_confidence_ratings (Weekly confidence tracking)
```ruby
create_table "outcome_confidence_ratings" do |t|
  t.bigint "outcome_id", null: false
  t.bigint "reporter_id", null: false               # Person reporting confidence
  t.integer "confidence_percentage", null: false   # 0-100
  t.date "rating_date", null: false                 # Monday of the week
  t.text "notes"                                    # Optional context
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false

  t.index ["outcome_id", "rating_date"], name: "index_outcome_confidence_ratings_unique", unique: true
  t.index ["outcome_id"], name: "index_outcome_confidence_ratings_on_outcome_id"
  t.index ["reporter_id"], name: "index_outcome_confidence_ratings_on_reporter_id"
  t.index ["rating_date"], name: "index_outcome_confidence_ratings_on_rating_date"
end
```

### 9. outcome_achievements (Hit/miss tracking)
```ruby
create_table "outcome_achievements" do |t|
  t.bigint "outcome_id", null: false
  t.bigint "reporter_id", null: false               # Person reporting achievement
  t.string "status", null: false                    # "hit", "miss", "partial"
  t.text "proof_of_completion"                      # Evidence/explanation
  t.date "achieved_at", null: false                 # When it was achieved
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false

  t.index ["outcome_id"], name: "index_outcome_achievements_on_outcome_id", unique: true
  t.index ["reporter_id"], name: "index_outcome_achievements_on_reporter_id"
  t.index ["achieved_at"], name: "index_outcome_achievements_on_achieved_at"
end
```

### 10. hypothesis_templates (Templates for common patterns)
```ruby
create_table "hypothesis_templates" do |t|
  t.string "name", null: false                      # "Learning Hypothesis", "Behavioral Hypothesis"
  t.text "description"                              # What this template is for
  t.text "condition_template"                      # Template for condition
  t.text "outcome_template"                        # Template for outcome
  t.string "condition_type", null: false           # "activity", "output", "outcome"
  t.string "outcome_type", null: false            # "easier", "achieved", "closer", etc.
  t.string "owner_type", null: false              # "Person" or "Organization"
  t.bigint "owner_id", null: false               # References person or organization
  t.boolean "is_public", default: false            # Can others use this template?
  t.bigint "created_by_id", null: false          # Person who created it
  t.bigint "updated_by_id", null: false          # Person who last updated it
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false

  t.index ["owner_type", "owner_id"], name: "index_hypothesis_templates_on_owner"
  t.index ["is_public"], name: "index_hypothesis_templates_on_is_public"
  t.index ["created_by_id"], name: "index_hypothesis_templates_on_created_by_id"
  t.index ["updated_by_id"], name: "index_hypothesis_templates_on_updated_by_id"
end
```

## Key Relationships

### Mission Relationships
- Mission belongs to Person or Organization (polymorphic)
- Mission has many OutcomeConnections
- Mission versions are tracked for hypothesis connections

### Hypothesis Relationships
- Hypothesis belongs to Person or Organization (polymorphic)
- Hypothesis has many Conditions (through hypothesis_conditions)
- Hypothesis has many Outcomes (through hypothesis_outcomes)
- Hypothesis has primary_reporter and optional backup_reporter

### Condition Relationships
- Condition belongs to Person or Organization (polymorphic)
- Condition has many Hypotheses (through hypothesis_conditions)
- Condition is complete when ALL its outcomes are complete

### Outcome Relationships
- Outcome belongs to Person or Organization (polymorphic)
- Outcome has many Hypotheses (through hypothesis_outcomes)
- Outcome can connect to Mission or other Hypothesis (through outcome_connections)
- Outcome has many ConfidenceRatings (weekly)
- Outcome has one Achievement record

## Business Rules

### 1. Condition Completion
- Conditions are complete when ALL their outcomes are complete
- This enforces outcome-focused thinking

### 2. Mission Versioning
- When missions change, show warnings on connected hypotheses
- "Still relevant" button updates hypothesis to latest mission version

### 3. Confidence Tracking
- Weekly confidence ratings starting Mondays
- Confidence stops mattering once outcome is achieved (hit/miss)
- Historical confidence data preserved for analysis

### 4. Hypothesis States
- Draft → Active → Paused/Completed → Archived
- States tracked with timestamp fields
- Validations prevent invalid state transitions

### 5. Circular Dependency Prevention
- Hypotheses can only connect to hypotheses that don't create circular dependencies
- System validates connection chains

## Integration Points

### OurGruuv System Integration
- **Milestone Outcomes**: Connect to person_milestones table
- **Assignment Outcomes**: Connect to assignment_tenures table  
- **Position Outcomes**: Connect to employment_tenures table

### External System Integration (Future)
- **Asana Projects**: Link hypotheses to Asana projects
- **Other PM Tools**: Extensible through third_party_objects pattern

## Growth Compass Visualization

### Bullseye Model
- **Inner Ring**: Hypotheses connected to missions (largest/most important)
- **Middle Ring**: Hypotheses connected to other hypotheses
- **Outer Ring**: Supporting hypotheses (unlimited depth)

### Dependency Visualization
- Arrows/lines showing connections between hypotheses
- Color coding for different outcome types
- Progress indicators for confidence trends

## Example Data

### Mission Example
```
statement: "We pursue a world where every team member continuously grows their skills"
description: "Learning and development is core to our culture"
version: "1.0.0"
owner_type: "Organization"
owner_id: 123
```

### Hypothesis Example
```
title: "React Mastery Hypothesis"
description: "Testing if advanced React training leads to senior developer eligibility"
owner_type: "Person"
owner_id: 456
primary_reporter_id: 456
target_completion_date: "2024-03-15"
```

### Condition Example
```
description: "If I complete React Advanced course"
condition_type: "activity"
owner_type: "Person"
owner_id: 456
```

### Outcome Example
```
description: "Then I'll be closer to Senior Developer eligibility"
outcome_type: "position"
owner_type: "Person"
owner_id: 456
```

### Outcome Connection Example
```
outcome_id: 789
connected_type: "Mission"
connected_id: 123
mission_version: "1.0.0"
```

## Benefits of This Design

### 1. Deep Simple
- **Simple**: Write if-then statements, add confidence, set timeframe
- **Deep**: Complex dependency webs, confidence calibration, mission alignment

### 2. Learning Oriented
- Every hypothesis is a learning experiment
- Failed hypotheses provide valuable data
- Confidence calibration improves over time

### 3. Flexible
- Many-to-many relationships allow complex webs
- Unlimited hypothesis chaining
- Configurable sharing levels

### 4. Trackable
- Weekly confidence updates
- Clear achievement tracking
- Mission alignment visibility

### 5. Extensible
- Template system for common patterns
- Integration points for external systems
- Versioned missions for evolution

