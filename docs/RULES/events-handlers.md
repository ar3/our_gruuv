# Events & Handlers Patterns

This document defines the Events and Handlers patterns for the OurGruuv application.

> **See also**: [Overview](../overview.md) | [Services Patterns](./services-patterns.md) | [Forms Patterns](./forms-validation.md)

## Events & Handlers Pattern

**Default:** **Wisper** for in-process pub/sub to decouple side-effects.

One handler = one effect; make handlers **idempotent**.

## Event Example

```ruby
# app/events/subscription_activated.rb
class SubscriptionActivated
  attr_reader :subscription_id, :activated_at
  def initialize(subscription_id:, activated_at: Time.current)
    @subscription_id, @activated_at = subscription_id, activated_at
  end
end
```

## Service with Event Publishing

```ruby
# app/services/activate_subscription.rb
class ActivateSubscription
  include Wisper::Publisher
  def self.call(...) = new(...).call
  def initialize(subscription_id:, plan_id:) = (@sid, @pid = subscription_id, plan_id)
  def call
    sub = Subscription.find(@sid)
    sub.activate!(plan_id: @pid) # domain rule on model
    broadcast(:subscription_activated, SubscriptionActivated.new(subscription_id: sub.id))
    Result.ok(sub)
  end
end
```

## Event Handler

```ruby
# app/handlers/notify_customer_on_activation.rb
class NotifyCustomerOnActivation
  def call(event)
    sub = Subscription.find(event.subscription_id)
    UserMailer.plan_activated(sub.user_id).deliver_later
  end
end
```

## Wisper Configuration

```ruby
# config/initializers/wisper.rb
Wisper.subscribe(NotifyCustomerOnActivation.new)
```

## Upgrade Signal: Rails Event Store

Notify AR3 to consider **RES** if any of these appear:

* Need **durable, replayable** events / audit trail
* Build **projections/read models** from event history
* Reliable **webhooks/integration** delivery (outbox, retries across deploys)
* Multiple subscribers with different speeds; need backpressure & idempotency guarantees

## Key Principles

- **Events**: Past tense (`InvoicePaid`, `SubscriptionActivated`)
- **Handlers**: One effect per handler, idempotent
- **Services**: Publish events for side effects
- **Decoupling**: Keep side effects separate from business logic
- **Upgrade path**: Start with Wisper, escalate to RES when needed

## Naming Conventions

- **Events**: past tense (`InvoicePaid`, `SubscriptionActivated`)
- **Handlers**: `DoXOnY` (`NotifySlackOnApplicantHired`)

## Implementation Checklist

When creating or updating events and handlers, ensure:
- [ ] Use Wisper for in-process pub/sub
- [ ] Make events past tense
- [ ] Make handlers idempotent
- [ ] One handler = one effect
- [ ] Services publish events for side effects
- [ ] Keep side effects separate from business logic
- [ ] Don't put business logic in handlers
- [ ] Don't make handlers dependent on each other
- [ ] Don't process heavy logic synchronously in handlers
