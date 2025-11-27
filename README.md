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

To run the full spec suite, use the following command because there are spec leaks that I haven't spent the time to debug:

---

1. Review our testing strategy doc
2. Run all specs in segments. Make sure you run each segment and each folder of the system specs separately in different commands, updating the last_full_spec_suite doc after every folder/segment. Do not run multiple segments/folders in one command. Remember to get the real date/time.

Before you run this, review our coding standards and rules, which can be found linked in the readme
After you run this list out all failures with a plan of action to fix them


---

### 🎯 For AI Agents

**Start here**: [docs/RULES/overview.md](docs/RULES/overview.md) - Complete rules and patterns overview

**Core Agent Behavior**: [docs/RULES/agent-behavior.md](docs/RULES/agent-behavior.md) - How AI agents should work

**Architecture Patterns**:
- [Services & Result Pattern](docs/RULES/services-patterns.md) - One verb, one call, explicit returns
- [Forms & Validation](docs/RULES/forms-validation.md) - ActiveModel + dry-validation escalation
- [Integrations](docs/RULES/integrations.md) - Gateway pattern for external APIs
- [Queries & Value Objects](docs/RULES/queries-value-objects.md) - Complex reads and domain types
- [Events & Handlers](docs/RULES/events-handlers.md) - Wisper pub/sub patterns
- [Testing Strategy](docs/RULES/testing-strategy.md) - Testing pyramid and critical path coverage

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

The test suite is organized into three independent groups:

**1. Unit & Integration Specs** (Models, Controllers, Services, Policies, etc.)
```bash
# Run all non-system specs (fast, ~2064 examples)
./bin/unit-specs

# Manual equivalent
bundle exec rspec --exclude-pattern "spec/system/**/*_spec.rb"
```

**2. System Specs** (End-to-end browser tests with Selenium)
```bash
# Run all system specs (slower, ~57 examples)
./bin/system-specs

# Manual equivalent  
bundle exec rspec spec/system/
```

**3. ENM Specs** (Ethical Non-Monogamy assessment module)
```bash
# Run ENM specs only (isolated module, ~106 examples)
./bin/enm-specs

# Manual equivalent
bundle exec rspec spec/enm/
```

**All Specs Together**
```bash
# Run everything (unit + system + ENM)
bundle exec rspec spec/
```

**Why This Separation?**
- **Speed**: Unit specs run fast (~2 minutes) for quick development feedback
- **Isolation**: ENM is a separate module with its own test suite
- **Stability**: System specs need browser (Chrome/Selenium) and are slower
- **Flexibility**: Run only what you need for your current work

**Testing Pyramid:**
- **Unit/Integration Specs** (many, fast): Models, services, decorators, policies, controllers
- **System Specs** (few, slow): Critical end-to-end user workflows with browser testing
- **ENM Specs** (separate): Isolated assessment wizard functionality

**Development Workflow:**
```bash
# Day-to-day development (fast feedback)
./bin/unit-specs

# Before committing (ensure critical paths work)
./bin/system-specs

# Pre-deployment (everything)
bundle exec rspec spec/
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