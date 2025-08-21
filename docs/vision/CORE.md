# Core Functionality Vision

This document outlines the vision for core system functionality that spans across all value streams (Align, Collaborate, Transform).

## DONE ✅

### Authentication & Authorization
- Google OAuth2 integration for user authentication
- Basic Pundit-based authorization policies
- Session management with current_person and current_organization
- Person profile viewing with conditional access control

### Database & Models
- STI-based organization hierarchy (Company < Organization)
- Comprehensive model associations and validations
- FactoryBot factories for testing
- Database migrations and schema management

### Testing Infrastructure
- RSpec test suite with 872 examples, 0 failures
- Comprehensive test coverage for models, controllers, views
- FactoryBot factories for all models
- Request and feature specs

## DOING 🔄

### **Current OKR: Employment Management Security**
**Objective: Allow all employees of an organization to have their employment to be managed in a safe and secure way**

**Key Results:**
1. **100% of employment management actions require proper authorization** (using our new PersonOrganizationAccess model)
2. **All employment data is accessible only to authorized personnel** (employment managers can see their org + descendants)
3. **Employment creation/editing interface is available and functional** (the UI we're about to build)
4. **Employment data integrity is maintained** (no overlapping tenures, proper validation)
5. **Audit trail exists for all employment changes** (we can track who made what changes)

### **Current Sprint: Employment Management Interface** (Waypoint 1)
- [ ] Create new page for adding person + employment simultaneously
- [ ] Include comprehensive employment data validation
- [ ] Add high-quality test coverage
- **Deliverable**: Functional employment creation interface with validation
- **Commit**: "feat: create employment management interface"

### **Next Waypoints:**
**Waypoint 2: Authorization Integration** (Security-focused)
- [ ] Integrate PersonOrganizationAccess checks into employment actions
- [ ] Add authorization to employment create/edit/destroy actions
- [ ] Add high-quality test coverage
- **Deliverable**: Secure employment management with proper permissions

**Waypoint 3: Data Access Control** (Security-focused)
- [ ] Implement organization-scoped data access (org + descendants)
- [ ] Ensure employment data is only visible to authorized personnel
- [ ] Add high-quality test coverage
- **Deliverable**: Proper data isolation and access control

**Waypoint 4: Audit Trail System** (Compliance-focused)
- [ ] Create audit logging for employment changes
- [ ] Track who made what changes and when
- [ ] Add high-quality test coverage
- **Deliverable**: Complete audit trail for employment modifications

**Waypoint 5: PersonAccessesController Test Coverage** (Quality-focused)
- [ ] Review and implement valuable PersonAccessesController specs
- [ ] Focus on authorization, CRUD operations, and edge cases
- [ ] Ensure proper organization-scoped access testing
- [ ] Remove temporary `xit` skips and add comprehensive coverage
- **Deliverable**: Robust test coverage for organization-scoped access management

## DREAMING 🌟

### **Organization-Centric User Experience**
- **Profile page becomes current-organization-centric**: User profile shows information about other organizations but requires switching organizational context to engage with organization-specific features
- **Organization-scoped access management**: PersonOrganizationAccess management lives within the organization namespace, not as a standalone controller
- **Context switching for cross-organization work**: Users must switch to specific organization context to manage positions, assignments, huddles, and access for that organization
- **Unified organization management**: All organization-specific operations (employment, access, positions, etc.) are managed from within that organization's context

### **Public Profile & Social Sharing**
- **Customizable vanity URLs**: Allow users to create shareable, branded profile URLs for social media
- **Public profile pages**: Accessible without authentication, showing portable stats and achievements
- **Cross-organization reputation**: Stats that follow users across different jobs and organizations
- **Social media integration**: Easy sharing of professional achievements and milestones
- **Dream Goal**: Make the public profile page such that people will want to share it on their social media accounts… ideally this page will challenge what is the center of their professional identity, rivaling LinkedIn

**Future Sprint: MAAP Management UI**
- [ ] Add authorization checks to position/assignment management
- [ ] Implement disabled button states with permission tooltips
- [ ] Update existing forms to respect new permissions

## DREAMING 💭

### Advanced Authorization
- Hierarchical permission inheritance across organization tree
- Permission caching with JSON for performance
- Role-based access control (if needed)
- Permission audit logging and history

### API Development
- RESTful API endpoints for core models
- API authentication and rate limiting
- API versioning strategy
- OpenAPI/Swagger documentation

### Billing & Subscription Management
- Multi-tenant billing system
- Subscription tiers and feature gating
- Usage tracking and metering
- Payment processing integration

### System Administration
- Admin dashboard for system-wide management
- User management and bulk operations
- System health monitoring and alerts
- Backup and recovery procedures

### Performance & Scalability
- Database query optimization
- Caching strategies (Redis, Memcached)
- Background job processing
- Horizontal scaling considerations

### Security & Compliance
- Data encryption at rest and in transit
- GDPR compliance features
- Security audit logging
- Penetration testing and vulnerability management

## Design Rules

### Authorization UX
- **Don't hide things**: Show all actions but disable unauthorized ones
- **Clear feedback**: Use warning icons next to disabled buttons/links
- **Helpful tooltips**: Explain what permission is needed for each action
- **Consistent patterns**: Use the same UI patterns across all permission checks

### Development Workflow
- **Small commits**: Each commit should be deployable and reviewable
- **Model-first**: Start with database and model changes
- **UI second**: Add UI after models are solid
- **Test coverage**: Maintain 100% test coverage for new functionality
- **Manual testing**: UI changes go through manual testing before deployment
