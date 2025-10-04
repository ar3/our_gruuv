# Forms & Validation Patterns

This document defines the Forms and Validation patterns for the OurGruuv application.

> **See also**: [Overview](../overview.md) | [Services Patterns](./services-patterns.md) | [Integrations](./integrations.md)

## Forms Pattern

**Default:** PORO + `ActiveModel::Model` + `ActiveModel::Attributes`.

Escalate to **dry-validation** when inputs are nested, coercion-heavy, or require cross-field/conditional rules.

## ActiveModel Forms (Default)

```ruby
# app/forms/signup_form.rb
class SignupForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :email, :string
  attribute :plan_id, :integer
  attribute :accept_terms, :boolean, default: false

  validates :email, :plan_id, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :accept_terms, acceptance: true

  def save
    return false unless valid?
    res = EnrollUser.call(email: email.strip.downcase, plan_id:)
    res.ok? ? true : (errors.add(:base, Array(res.error).to_sentence); false)
  end
end
```

## dry-validation (When Needed)

```ruby
# app/forms/applicant_filter_form.rb
class ApplicantFilterForm
  include ActiveModel::Model
  attr_reader :attributes

  Schema = Dry::Schema.Params do
    required(:company_id).filled(:integer)
    optional(:stages).array(:string)
    optional(:from).filled(:date)
    optional(:to).filled(:date)
    rule(to_after_from: %i[from to]) { to.nil? || from.nil? || to >= from }
  end

  def initialize(params={})
    result = Schema.call(params)
    @attributes = result.to_h
    @dry_errors = result.errors
  end

  def valid? = @dry_errors.empty?
  def errors
    @errors ||= DryToActiveModelErrors.wrap(@dry_errors)
  end
end
```

## Key Principles

- **Start with ActiveModel**: Use for simple forms
- **Escalate to dry-validation**: For nested/coercion-heavy/conditional inputs
- **Keep invariants on models**: Don't move true business rules to forms
- **Call Services**: Forms should call Services for business logic
- **Consistent error handling**: Adapt dry-validation errors to ActiveModel::Errors

## When to Use Each

### ActiveModel Forms:
- Simple input validation
- Single model updates
- Basic form fields
- Standard Rails validations

### dry-validation:
- Nested/conditional validation
- Complex coercion needs
- Cross-field validation rules
- API input validation
- Complex data transformation

## Implementation Checklist

When creating or updating forms, ensure:
- [ ] Start with ActiveModel for simple cases
- [ ] Escalate to dry-validation when needed
- [ ] Handle input shaping and validation
- [ ] Call Services for business logic
- [ ] Provide consistent error handling
- [ ] Keep invariants on models/DB
- [ ] Don't contain business logic
- [ ] Don't access database directly
- [ ] Don't handle authorization (use Policies instead)
