# Align--Accountability Vision

The Align--Accountability module houses concepts such as Aspirations (company, department, or team values/philosophies/ways of working), Assignments, and Abilities needed for Assignments. Employees should get extreme clarity about what they are being relied upon for when in this area.

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

### **Current OKR3: Job Description Generation System**
**Objective: Create comprehensive job description system with dedicated pages and views**

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

## DREAMING 💭

### **Aspirations & Values Management**
- **Company Values**: Define and track organizational values and philosophies
- **Department Philosophies**: Department-specific ways of working and cultural norms
- **Team Aspirations**: Team-level goals and aspirations that guide daily work
- **Values Alignment**: Track how assignments and abilities align with organizational values

### **Assignment Evolution**
- **Dynamic Assignment Creation**: AI-assisted assignment creation based on organizational needs
- **Assignment Templates**: Standardized assignment definitions across organizations
- **Assignment Dependencies**: Track how assignments relate to and depend on each other
- **Assignment Lifecycle**: Complete assignment lifecycle from creation to completion

### **Ability Framework Expansion**
- **Cross-Organization Abilities**: Share abilities across organizational boundaries
- **Ability Clusters**: Group related abilities for easier management and development
- **Ability Prerequisites**: Define ability dependencies and learning paths
- **Ability Marketplace**: Internal marketplace for ability development and sharing

### **Accountability Clarity Tools**
- **Role Clarity Dashboard**: Clear view of what each person is accountable for
- **Accountability Mapping**: Visual representation of accountability relationships
- **Responsibility Matrix**: RACI-style responsibility and accountability tracking
- **Accountability Reviews**: Regular reviews of accountability clarity and effectiveness

### **Advanced Features**
- **Predictive Analytics**: Predict assignment success based on ability levels
- **Automated Recommendations**: Suggest assignments based on ability gaps and interests
- **Accountability Scoring**: Quantify accountability clarity and effectiveness
- **Integration with Performance**: Link accountability with performance management systems

---

*This module provides the clarity and structure that enables employees to understand exactly what they are being relied upon for.*
