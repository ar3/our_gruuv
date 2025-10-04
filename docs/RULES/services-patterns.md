# Services Patterns

This document defines the Services pattern for the OurGruuv application.

> **See also**: [Overview](../overview.md) | [Forms Patterns](./forms-validation.md) | [Integrations](./integrations.md)

## Services Pattern

**Use when:** operation coordinates multiple models and/or external systems; requires a transactional boundary; should be callable sync **and** async.

**Shape:** one verb name (`ChargeInvoice`, `SyncFranchisee`), one public `call`, one transaction, explicit return via `Result`.

## Result Pattern

```ruby
# lib/result.rb
Result = Data.define(:ok?, :value, :error) do
  def self.ok(value=nil) = new(true, value, nil)
  def self.err(error)    = new(false, nil, error)
end
```

## Service Structure

```ruby
# app/services/enroll_user.rb
class EnrollUser
  def self.call(...) = new(...).call

  def initialize(user_id:, plan_id:, gateway: StripeGateway.new)
    @user_id, @plan_id, @gateway = user_id, plan_id, gateway
  end

  def call
    user = User.find(@user_id)
    plan = Plan.find(@plan_id)

    ApplicationRecord.transaction do
      sub = user.subscriptions.find_or_create_by!(plan:)
      @gateway.subscribe(user:, plan:)
      Events.publish(SubscriptionActivated.new(subscription_id: sub.id))
      Result.ok(sub)
    end
  rescue StripeGateway::Timeout => e
    raise RetryableError, e.message # let job retry
  rescue ActiveRecord::RecordInvalid => e
    Result.err(e.record.errors.full_messages)
  end
end
```

## Key Principles

- **One verb, one call**: Service name should be a verb + noun
- **Explicit returns**: Always return `Result.ok` or `Result.err`
- **Transaction boundaries**: Wrap related operations in transactions
- **Error handling**: Categorize errors as retryable vs non-retryable
- **Keep domain rules close to entities**: Move invariants to models/value objects

## Jobs Integration

Jobs should call the same Services as controllers:

```ruby
class EnrollUserJob < ApplicationJob
  queue_as :default
  def perform(user_id, plan_id)
    res = EnrollUser.call(user_id:, plan_id:)
    unless res.ok?
      Rails.logger.warn("EnrollUser failed: #{res.error}")
    end
  rescue EnrollUser::RetryableError => e
    raise e # let backend retry
  end
end
```

## Implementation Checklist

When creating or updating services, ensure:
- [ ] One verb name (e.g., `ChargeInvoice`, `SyncFranchisee`)
- [ ] One public `call` method
- [ ] Use `Result` pattern for returns
- [ ] Wrap operations in transactions when needed
- [ ] Handle errors explicitly with `Result.ok/err`
- [ ] Keep business logic separate from external API calls
- [ ] Be callable from both controllers and jobs
- [ ] Don't handle authorization (use Policies instead)
