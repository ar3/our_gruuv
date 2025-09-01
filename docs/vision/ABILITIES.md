# ABILITIES Vision Board

The Abilities system enables organizations to define, track, and certify skills, knowledge, and behaviors needed for assignments and career growth. It provides a framework for professional development that transcends organizational boundaries.

## DONE ✅

### **Waypoint 1: Ability Foundation** ✅
**Completed**: Core ability management system with organization scoping and versioning

**Key Results Achieved:**
1. **Ability model with organization scope** - Abilities belong to organizations, managed by MAAP permissions
2. **Versioning system** - Track ability evolution with semantic versioning and audit trail
3. **Basic CRUD operations** - Create, read, update, delete abilities with proper authorization
4. **MAAP integration** - Only users with can_manage_maap can create/modify abilities

### **Waypoint 2: Assignment-Ability Association** ✅
**Completed**: Connect abilities to assignments with milestone requirements

**Key Results Achieved:**
1. **Many-to-many relationship** - Assignments can require multiple abilities at different milestone levels
2. **Milestone requirement specification** - Define which milestone level is needed for each ability
3. **Organization scoping validation** - Ensure assignments and abilities belong to same organization
4. **Assignment validation** - Prevent assignment creation without required abilities

### **Waypoint 4: Milestone System** ✅
**Completed**: Implement milestone attainment with evidence tracking

**Key Results Achieved:**
1. **Milestone descriptions** - Text attributes on Ability model for each milestone level (1-5)
2. **PersonMilestone model** - Track when people achieve specific milestone levels for abilities
3. **Certification workflow** - Record who certified what and when with audit trail
4. **Convenience methods** - Easy management of milestone attainments and queries

## DOING 🔄

### **Waypoint 3: Job Description Generation System** 🔄
**Next**: Create comprehensive job description system with dedicated pages and views

**Key Results:**
1. **Position Job Description** - Default job description for positions
2. **Seat Job Description** - Job requisition with HR metadata
3. **Person Job Description** - Individual job description based on assignments and milestones
4. **Eligibility Analysis** - Gap analysis for position requirements

**Status**: 🚧 In Progress

#### Phase 1: Position Show Page & Job Description View ✅ Completed
- Updated position show page to use new layout with action switching
- Created management view (existing functionality)
- Created job description view with both existing UI and template format
- Added milestone level display helper (Demonstrated, Advanced, Expert, Coach, Industry-Recognized)
- Removed text-based job description generator in favor of dedicated pages

#### Phase 2: Seat Concept & Model 🚧 Next
- **Seat Model**: Job requisition with HR metadata
  - States: Archived, Filled, Open, Draft
  - References in EmploymentTenure model
  - Goal: No active tenure missing seat, no seat missing tenure
- **Seat Attributes**: Based on template (need to define)
- **Seat View**: Mirror template structure

#### Phase 3: Person Job Description View 🚧 Planned
- **Teammate View**: Show job description powered by assignments/abilities
- **Eligibility View**: Same permissions as management view
  - Show current position gaps
  - Allow position selection for gap analysis
  - Report: "To be X.X of <Position Type> you need Assignments A,B,C and Milestones D,E,F"

#### Phase 4: Position Eligibility Simulator 🚧 Planned
- **Wizard Flow**:
  1. Select position
  2. Choose additional assignments (beyond required)
  3. Assess milestone levels across all required abilities
  4. Gap analysis showing apprentice vs. full status eligibility
- **Features**: 
  - Current position analysis
  - New position exploration
  - Anonymous usage (may merge with eligibility view)

**Questions for Implementation**:
- **Policies**: Who can access what views? (HR, managers, employees, public?)
- **Seat Attributes**: What specific metadata fields from template?
- **View Permissions**: Different access levels for different job description types?
- **Eligibility Simulator**: Should this be a separate feature or integrated with existing views?

## WAYPOINTS 📋

### **Waypoint 1: Ability Foundation** (2-3 commits)
**Objective**: Create the core ability management system with organization scoping and versioning

**Key Results:**
1. **Ability model with organization scope** - Abilities belong to organizations, managed by MAAP permissions
2. **Versioning system** - Track ability evolution with semantic versioning and audit trail
3. **Basic CRUD operations** - Create, read, update, delete abilities with proper authorization
4. **MAAP integration** - Only users with can_manage_maap can create/modify abilities

**Deliverable**: Functional ability management interface with versioning
**Commit**: "feat: implement ability foundation with organization scoping and versioning"

### **Waypoint 2: Assignment-Ability Association** ✅ (2-3 commits)
**Objective**: Connect abilities to assignments with milestone requirements

**Key Results:**
1. **Many-to-many relationship** - Assignments can require multiple abilities at different milestone levels
2. **Milestone requirement specification** - Define which milestone level is needed for each ability
3. **Organization scoping validation** - Ensure assignments and abilities belong to same organization
4. **Assignment validation** - Prevent assignment creation without required abilities

**Deliverable**: Assignment-ability association system with milestone requirements
**Commit**: "feat: connect assignments to abilities with milestone requirements"

### **Waypoint 3: Job Description Generation** 🔄 (2-3 commits)
**Objective**: Generate job descriptions from ability requirements and milestone attainments

**Key Results:**
1. **Generic job descriptions** - Generate from position ability requirements
2. **Unique job descriptions** - Generate from person milestone attainments
3. **Apprentice vs. full status** - Display logic based on milestone levels
4. **Growth gap analysis** - Show what milestones needed for next level

**Deliverable**: Dynamic job description generation system
**Commit**: "feat: generate job descriptions from abilities and milestones"

### **Waypoint 4: Milestone System** ✅ (2-3 commits)
**Objective**: Implement milestone attainment with evidence tracking

**Key Results:**
1. **Milestone descriptions** - Text attributes on Ability model for each milestone level
2. **PersonMilestone model** - Track when people achieve specific milestone levels
3. **Certification workflow** - Record who certified what and when
4. **Audit trail** - Complete tracking of milestone attainment history

**Deliverable**: Complete milestone attainment system with evidence tracking
**Commit**: "feat: implement milestone system with evidence and certification"

### **Waypoint 5: Observation System** (2-3 commits)
**Objective**: Build 360-degree, 365-day observation system

**Key Results:**
1. **Observation model** - 5-point Likert scale (strongly_agree to strongly_disagree)
2. **Association system** - Link observations to abilities, assignments, aspirations
3. **Feedback integration** - Both positive recognition and constructive feedback
4. **Natural habit formation** - Make observations part of daily workflow

**Deliverable**: Comprehensive observation and feedback system
**Commit**: "feat: implement 360-degree observation system with Likert scale"

### **Waypoint 6: Growth Plans** (2-3 commits)
**Objective**: Generate built-in promotion pathways and growth plans

**Key Results:**
1. **Promotion pathways** - Show what milestones needed for next level
2. **Gap analysis** - Identify current vs. required milestone levels
3. **Progress tracking** - Visual progress toward career goals
4. **Growth recommendations** - Suggest next steps for development

**Deliverable**: Automated growth plan generation and tracking
**Commit**: "feat: generate growth plans and promotion pathways"

## IMPLEMENTATION NOTES

### **Influenced by Medium Growth Framework**
- Based on [Medium's Engineering Growth Framework](https://medium.com/s/engineering-growth-framework/engineering-growth-assessing-progress-743620e70763)
- Uses 5 Cs: Conscious, Comfortable, Continuous, Consistent Competency
- Subjective assessment with objective examples
- Ongoing conversation model vs. annual reviews

### **Observation Scale**
- **strongly_agree** (Exceptional) - Green star icon
- **agree** (Good) - Thumbs up icon  
- **na** (N/A) - Eye slash icon
- **disagree** (Opportunity for Improvement) - Thumbs down icon
- **strongly_disagree** (Major Concern) - Times circle icon

### **Key Principles**
- Abilities are organization-scoped
- Milestones require evidence and certification
- Observations support but don't directly cause milestone attainment
- Job descriptions dynamically generated from ability requirements
- Growth plans show clear pathways to promotion

### **Technical Notes**
- PaperTrail metadata functionality deferred - basic versioning working, metadata needs investigation
- Semantic versioning implemented (major.minor.patch)
- Organization scoping and MAAP permissions enforced
