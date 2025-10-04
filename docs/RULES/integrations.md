# Integrations Patterns

This document defines the Gateway pattern for external integrations in the OurGruuv application.

> **See also**: [Overview](../overview.md) | [Services Patterns](./services-patterns.md) | [Forms Patterns](./forms-validation.md)

## Gateway Pattern

**Pattern:** Gateway (app-facing adapter) + Client (HTTP/gem wrapper) + FakeGateway (tests).

Keep OAuth tokens in `ExternalAccount`. Webhooks in `controllers/webhooks/*`.

## Directory Structure

```
app/integrations/
  slack/
    client.rb           # low-level HTTP/gem
    gateway.rb          # app-facing methods; raises Retryable/NonRetryable
    fake_gateway.rb     # used in unit tests
    serializers.rb      # (optional) request/response mapping
  asana/
    client.rb
    gateway.rb
    fake_gateway.rb
  google/
    oauth.rb            # token exchange/refresh helpers
    gateway.rb          # app-facing Google APIs
    fake_gateway.rb
```

## Gateway Example

```ruby
# app/integrations/slack/gateway.rb
class Slack::Gateway
  class RetryableError < StandardError; end
  class NonRetryableError < StandardError; end

  def initialize(client: Slack::Client.new)
    @client = client
  end

  def post_message(channel:, text:, blocks: nil, thread_ts: nil, idempotency_key: nil)
    @client.post("chat.postMessage", channel:, text:, blocks:, thread_ts:,
                 headers: idempotency_key ? {"Idempotency-Key" => idempotency_key} : {})
  rescue Slack::Client::RateLimited => e
    raise RetryableError, e.retry_after_seconds
  rescue Slack::Client::BadRequest => e
    raise NonRetryableError, e.message
  end
end
```

## OAuth Token Management

```ruby
# app/models/external_account.rb
class ExternalAccount < ApplicationRecord
  belongs_to :user
  encrypts :access_token, :refresh_token
  validates :provider, :uid, presence: true
  # columns: provider, uid, user_id, access_token, refresh_token, expires_at, scope
end
```

## Webhook Controllers

```ruby
# app/controllers/webhooks/slack_controller.rb
class Webhooks::SlackController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_signature!

  def create
    ProcessVendorEventJob.perform_later(body: request.body.read, headers: request.headers.to_h)
    head :ok
  end
end
```

## Service Integration

```ruby
# app/services/post_slack_message.rb
class PostSlackMessage
  def self.call(...) = new(...).call

  def initialize(notification_id:, gateway: Slack::Gateway.new)
    @notification_id = notification_id
    @gateway = gateway
  end

  def call
    notification = Notification.find(@notification_id)
    
    ApplicationRecord.transaction do
      response = @gateway.post_message(
        channel: notification.metadata['channel'],
        text: notification.fallback_text,
        blocks: notification.rich_message,
        thread_ts: notification.main_thread&.message_id
      )
      
      notification.update!(
        status: 'sent_successfully',
        message_id: response['ts']
      )
      
      Result.ok(response)
    end
  rescue Slack::Gateway::RetryableError => e
    raise RetryableError, e.message # Let job retry
  rescue Slack::Gateway::NonRetryableError => e
    notification.update!(status: 'send_failed')
    Result.err(e.message)
  end
end
```

## Key Principles

- **Error categorization**: `RetryableError` (429/5xx/timeouts) vs `NonRetryableError` (401/403/422)
- **Separation of concerns**: Gateway handles API, Service handles business logic
- **Testability**: Use fake gateways for unit tests
- **OAuth security**: Encrypt tokens, store in ExternalAccount model
- **Webhook handling**: Process asynchronously, verify signatures

## Implementation Checklist

When creating or updating integrations, ensure:
- [ ] Use Gateway pattern for external API calls
- [ ] Categorize errors as Retryable vs Non-retryable
- [ ] Keep business logic separate from API calls
- [ ] Use fake gateways for testing
- [ ] Handle OAuth tokens in ExternalAccount model
- [ ] Use webhook controllers for incoming events
- [ ] Don't mix API calls with business logic
- [ ] Don't handle all errors the same way
- [ ] Don't access external APIs directly from services
- [ ] Don't store tokens in plain text
- [ ] Don't process webhooks synchronously
