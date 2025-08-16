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

### Authorization System
**Current Sprint: Person Organization Access Model** ✅ **COMPLETED**
- ✅ Create `PersonOrganizationAccess` model with `organization_id` (not company_id)
- ✅ Add `can_manage_employment` boolean capability
- ✅ Add `can_manage_maap` boolean capability  
- ✅ Create migration and update schema
- ✅ Add model specs and factories
- ✅ Implement hierarchical permission checking

**Next Sprint: Employment Management UI**
- [ ] Create new page for adding person + employment simultaneously
- [ ] Add authorization checks to employment management actions
- [ ] Implement disabled button states with permission tooltips

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
