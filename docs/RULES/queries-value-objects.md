# Queries & Value Objects Patterns

This document defines the Queries and Value Objects patterns for the OurGruuv application.

> **See also**: [Overview](../overview.md) | [Services Patterns](./services-patterns.md) | [Forms Patterns](./forms-validation.md)

## Queries Pattern

**Use when:** reads are multi-join, paginated/sorted, reused across controllers/jobs, or feed reporting APIs.

**Scopes (on models):** small, composable, local filters (single-table or simple joins).

**Query objects (`app/queries`):** complex reads/reporting with stable shape, joins, pagination, caching.

## Query Object Example

```ruby
# app/queries/applicants_by_stage.rb
class ApplicantsByStage
  def initialize(company_id:, from: 30.days.ago, to: Time.current)
    @company_id, @from, @to = company_id, from, to
  end

  def call
    Applicant
      .where(company_id: @company_id, created_at: @from..@to)
      .left_joins(:interviews, :offers)
      .select("stage, COUNT(*) AS count")
      .group("stage")
      .order("count DESC")
  end
end
```

## When to Use Queries vs Scopes

### Use Scopes When:
- Simple, composable filters
- Single-table or simple joins
- Local to one model
- Basic filtering logic

### Use Query Objects When:
- Multi-join queries
- Pagination and sorting
- Reused across controllers/jobs
- Complex reporting
- Caching strategies needed

## Value Objects Pattern

**Use for:** small immutable domain types (e.g., `Money`, `TimeRange`, `EmailAddress`).

Prefer `Data.define` (Ruby ≥ 3.2). Fallback: `Struct.new(..., keyword_init: true)`.

## Value Object Examples

```ruby
# app/value_objects/money.rb
Money = Data.define(:cents, :currency) do
  def +(other)  = same!(other) && Money.new(cents + other.cents, currency)
  def -(other)  = same!(other) && Money.new(cents - other.cents, currency)
  def zero?     = cents.zero?
  def to_s      = format("%.2f %s", cents / 100.0, currency)
  private
  def same!(other) = raise ArgumentError, "Currency mismatch" unless other.currency == currency
end
```

```ruby
# app/value_objects/time_range.rb
TimeRange = Data.define(:starts_at, :ends_at) do
  def include?(t)    = (starts_at..ends_at).cover?(t)
  def overlaps?(o)   = starts_at < o.ends_at && o.starts_at < ends_at
  def duration       = ends_at - starts_at
end
```

## Key Principles

- **Queries**: Complex reads with stable shape, joins, pagination
- **Scopes**: Simple, composable, local filters
- **Value Objects**: Immutable, equality by value, no DB access
- **Domain calculations**: Centralize in value objects
- **Reusability**: Queries should be reusable across controllers/jobs

## Implementation Checklist

When creating or updating queries and value objects, ensure:
- [ ] Use scopes for simple, composable filters
- [ ] Use query objects for complex reads/reporting
- [ ] Make value objects immutable
- [ ] Use `Data.define` for value objects
- [ ] Keep domain calculations in value objects
- [ ] Don't access database from value objects
- [ ] Don't put complex queries in controllers
- [ ] Don't mix business logic with query logic
