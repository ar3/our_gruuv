# Slack Integration for Our Gruuv

## Overview

We've successfully set up the foundation for Slack integration in Our Gruuv. This includes:

- **Slack API Client**: Using the `slack-ruby-client` gem
- **Configuration**: Environment-based setup with fallbacks
- **Service Layer**: `SlackService` for all Slack interactions
- **Database Integration**: `slack_channel` field on Huddle model
- **Testing**: Comprehensive test coverage
- **Documentation**: Setup and usage guides

## What's Been Implemented

### 1. Core Infrastructure
- ✅ Slack gem added to Gemfile
- ✅ Slack configuration initializer (`config/initializers/slack.rb`)
- ✅ SlackService for API interactions
- ✅ Database migration for `slack_channel` on Huddles
- ✅ Form integration for setting Slack channels
- ✅ Controller parameter permitting

### 2. API Endpoints
- ✅ `/slack/configuration_status` - Check if Slack is configured
- ✅ `/slack/test_connection` - Test connection to Slack
- ✅ `/slack/list_channels` - List available channels
- ✅ `/slack/post_test_message` - Post a test message

### 3. Message Templates
- ✅ Huddle creation notifications
- ✅ Huddle start notifications
- ✅ Huddle reminder notifications
- ✅ Feedback request notifications
- ✅ Huddle completion notifications

### 4. Testing
- ✅ Unit tests for SlackService
- ✅ Environment configuration tests
- ✅ Message template tests
- ✅ All existing tests still pass

## Next Steps

### Immediate (Ready to Implement)
1. **Automatic Notifications**: Hook into huddle lifecycle events
   - Post notification when huddle is created
   - Send reminders before huddle starts
   - Notify when feedback is requested
   - Share results when huddle completes

2. **Interactive Messages**: Add buttons and actions
   - "Join Huddle" buttons
   - "Submit Feedback" quick actions
   - "View Summary" links

### Future Enhancements
1. **Slash Commands**: Create huddles directly from Slack
2. **User Authentication**: OAuth flow for Slack users
3. **Real-time Updates**: WebSocket integration for live updates
4. **Channel Management**: Auto-create channels for teams
5. **Advanced Notifications**: Custom notification schedules

## Setup Instructions

### 1. Create Slack App
1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. Create new app from scratch
3. Add required bot token scopes:
   - `chat:write`
   - `chat:write.public`
   - `channels:read`
   - `users:read`
   - `users:read.email`

### 2. Install App
1. Go to OAuth & Permissions
2. Install to workspace
3. Copy bot token (starts with `xoxb-`)

### 3. Environment Variables
```bash
# Required
SLACK_BOT_TOKEN=xoxb-your-bot-token-here

# Optional (with defaults)
SLACK_DEFAULT_CHANNEL=#general
SLACK_BOT_USERNAME=Huddle Bot
SLACK_BOT_EMOJI=:huddle:
```

### 4. Test Integration
```bash
# Check configuration
curl http://localhost:3000/slack/configuration_status

# Test connection
curl http://localhost:3000/slack/test_connection

# List channels
curl http://localhost:3000/slack/list_channels

# Post test message
curl -X POST http://localhost:3000/slack/post_test_message \
  -H "Content-Type: application/json" \
  -d '{"channel": "#general", "message": "Test from Our Gruuv!"}'
```

## Files Created/Modified

### New Files
- `config/initializers/slack.rb` - Slack configuration
- `app/services/slack_service.rb` - Slack API service
- `app/controllers/slack_controller.rb` - Testing endpoints
- `spec/services/slack_service_spec.rb` - Service tests
- `docs/SLACK_INTEGRATION.md` - Detailed documentation

### Modified Files
- `Gemfile` - Added slack-ruby-client gem
- `config/routes.rb` - Added Slack routes
- `app/views/huddles/new.html.haml` - Added Slack channel field
- `app/controllers/huddles_controller.rb` - Permitted slack_channel parameter
- `db/migrate/*_add_slack_channel_to_huddles.rb` - Database migration

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Huddle Form   │───▶│  HuddlesController│───▶│   SlackService  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │   Huddle Model   │    │  Slack API      │
                       │ (slack_channel)  │    │  (slack-ruby-   │
                       └──────────────────┘    │   client)       │
                                               └─────────────────┘
```

## Security Considerations

- ✅ Bot tokens stored as environment variables
- ✅ Minimal required permissions
- ✅ Error handling prevents sensitive data leakage
- ✅ All API calls logged for debugging
- ✅ Graceful fallbacks when Slack is not configured

## Performance Notes

- Slack API calls are made synchronously (can be optimized later)
- No caching implemented yet (can add Redis caching)
- Rate limiting handled by slack-ruby-client gem
- Error handling prevents cascading failures

## Troubleshooting

### Common Issues
1. **"Slack bot token not configured"**
   - Check `SLACK_BOT_TOKEN` environment variable
   - Verify token starts with `xoxb-`

2. **"Failed to connect to Slack"**
   - Verify app is installed in workspace
   - Check required scopes are granted
   - Ensure token is valid

3. **"Failed to post message"**
   - Bot must be invited to target channel
   - Channel name must include `#` for public channels
   - Verify `chat:write` permission

### Debug Mode
Enable debug logging by setting Rails environment to development. The Slack service will log all API calls and responses. 