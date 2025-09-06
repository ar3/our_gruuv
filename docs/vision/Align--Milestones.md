# Align--Milestones Vision

The Align--Milestones module houses things related to growing accountability. This includes Observations (where your teammates give you 360-365 feedback), Certify and Recognize Milestone Achievements, and to review Eligibility for more/different accountability... "what do I need to demonstrate to show eligibility for a new ability milestone, a new Assignment, or ultimately a new Position".

## DONE ✅

### **Waypoint 4: Milestone System** ✅
**Completed**: Implement milestone attainment with evidence tracking

**Key Results Achieved:**
1. **Milestone descriptions** - Text attributes on Ability model for each milestone level (1-5)
2. **PersonMilestone model** - Track when people achieve specific milestone levels for abilities
3. **Certification workflow** - Record who certified what and when with audit trail
4. **Convenience methods** - Easy management of milestone attainments and queries

### **Milestone Level Display**
- ✅ Milestone level display helper (Demonstrated, Advanced, Expert, Coach, Industry-Recognized)
- ✅ 5-level competency certification with evidence tracking
- ✅ Audit trail for milestone attainment history

## DOING 🔄

### **Current OKR3: Observation System Development**
**Objective: Build 360-degree, 365-day observation system for continuous feedback**

**Key Results:**
1. **Observation model** - 5-point Likert scale (strongly_agree to strongly_disagree)
2. **Association system** - Link observations to abilities, assignments, aspirations
3. **Feedback integration** - Both positive recognition and constructive feedback
4. **Natural habit formation** - Make observations part of daily workflow

### **Current Sprint: Observation Foundation**
- [ ] Create Observation model with Likert scale ratings
- [ ] Build observation creation and management interface
- [ ] Implement observation association with abilities, assignments, aspirations
- [ ] Add observation display and filtering capabilities

### **Next Sprint: Certification Workflow**
- [ ] Build milestone certification interface
- [ ] Implement certification approval workflow
- [ ] Create certification history and audit trail
- [ ] Add certification notifications and reminders

### **Job Description Generation System** 🔄
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

## DREAMING 💭

### **360-Degree Observation System**
- **Continuous Feedback**: 365-day observation system with 5-point Likert scale
- **Observation Types**: 
  - Positive recognition for good work
  - Constructive feedback for improvement
  - Neutral observations for data collection
- **Association System**: Link observations to abilities, assignments, aspirations
- **Natural Habit Formation**: Make observations part of daily workflow

### **Milestone Achievement & Recognition**
- **Certification Workflow**: Complete milestone certification process
- **Recognition System**: Celebrate milestone achievements across the organization
- **Achievement Badges**: Visual recognition of milestone accomplishments
- **Progress Tracking**: Visual progress toward milestone goals

### **Eligibility Review System**
- **Eligibility Assessment**: "What do I need to demonstrate to show eligibility for..."
  - New ability milestone
  - New assignment
  - New position
- **Gap Analysis**: Identify what's needed vs. what's demonstrated
- **Development Planning**: Create development plans based on eligibility gaps
- **Eligibility Tracking**: Track progress toward eligibility requirements

### **Advanced Milestone Features**
- **Milestone Prerequisites**: Define milestone dependencies and learning paths
- **Milestone Clusters**: Group related milestones for easier management
- **Cross-Organization Milestones**: Share milestones across organizational boundaries
- **Milestone Marketplace**: Internal marketplace for milestone development and sharing

### **Observation Analytics**
- **Feedback Patterns**: Analyze observation patterns and trends
- **Recognition Balance**: Ensure balanced positive and constructive feedback
- **Observation Quality**: Track observation quality and consistency
- **Team Health Indicators**: Use observations to measure team health and effectiveness

### **Abilities & Skills Management**
- **Organization-Scoped Abilities**: Define skills, knowledge, and behaviors specific to each organization
- **Milestone Certification System**: 5-level competency certification with evidence tracking
- **Assignment-Ability Mapping**: Connect assignments to required abilities and milestone levels
- **Dynamic Job Descriptions**: Generate generic (position) and unique (person) job descriptions from ability requirements
- **Growth Plans**: Built-in promotion pathways showing required milestones for career advancement
- **360-Degree Observation System**: Continuous feedback system with 5-point Likert scale for abilities, assignments, and aspirations
- **Economic Point System**: Finite pool of acknowledgment points to prevent milestone inflation and gaming
- **Cross-Organization Inspiration**: "Inspired-by" associations between assignments, positions, abilities, and aspirations across organizations
- **Skill Atrophy Management**: System to acknowledge and address skill/knowledge decay over time
- **Advanced Observation Analytics**: Anti-spam and anti-favoritism systems for observation quality control
- **Comparison Views**: Compare employment patterns across similar roles or team members for insights

### **Implementation Notes**
- **Influenced by Medium Growth Framework**: Based on Medium's Engineering Growth Framework
- **Uses 5 Cs**: Conscious, Comfortable, Continuous, Consistent Competency
- **Subjective assessment with objective examples**
- **Ongoing conversation model vs. annual reviews**

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

### **Integration Possibilities**
- **Performance Management**: Link milestone achievements with performance reviews
- **Learning Management**: Connect milestone development with learning and development programs
- **Career Development**: Use milestone progress for career planning and development
- **Succession Planning**: Identify high-potential individuals based on milestone achievements

---

*This module provides the growth and development framework that enables employees to continuously improve their accountability and capabilities.*
