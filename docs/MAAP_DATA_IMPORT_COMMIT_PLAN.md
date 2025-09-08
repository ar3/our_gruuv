# MAAP Data Import Commit Plan

## Commit 2: MAAP Data Import Script

**Commit Message**: `feat: create MAAP data import script for production use`

**Summary**: 
- Build Rails runner script to parse `amy_maap.md` and create all necessary data
- Create all assignments, abilities, and position data from the job description
- Add Amy Campero and Natalie Morgan profiles with realistic data and proper relationships
- Create Growth & Development Manager position with all three levels (1, 2, 3) with same requirements for now
- Set assignment energy percentages based on time allocations (Employee Growth Plan Champion 30%, Quarterly Conversation Coordinator 20%, etc.)
- Ensure idempotent operation - skip existing data, update where appropriate
- Use CareerPlug organization, create if doesn't exist
- Include comprehensive error handling, progress output, and summary report
- Amy only has milestone levels for abilities explicitly specified in document (Communication Level 2, Executive Coaching Level 2)
- Assignments marked as Required/Optional based on document structure
- Script continues on errors with detailed error reporting in summary

## Technical Requirements

### Script Location & Execution
- **Location**: `lib/scripts/import_maap_data.rb`
- **Execution**: `rails runner lib/scripts/import_maap_data.rb`
- **Output**: Console progress and summary report

### Data to Import

#### Organizations
- Create "CareerPlug" organization if doesn't exist

#### People
- **Amy Campero**: Growth & Development Manager
- **Natalie Morgan**: Sr. Director People (Amy's manager)

#### Position Types & Levels
- **Position Type**: "Growth & Development Manager"
- **Position Levels**: 1, 2, 3 (all with same requirements for now)

#### Assignments (from amy_maap.md)
1. **Employee Growth Plan Champion** (30% time, Required)
   - Abilities: Executive Coaching, Learning & Development, Emotional Intelligence
2. **Quarterly Conversation Coordinator** (20% time, Required)
   - Abilities: Project Management, Communication, Data Insights
3. **Learning Librarian** (Required)
   - Abilities: Communication, Learning & Development, Data Insights
4. **Tooling Admin - CultureAmp** (Required)
   - Abilities: Communication, Tool Proficiency, Data Insights
5. **Lifeline Interview Facilitator** (Optional)
   - Abilities: Interviewing, Emotional Intelligence
6. **New Hire Onboarding Agent** (Optional)
   - Abilities: Training, Communication

#### Abilities (from amy_maap.md)
- Communication
- Executive Coaching
- Learning & Development
- Emotional Intelligence
- Project Management
- Data Insights
- Tool Proficiency
- Interviewing
- Training

#### Amy's Current Milestones
- Communication: Level 2
- Executive Coaching: Level 2

### Data Relationships
- Assignment-ability associations with milestone requirements
- Position-assignment associations with energy percentages
- Person-milestone records for Amy's current abilities
- Employment tenures for Amy and Natalie
- Assignment tenures for Amy's current assignments

### Error Handling
- Continue on errors with detailed error reporting
- Skip existing data (idempotent operation)
- Output progress as script runs
- Create comprehensive summary report

## Implementation Notes
- All models exist and are ready for use
- Script should be idempotent - can be run multiple times safely
- Use realistic data based on amy_maap.md content
- Follow Rails best practices for data import scripts
