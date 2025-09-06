# Align--Position Vision

The Align--Position module focuses on organizational structure, position management, and seat allocation. This is where executive teams will likely spend a significant portion of their time, managing compensation, labor budgets, and seat prioritization.

## DONE ✅

### Core Models & Infrastructure
- ✅ `EmploymentTenure` model with person/company/position associations
- ✅ `AssignmentTenure` model with energy percentage tracking
- ✅ `AssignmentCheckIn` model with comprehensive check-in fields
- ✅ Organization hierarchy (Company > Department > Team)
- ✅ Position management (Type, Level, Position)
- ✅ Assignment system with outcomes and external references
- ✅ Comprehensive test coverage (872 examples, 0 failures)

### Assignment Management System
- ✅ Unified assignment management interface
- ✅ Row-based design for managing assignments and check-ins
- ✅ Business logic for tenure changes and check-in creation
- ✅ Assignment selection and management
- ✅ Check-in system with ratings and notes

### Organization Management
- ✅ Organization employee listing with huddle participants
- ✅ Person profile viewing for any person (not just current user)
- ✅ Organization switching with proper redirects
- ✅ Employee stats and organizational data display

## DOING 🔄

### **Current OKR3: Assignment Check-in Habit Formation**
**Objective: CareerPlug creates a habit of actionable feedback and fairness calibration by using Assignment Check-ins**

**Key Results:**
1. **All CareerPlug Product employees are set up as employees in OurGruuv**
2. **All CareerPlug product employees have employment with their real positions in OurGruuv**
3. **80% of CareerPlug employees have 2+ Assignment check-ins logged**
4. **50% of the managers have visited the assignment-check-in-calibration page of a sibling-manager's employee**
5. **50% of the managers that visit "diagonally-related" employees have submitted a piece of note-worthy feedback about an assignment rating/check-in**
6. **All CareerPlug Abilities exist in OurGruuv**

### **Current Sprint: Employment Management UI**
- [ ] Create new page for adding person + employment simultaneously
- [ ] Add authorization checks to employment management actions
- [ ] Implement disabled button states with permission tooltips

### **Next Sprint: Assignment Check-in System**
- [ ] Build assignment check-in creation and management interface
- [ ] Implement check-in rating and feedback system
- [ ] Create manager calibration and review workflows

## DREAMING 💭

### **Position Management Evolution**
- **Seat Concept & Model**: Job requisition with HR metadata
  - States: Archived, Filled, Open, Draft
  - References in EmploymentTenure model
  - Goal: No active tenure missing seat, no seat missing tenure
- **Seat Attributes**: Based on template (need to define)
- **Seat View**: Mirror template structure

### **Compensation & Labor Budgets**
- **Compensation Management**: Salary bands, equity allocation, bonus structures
- **Labor Budget Planning**: Department and team budget allocation and tracking
- **Cost Center Management**: Track and allocate costs across organizational units
- **Headcount Planning**: Strategic workforce planning and headcount management

### **Executive Dashboard**
- **Organizational Health Metrics**: Key performance indicators for organizational structure
- **Position Utilization**: Track how positions are being used and optimized
- **Budget vs Actual**: Compare planned vs actual labor costs and headcount
- **Strategic Planning**: Long-term organizational structure and position planning

### **Advanced Position Features**
- **Position Templates**: Standardized position definitions across organizations
- **Position Inheritance**: Inherit position attributes from parent organizations
- **Position Analytics**: Deep insights into position effectiveness and utilization
- **Automated Position Creation**: AI-assisted position creation based on organizational needs

### **Integration Possibilities**
- **HRIS Integration**: Connect with existing HR information systems
- **Payroll Integration**: Automatic salary and compensation data sync
- **Recruiting Integration**: Connect position management with recruiting workflows
- **Performance Management**: Link position management with performance review cycles

---

*This module provides the structural foundation that enables effective collaboration and transformation within organizations.*
