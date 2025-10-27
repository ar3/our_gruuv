# Quality Analysis Tools

This document explains how to use the quality analysis tools to ensure your spec suite is valuable and efficient, especially when working with AI-assisted development.

## Overview

The quality analysis toolkit consists of three main tools:

1. **SimpleCov** - Code coverage tracking
2. **RubyCritic** - Code quality analysis
3. **Custom Analysis Scripts** - Spec-specific insights

## Quick Start

### First Time Setup

```bash
# Install the new gems
bundle install

# Run specs to generate initial coverage data
bundle exec rspec

# View the coverage report
open coverage/index.html
```

## Available Rake Tasks

### `rake quality:coverage`

Generate a coverage report showing which code is tested.

**When to use:**
- After AI generates new specs to verify they're testing new code paths
- Before deleting specs to ensure you're not losing coverage
- Weekly to track coverage trends

**Output:** Coverage report at `coverage/index.html`

### `rake quality:specs`

Analyze spec performance to identify slow tests.

**When to use:**
- When your test suite feels slow
- Before optimizing your test suite
- Weekly to monitor spec performance

**Output:** Console report showing slowest specs and recommendations

### `rake quality:critique`

Run RubyCritic to analyze code quality, complexity, and duplication.

**When to use:**
- Before major refactoring
- When feeling "sloppy" and want to improve code quality
- Monthly to track technical debt

**Output:** Quality report at `tmp/rubycritic/index.html`

### `rake quality:full`

Complete quality check combining all tools.

**When to use:**
- Monthly comprehensive review
- Before major code review
- When preparing for deployment

### `rake quality:help`

Show all available quality tasks and usage recommendations.

## Usage Patterns

### Daily Development Workflow

```bash
# After AI generates new specs
rake quality:coverage

# Review coverage report to ensure specs aren't redundant
open coverage/index.html

# Check if new specs are testing new code or duplicating existing coverage
```

### Weekly Quality Check

```bash
# Run specs and analyze performance
bundle exec rspec
rake quality:specs

# Review the slowest specs
# Consider optimizing or removing redundant slow tests
```

### When Feeling "Sloppy"

```bash
# Get comprehensive quality analysis
rake quality:critique

# Review files with low scores
open tmp/rubycritic/index.html

# Focus on improving complexity and code smells
```

### Before Major Refactoring

```bash
# Full quality check
rake quality:full

# Review complex code before refactoring
bundle exec rubycritic app

# Generate quality report
ruby lib/scripts/generate_quality_report.rb
```

### Ad-hoc Analysis

```bash
# Analyze specific aspects as needed
ruby lib/scripts/analyze_spec_coverage.rb
ruby lib/scripts/analyze_spec_performance.rb
```

## Understanding Reports

### Coverage Report (`coverage/index.html`)

**What it shows:**
- Line-by-line coverage for each file
- Overall coverage percentage
- Untested code paths

**How to interpret:**
- High coverage (90%+) - Good, but verify no over-testing of simple logic
- Low coverage (<50%) - Add specs for complex business logic
- Very high coverage (95%+) - May indicate redundant specs testing the same paths

**Key insights:**
- Files with low coverage need more testing
- Files with very high coverage may have redundant specs
- Focus on testing complex logic, not simple CRUD

### RubyCritic Report (`tmp/rubycritic/index.html`)

**What it shows:**
- Code quality scores (A-F)
- Code smells (Reek analysis)
- Code duplication (Flay analysis)
- Complexity metrics (Flog analysis)

**How to interpret:**
- **Score A-B**: High quality, maintainable code
- **Score C-D**: Moderate quality, some improvement needed
- **Score E-F**: Low quality, significant refactoring needed

**Key insights:**
- Files with low scores need refactoring
- High complexity scores indicate hard-to-maintain code
- Duplication suggests opportunities for DRY refactoring

### Performance Analysis (Console Output)

**What it shows:**
- Slowest spec files
- Spec distribution by type
- Performance bottlenecks

**How to interpret:**
- Specs >1 second are slow and may need optimization
- Many system specs may indicate opportunity to use request specs
- Performance balance between unit and integration tests

## Guidelines for AI-Assisted Development

### When AI Generates New Specs

1. **Check redundancy:**
   ```bash
   rake quality:coverage
   ```
   Review if the new specs are testing code already covered by existing specs.

2. **Verify necessity:**
   - Are they testing new code paths?
   - Are they testing complex business logic?
   - Or just duplicating existing coverage of simple CRUD?

3. **Delete redundant specs:**
   - If specs test the same code paths as existing specs, they're redundant
   - Keep only the most comprehensive spec for each code path

### Maintaining Quality with AI

**Focus on:**
- Testing complex business logic, not simple CRUD
- Edge cases that AI might miss
- Authorization and security flows
- Data integrity validations

**Avoid:**
- Over-testing simple model validations
- Duplicating coverage of Rails framework behavior
- Testing the same code path in multiple ways

### Quality Thresholds

**Acceptable:**
- Average coverage: 70-85%
- Most files: 50%+ coverage
- Test suite runs in reasonable time (<10 minutes)

**Target:**
- Average coverage: 80-90%
- Complex logic: 90%+ coverage
- Simple CRUD: 50-70% coverage (Rails handles this)
- Test suite runs quickly (<5 minutes)

**Action Required:**
- Average coverage <70%: Add more strategic specs
- Many slow specs (>20): Optimize or remove
- Low RubyCritic scores (<C): Refactor before adding features

## Tips for Evaluating Spec Value

### Redundant Specs (Consider Removing)

- Multiple specs testing the same validation
- Specs testing Rails framework behavior
- Specs with identical expectations
- Slow specs testing simple logic

### Valuable Specs (Keep and Maintain)

- Specs testing complex business logic
- Specs testing authorization flows
- Specs testing data integrity
- Specs testing edge cases
- Fast specs that catch real issues

### Signs Your Spec Suite is "Sloppy"

- Many specs taking >1 second
- Low RubyCritic scores on app code
- High coverage but tests break often
- Difficult to understand what's tested
- Specs fail randomly

## Integration with Development Workflow

### Before Committing

```bash
# Quick check
bundle exec rspec
rake quality:coverage

# Review coverage for changed files
```

### Weekly Review

```bash
# Full quality check
rake quality:full

# Review report for issues
open tmp/quality_reports/report_*.html
```

### Before Deployment

```bash
# Comprehensive quality check
rake quality:full
bundle exec rubycritic app

# Ensure no critical issues
```

## Troubleshooting

### "No coverage data found"

**Solution:**
```bash
bundle exec rspec
```

### "No spec timing data found"

**Solution:**
```bash
bundle exec rspec --format json --out spec/examples.json
rake quality:specs
```

### RubyCritic hangs or errors

**Solution:**
```bash
# Run on specific directory
bundle exec rubycritic app/models
```

## Additional Resources

- [SimpleCov Documentation](https://github.com/simplecov-ruby/simplecov)
- [RubyCritic Documentation](https://github.com/whitesmith/rubycritic)
- [RSpec Best Practices](https://rspec.info/documentation/)

## Quick Reference

```bash
# Daily
rake quality:coverage

# Weekly  
rake quality:specs

# As needed
rake quality:critique

# Monthly
rake quality:full
```

