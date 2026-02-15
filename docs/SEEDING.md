# Seeding System Documentation

## Overview

The seeding system provides flexible data generation for development and testing scenarios. It creates realistic organizations, teams, huddles, and participants with varying levels of feedback participation.

## Available Scenarios

### Basic Scenario
```bash
bundle exec rake "seed:scenario[basic]"
```
- **3 organizations** (Konoha Industries, S.H.I.E.L.D. Enterprises, Starfleet Command)
- **3 teams per organization** (Ninja Squad, Avengers Initiative, Starship Crew, etc.)
- **Mixed participation** (60-80% feedback completion)
- **First team per org gets 2 huddles** (one with alias, one without)
- **Other teams get 1 huddle each**
- **3-8 participants per huddle**
- **Guaranteed scenarios** (always included):
  - 🌟 **Perfect huddle**: Full participation with all 5-star ratings
  - 🤐 **No feedback huddle**: Multiple participants but zero feedback
  - 💥 **Disaster huddle**: Full participation but all low ratings (1-3)

### Full Participation Scenario
```bash
bundle exec rake "seed:scenario[full]"
```
- Same structure as basic scenario
- **100% feedback participation** across all huddles
- **Guaranteed scenarios** (always included)
- Useful for testing complete data scenarios

### Low Participation Scenario
```bash
bundle exec rake "seed:scenario[low]"
```
- Same structure as basic scenario
- **20-40% feedback participation** across all huddles
- **Guaranteed scenarios** (always included)
- Useful for testing low engagement scenarios

### Clean Slate
```bash
bundle exec rake "seed:scenario[clean]"
```
- Deletes all existing data
- Useful before running other scenarios

## Data Structure

### Organizations
- Uses Single Table Inheritance (STI)
- `Company` = top-level organizations
- `Team` = child organizations with parent companies

### Teams
- Each team belongs to a parent company
- Teams have names like "Engineering", "Product", "Sales"
- Display names show hierarchy: "Acme Corp > Engineering"

### Participants
- 5-8 participants per team
- **Fun thematic names** from Naruto, Star Wars, Star Trek, and Marvel
- Random timezones from Rails timezone list
- Some participants join multiple huddles within their team

### Huddles
- Started 1-7 days ago
- Expire 1 week from creation
- **Thematic aliases** (e.g., "shadow-clone", "force-lightsaber", "phaser-warp", "shield-avenger")
- 3-6 participants per huddle

### Feedback
- Realistic ratings (3-5 range for regular huddles)
- **Thematic feedback** with franchise-specific language
- Random conflict styles
- Optional appreciation and suggestions
- Optional private feedback
- **Guaranteed scenarios**:
  - Perfect huddles: All 5-star ratings with positive feedback
  - Disaster huddles: All 1-3 star ratings with negative feedback

## Usage Examples

### Development Setup
```bash
# Start with a clean slate and basic scenario
bundle exec rake "seed:scenario[clean]"
bundle exec rake "seed:scenario[basic]"

# Start Rails server
bin/dev
```

### Testing Different Scenarios
```bash
# Test full participation UI
bundle exec rake "seed:scenario[full]"

# Test low participation UI
bundle exec rake "seed:scenario[low]"
```

### View Available Options
```bash
bundle exec rake seed:scenarios
```

## Color System Testing

The seeding system works perfectly with the new color system:

- **Feedback participation badges** will show different colors based on completion percentage
- **S.E.E. 20 scores** will have appropriate colors based on the composite score
- **Individual ratings** will show colors based on the 1-5 scale
- **Status badges** will reflect the current state

## Customization

### Adding New Scenarios
1. Add a new method in `lib/tasks/seed.rake`
2. Add the case in the `seed:scenario` task
3. Update the help text in `seed:scenarios`

### Modifying Existing Scenarios
- Edit the methods in `lib/tasks/seed.rake`
- Adjust participation percentages, team counts, etc.
- Test with `bundle exec rake "seed:scenario[scenario_name]"`

### Data Patterns
- Organizations: 3 companies
- Teams: 3 teams per company
- Participants: 5-8 per team
- Huddles: 1-2 per team (first team gets 2)
- Feedback: varies by scenario (20-100%)

## Notes

- All data is cleaned before seeding new scenarios
- Email addresses are generated based on organization names
- Timezones are randomly selected from Rails timezone list
- Huddle aliases use adjective-noun combinations
- Feedback includes realistic text and ratings
- Some participants join multiple huddles to test cross-huddle functionality 