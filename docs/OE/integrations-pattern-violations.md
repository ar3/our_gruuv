# Integrations Pattern Violations

This document tracks violations of the Gateway pattern in the current codebase.

## Pattern Requirements

### Integrations Should:
- Use Gateway pattern for external API calls
- Categorize errors as Retryable vs Non-retryable
- Keep business logic separate from API calls
- Use fake gateways for testing
- Handle OAuth tokens in ExternalAccount model
- Use webhook controllers for incoming events

### Integrations Should NOT:
- Mix API calls with business logic
- Handle all errors the same way
- Access external APIs directly from services
- Store tokens in plain text
- Process webhooks synchronously

## Current Violations

### High Priority Violations

#### 1. SlackService - Gateway Pattern Violation
**File**: `app/services/slack_service.rb`
**Issues**:
- Mixes API calls with business logic
- No error categorization (retryable vs non-retryable)
- Direct Slack API access without Gateway
- Complex error handling mixed with business logic
- Should be split into Slack::Gateway + Service

#### 2. PendoService - Direct API Access
**File**: `app/services/pendo_service.rb`
**Issues**:
- Direct HTTP calls without Gateway pattern
- No error categorization
- Should use Gateway pattern for external API access
- No retry logic for API failures

### Medium Priority Violations

#### 3. SlackChannelsService - Mixed Concerns
**File**: `app/services/slack_channels_service.rb`
**Issues**:
- Calls SlackService directly instead of using Gateway
- Mixed business logic with API calls
- Should use Gateway pattern for Slack API access

## Migration Priority

1. **High Priority**: SlackService (mixed concerns)
2. **Medium Priority**: Other external API integrations
3. **Low Priority**: Simple integrations that work well

## Notes

- Focus on SlackService first (most complex)
- Look for other external API calls
- Consider OAuth token management
- Check for webhook handling patterns
