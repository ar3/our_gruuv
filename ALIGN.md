# Align

The Align module focuses on organizational structure, position management, and assignment tracking. It provides the foundation for understanding how work is organized and distributed within organizations.

## Overview

Align helps organizations structure their work by defining positions, roles, and assignments. It creates a clear hierarchy and accountability framework that supports both the Collaborate and Transform modules.

## Core Domain Objects

```mermaid
flowchart TD
    A[Organization:Company] --> B[Organization:Department]
    B --> C[Organization:Team]
    
    A --> D[Position Type]
    
    D --> E[Position Level]
    D --> F[Position]
    E --> F
    
    F --> G[Position Assignment]
    G --> H[Assignment]
    G --> J[External Reference]

    H --> I[Assignment Outcome]

    K[Person] --> L[Employment Tenure]
    L --> M[Company]
    L --> N[Position]
    
    N --> O[Assignment Tenure]
    O --> H
    O --> P[Assignment Check-in]
    
    P --> Q[Performance Rating]
    P --> R[Energy Spent %]
    P --> S[Assignment Satisfaction]
    P --> T[Manager Rating]
    
    style A fill:#e1f5fe
    style K fill:#e1f5fe
    style L fill:#f3e5f5
    style O fill:#f3e5f5
    style P fill:#fff3e0
    style F fill:#fff3e0
    style H fill:#fff3e0
```

### Organization Hierarchy
- **Company**: Top-level organization
- **Team**: Sub-organization within a company
- **Department**: Specialized team with specific focus

### Position Management
- **Position Type**: Defines a role (e.g., "Software Engineer", "Product Manager")
- **Position Level**: Seniority level within a position type (e.g., "Junior", "Senior", "Lead")
- **Position**: Specific combination of type and level

### Assignment System
- **Assignment**: A specific task, project, or responsibility
- **Position Assignment**: Links assignments to positions (required or suggested)
- **Assignment Outcome**: Measurable results or sentiment indicators
- **External Reference**: Links to external documentation or resources

### People-to-Assignment Connection (Future Vision)
- **Employment Tenure**: Time-based employment relationship between Person and Company/Position
- **Assignment Tenure**: Time-based assignment relationship between Person and Assignment
- **Assignment Check-in**: Periodic performance and satisfaction reviews
  - Performance Rating: Official assignment rating
  - Energy Spent %: Percentage of energy actually spent on assignment
  - Assignment Satisfaction: Does the assignment holder want this assignment
  - Manager Rating: How the manager rates the assignment holder's performance
- **Issue Provider**: External system integration (e.g., Asana) for escalating assignment concerns

## Key Features

### 1. Organizational Structure
- Hierarchical organization management
- Company > Team > Department structure
- Clear ownership and reporting relationships

### 2. Position Definition
- Flexible position type creation
- Multiple seniority levels per position type
- Company-specific position customization

### 3. Assignment Management
- Create and track assignments
- Link assignments to positions
- Define required vs suggested assignments
- Track outcomes and external references

### 4. Position Assignment
- Assign people to positions
- Track assignment history
- Support for temporary and permanent assignments

### 5. People-to-Assignment Connection (Planned)
- **Employment Tenure Tracking**: Track when people work for companies in specific positions
- **Assignment Tenure Management**: Track when people work on specific assignments
- **Performance Check-ins**: Regular reviews of assignment performance and satisfaction
- **Cross-Manager Reviews**: Allow sibling managers to review and calibrate ratings
- **Issue Escalation**: Drop issues to external systems (Asana) for assignment concerns
- **Data Migration**: Efficient import of existing employment and assignment data

## Data Flow

```mermaid
sequenceDiagram
    participant Admin
    participant Organization
    participant Position
    participant Assignment
    participant Person
    participant EmploymentTenure
    participant AssignmentTenure
    participant CheckIn
    
    Admin->>Organization: Create company/team structure
    Admin->>Position: Define position types and levels
    Admin->>Assignment: Create assignments with outcomes
    Admin->>Position: Link assignments to positions
    Person->>EmploymentTenure: Start employment at company/position
    EmploymentTenure->>AssignmentTenure: Begin assignment tenure
    Person->>CheckIn: Complete periodic check-ins
    CheckIn->>Assignment: Update performance metrics
    Admin->>CheckIn: Review and calibrate ratings
    CheckIn->>IssueProvider: Escalate concerns to external system
```

## Future Vision

### Short Term
- Enhanced position assignment workflows
- Assignment completion tracking
- Outcome measurement dashboards

### Medium Term
- Skills-based position matching
- Automated assignment recommendations
- Performance analytics integration

### Long Term
- AI-powered position optimization
- Dynamic organizational restructuring
- Predictive assignment success modeling

### People-to-Assignment Connection Roadmap
1. **Employment Tenure Model**: Track when people work for companies in specific positions
2. **Assignment Tenure Model**: Track when people work on specific assignments
3. **Assignment Check-in System**: Periodic performance and satisfaction reviews
4. **Cross-Manager Review System**: Allow calibration of ratings across managers
5. **Issue Provider Integration**: Connect to external systems (Asana) for escalation
6. **Data Migration Tools**: Import existing employment and assignment data

### TODO: Employment Tenure Page Improvements
- **Wizard-like Flow**: 
  - Step 1: Select organization/company
  - Step 2: Filter managers to show only employees of that organization
  - Step 3: Filter positions to show only positions within that organization
- **Dynamic Filtering**: Use JavaScript to update dropdowns based on organization selection
- **Better UX**: Make the form more intuitive and user-friendly

## Integration Points

### With Collaborate
- Positions inform huddle participant roles
- Organizational structure determines huddle scope
- Assignment completion feeds into huddle discussions
- Assignment check-ins inform huddle topics and focus areas

### With Transform
- Assignment outcomes become transformation metrics
- Position changes track career progression
- Organizational restructuring supports transformation initiatives
- Performance check-ins provide transformation insights

## Technical Implementation

### Current Models
- `Organization` (STI: Company, Team, Department)
- `PositionType`
- `PositionLevel`
- `Position`
- `Assignment`
- `AssignmentOutcome`
- `PositionAssignment`
- `ExternalReference`

### Planned Models
- `EmploymentTenure`: Links Person to Company/Position with time spans
  - `person_id`, `company_id`, `position_id`, `manager_id` (optional)
  - `started_at`, `ended_at` (nullable for current employment)
  - Validations: no overlapping active tenures for same person/company, ended_at > started_at
  - Note: Future optimization - consider caching active employment status on Person model for performance
- `AssignmentTenure`: Links Person to Assignment with time spans
- `AssignmentCheckIn`: Periodic performance and satisfaction reviews
- `IssueProvider`: External system integration configuration
- `Issue`: Escalated assignment concerns

### Key Controllers
- `OrganizationsController`
- `PositionTypesController`
- `PositionsController`
- `AssignmentsController`

### Planned Controllers
- `EmploymentTenuresController`
- `AssignmentTenuresController`
- `AssignmentCheckInsController`
- `IssueProvidersController`

### Decorators
- `OrganizationDecorator`
- `PositionTypeDecorator`
- `PositionDecorator`
- `AssignmentDecorator`

### Planned Decorators
- `EmploymentTenureDecorator`
- `AssignmentTenureDecorator`
- `AssignmentCheckInDecorator`

---

*This module provides the structural foundation that enables effective collaboration and transformation within organizations.*

## Implementation Plan: People-to-Assignment Connection

### Phase 1: Foundation Models (Week 1)

#### Commit 1: Employment Tenure Model
- Create `EmploymentTenure` model with:
  - `person_id`, `company_id`, `position_id`, `manager_id` (optional)
  - `started_at`, `ended_at` (nullable for current employment)
  - Validations: no overlapping active tenures for same person/company, ended_at > started_at
  - Validations and associations
- Add basic controller and views for CRUD operations
- Write specs for model and controller

#### Commit 2: Assignment Tenure Model
- Create `AssignmentTenure` model with:
  - `person_id`, `assignment_id`
  - `started_at`, `ended_at` (nullable for current assignment)
  - Validations: no overlapping active tenures for same person/assignment, ended_at > started_at
  - Validations and associations
- Add basic controller and views for CRUD operations
- Write specs for model and controller

#### Commit 3: Update Existing Models
- Add associations to existing models:
  - `Person` has_many `employment_tenures`, `assignment_tenures`
  - `Company` has_many `employment_tenures`
  - `Position` has_many `employment_tenures`
  - `Assignment` has_many `assignment_tenures`
- Update decorators to show tenure information
- Write specs for new associations

### Phase 2: Check-in System (Week 2)

#### Commit 4: Assignment Check-in Model
- Create `AssignmentCheckIn` model with:
  - `assignment_tenure_id`
  - `check_in_date`
  - `energy_spent_percentage` (integer 0-100)
  - `assignment_satisfaction` (enum: very_satisfied, satisfied, neutral, dissatisfied, very_dissatisfied)
  - `performance_rating` (enum: exceeds_expectations, meets_expectations, needs_improvement, unsatisfactory)
  - `manager_rating` (enum: same as performance_rating)
  - `notes` (text)
- Add validations and associations
- Write specs

#### Commit 5: Check-in Controller and Views
- Create `AssignmentCheckInsController` with CRUD operations
- Build forms for creating/editing check-ins
- Add index view to list all check-ins
- Write controller specs

#### Commit 6: Check-in Integration
- Add check-in functionality to assignment tenure views
- Create dashboard widgets for recent check-ins
- Add notifications for overdue check-ins
- Write integration specs

### Phase 3: Cross-Manager Reviews (Week 3)

#### Commit 7: Review System Model
- Create `AssignmentReview` model for cross-manager reviews:
  - `assignment_check_in_id`
  - `reviewer_id` (person doing the review)
  - `review_date`
  - `rating_agreement` (enum: agree, disagree, needs_discussion)
  - `notes` (text)
- Add validations and associations
- Write specs

#### Commit 8: Review Interface
- Create `AssignmentReviewsController`
- Build review interface for managers
- Add review notifications
- Write controller specs

#### Commit 9: Review Dashboard
- Create dashboard for viewing all reviews
- Add filtering by agreement/disagreement
- Create reports for rating calibration
- Write integration specs

### Phase 4: Issue Provider Integration (Week 4)

#### Commit 10: Issue Provider Model
- Create `