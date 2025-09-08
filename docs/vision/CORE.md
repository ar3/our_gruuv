# Core Vision

The Core module provides the foundational infrastructure that enables all other modules to function effectively. It encompasses authentication, authorization, communication/notification systems, and core infrastructure components.

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

### **Current OKR3: Employment Management Security**
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

### **Layout Migration Progress**
- [x] Create `authenticated-v2-0.html.haml` layout
- [x] Migrate person show page
- [x] Migrate person public page  
- [x] Migrate person teammate page
- [ ] Migrate person edit page
- [ ] Migrate person index page
- [ ] Migrate organization show page
- [ ] Migrate organization index page
- [ ] Migrate employment management page
- [ ] Migrate employees page
- [ ] Migrate huddle pages
- [ ] Migrate assignment pages
- [ ] Migrate other authenticated pages

## DREAMING 💭

### **Infrastructure Evolution**
- **App Server**: Need to build an app server at some point for better scalability
- **Communication Systems**: Enhanced notification and communication infrastructure
- **Performance Optimization**: Caching, database optimization, and response time improvements

### **Authentication & Authorization Enhancements**
- **Multi-factor Authentication**: Enhanced security for sensitive operations
- **Role-based Access Control**: Expand beyond simple admin flag to role-based system
- **Permission Caching**: Cache permissions for performance optimization
- **Organization-level Permissions**: Discrete permissions per organization with inheritance

### **Development Infrastructure**
- **Automated Testing**: Enhanced CI/CD pipeline with comprehensive test coverage
- **Monitoring & Observability**: Application performance monitoring and error tracking
- **Documentation**: Automated API documentation and developer onboarding materials

### **Visual Design System**
- **8px Grid System**: Implement consistent spacing using 8px multiples (8, 16, 24, 32px) for perfect visual rhythm
- **Component Library**: Build reusable UI components with consistent spacing, typography, and color usage
- **Design Tokens**: Create centralized design tokens for colors, typography, spacing, and component styling
- **Accessibility Standards**: Ensure all design elements meet WCAG AA contrast requirements and accessibility guidelines

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

### **Advanced Authorization**
- Hierarchical permission inheritance across organization tree
- Permission caching with JSON for performance
- Role-based access control (if needed)
- Permission audit logging and history

### **Impersonation & Audit System**
- **Admin Impersonation**: og_admin users can impersonate other users (except other og_admins) for testing and support
- **Session Persistence**: Impersonation persists across browser tabs/windows until manually stopped
- **Permission Enforcement**: Impersonated users only have their actual permissions, not admin privileges
- **Visual Indicators**: Clear warning icons and "Stop Impersonation" options when impersonating
- **Future: Whodunit Audit Trail**: Track who took actions and whether they were impersonated, enabling "whodunit" style investigation of system changes
- **Security Considerations**: Prevent impersonation hijacking, implement session validation, and add audit logging for all impersonation events
- **Future: Security Hardening** - Enhanced validation, comprehensive testing, audit logging foundation, and bulletproof security for production use

### **Layout Migration Status**
**Pages using authenticated-v2-0 layout:**
- Dashboard, Organizations, People, Assignments, Positions, Position Types, Huddles, Abilities, All new "Coming Soon" pages

**Pages still using old layout (need migration):**
- Employment Tenures, Assignment Tenures, Upload Events, Person Accesses, Huddle Playbooks, Seats, Slack Integration, Impersonation, Profile Management

**Migration Priority:** Complete layout migration for consistent UI/UX across all authenticated pages.

### **Future Possibilities**
- **Microservices Architecture**: Potential evolution to microservices for better scalability
- **Real-time Features**: WebSocket integration for real-time collaboration features
- **Mobile Applications**: Native mobile apps for iOS and Android
- **API Ecosystem**: Public API for third-party integrations and extensions

---

*This module provides the foundational infrastructure that enables effective collaboration, alignment, and transformation within organizations.*
