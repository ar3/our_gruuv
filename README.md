# OurGruuv

A Rails application for team management, huddles, and organizational development.

## 🚀 Quick Start

```bash
# Start the application
bin/dev

# For external access (if needed)
ngrok http --domain=crappie-saved-absolutely.ngrok-free.app 3000

# Deploy to production
git push origin main && railway up
```

## 📚 Documentation Hub

This is your central guide to understanding OurGruuv's architecture, patterns, and conventions.

### 🎯 For AI Agents

**Start here**: [docs/RULES/overview.md](docs/RULES/overview.md) - Complete rules and patterns overview

**Core Agent Behavior**: [docs/RULES/agent-behavior.md](docs/RULES/agent-behavior.md) - How AI agents should work

**Architecture Patterns**:
- [Services & Result Pattern](docs/RULES/services-patterns.md) - One verb, one call, explicit returns
- [Forms & Validation](docs/RULES/forms-validation.md) - ActiveModel + dry-validation escalation
- [Integrations](docs/RULES/integrations.md) - Gateway pattern for external APIs
- [Queries & Value Objects](docs/RULES/queries-value-objects.md) - Complex reads and domain types
- [Events & Handlers](docs/RULES/events-handlers.md) - Wisper pub/sub patterns

### 🎨 For Design & Styling

**Start here**: [docs/STYLES/overview.md](docs/STYLES/overview.md) - Complete styling patterns overview

**Page Patterns**:
- [Index Pages](docs/STYLES/index-pages.md) - List/index page standards
- [Show Pages](docs/STYLES/show-pages.md) - Detail/show page standards

**Component Patterns**:
- [Buttons & Authorization](docs/STYLES/buttons.md) - Button hierarchy and permission UX
- [Colors](docs/STYLES/colors.md) - Semantic color system
- [Navigation](docs/STYLES/navigation.md) - Navigation and back link patterns
- [Forms](docs/STYLES/forms.md) - Form layout and HAML best practices
- [Responsive Design](docs/STYLES/responsive.md) - Mobile-first patterns
- [Accessibility](docs/STYLES/accessibility.md) - Accessibility standards and responsive design

### 🔧 For Developers

**Coding Standards**: [docs/RULES/coding-style.md](docs/RULES/coding-style.md) - Rails, Ruby, and code organization

**Project Workflow**: [docs/RULES/project-workflow.md](docs/RULES/project-workflow.md) - Git, deployment, team processes

**Context Management**: [docs/RULES/context-management.md](docs/RULES/context-management.md) - OKR3 framework and vision documents

### 📋 Migration & Improvements

**Operational Enhancements**: [docs/OE/](docs/OE/) - Current violations and migration priorities

- [Services Pattern Violations](docs/OE/services-pattern-violations.md)
- [Forms Pattern Violations](docs/OE/forms-pattern-violations.md)
- [Integrations Pattern Violations](docs/OE/integrations-pattern-violations.md)
- [Queries & Value Objects Violations](docs/OE/queries-value-objects-violations.md)
- [Events & Handlers Violations](docs/OE/events-handlers-violations.md)

### 📝 Project Notes & Technical Docs

**Session Notes**: [docs/NEXT_CHAT_SUMMARY.md](docs/NEXT_CHAT_SUMMARY.md) - Current session summary

**Technical Documentation**:
- [Slack Integration](docs/SLACK_INTEGRATION.md) - Slack setup and implementation
- [Slack Debug Improvements](docs/SLACK_DEBUG_IMPROVEMENTS.md) - Recent Slack fixes
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [PostgreSQL Troubleshooting](docs/postgres_troubleshooting.md) - Database connection issues and fixes
- [Seeding](docs/SEEDING.md) - Database seeding information

### 🏗️ Architecture Overview

**Directory Structure**:
```
app/
├── models/                 # Entities & invariants (ActiveRecord)
├── services/               # Orchestrating commands (one verb, one call)
├── jobs/                   # Thin wrappers; call services
├── forms/                  # ActiveModel forms; optional dry-validation
├── policies/               # Pundit authorization
├── decorators/             # View/presenter logic
├── queries/                # Complex reads/reporting
├── value_objects/          # Money, TimeRange, EmailAddress, etc.
├── events/                 # Event classes (Wisper topics)
├── handlers/               # Event handlers; single responsibility
└── integrations/           # Vendor gateways/clients/fakes
```

**Key Patterns**:
- **Controllers**: Coordinate only → validate params, authorize, call Service, render/redirect
- **Services**: One verb, one `call`, one transaction; return `Result`
- **Forms**: Shape/validate input; call a Service
- **Policies**: Pundit for permissions
- **Integrations**: Gateway pattern for external APIs

### 🎯 Vision & Strategy

**Vision Documents**: [docs/vision/](docs/vision/) - OKR3 framework and strategic direction

**Mission-Hypothesis Framework**: 
- [Mission-Hypothesis Summary](docs/vision/Mission-Hypothesis-Summary.md) - Core framework philosophy
- [Mission-Hypothesis Commit Plan](docs/vision/Mission-Hypothesis-Commit-Plan.md) - Implementation roadmap
- [Mission-Hypothesis ERD](docs/vision/Mission-Hypothesis-ERD.md) - Database design
- [Mission-Hypothesis Diagram](docs/vision/Mission-Hypothesis-Diagram.md) - Visual diagrams
- [Mission-Hypothesis Domain Model](docs/vision/Mission-Hypothesis-Domain-Model.md) - Domain model

**Module Overviews**:
- [Transform Overview](docs/vision/Transform--Overview.md) - Measurement and analytics
- [Collaborate Overview](docs/vision/Collab--Overview.md) - Team collaboration and huddles

**Current State**: Review vision documents when starting fresh conversations to understand priorities

## 🛠️ Development

### Prerequisites
- Ruby (see `.ruby-version`)
- Rails
- PostgreSQL
- Node.js (for asset compilation)

### Setup
```bash
# Install dependencies
bundle install
yarn install

# Setup database
rails db:create db:migrate db:seed

# Start development server
bin/dev
```

### Testing
```bash
# Run tests
bundle exec rspec

# Run specific test
bundle exec rspec spec/path/to/test_spec.rb
```

### Deployment
- **Platform**: Railway
- **Process**: `git push origin main && railway up`
- **Environment**: Production configuration in Railway dashboard

## 📞 Support

For questions about architecture, patterns, or conventions:
1. Check the relevant documentation above
2. Review the OE violation files for known issues
3. Consult the vision documents for strategic context

---

*This README is the central hub for OurGruuv's documentation. Keep it updated as the architecture evolves.*