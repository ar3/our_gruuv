# Slack Integration

This document outlines the Slack integration setup and usage for Our Gruuv.

## Setup

### 1. Create a Slack App

1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. Click "Create New App" → "From scratch"
3. Name your app (e.g., "Our Gruuv Huddle Bot")
4. Select your workspace

### 2. Configure Bot Token Scopes

In your Slack app settings, add the following OAuth scopes:

**Bot Token Scopes:**
- `chat:write` - Post messages to channels
- `chat:write.public` - Post to public channels
- `channels:read` - View basic channel info
- `users:read` - View basic user info
- `users:read.email` - View user email addresses

### 3. Install the App

1. Go to "OAuth & Permissions" in your app settings
2. Click "Install to Workspace"
3. Authorize the app
4. Copy the "Bot User OAuth Token" (starts with `xoxb-`)

### 4. Environment Variables

Add the following environment variables:

```bash
# Required
SLACK_BOT_TOKEN=xoxb-your-bot-token-here

# Optional (with defaults)
SLACK_DEFAULT_CHANNEL=#general
SLACK_BOT_USERNAME=Huddle Bot
SLACK_BOT_EMOJI=:huddle:
```

## Usage

### Testing the Integration

Use the following endpoints to test your Slack integration:

- `GET /slack/configuration_status` - Check if Slack is configured
- `GET /slack/test_connection` - Test connection to Slack
- `GET /slack/list_channels` - List available channels
- `POST /slack/post_test_message` - Post a test message

### Huddle Notifications

When creating a huddle, you can specify a Slack channel where notifications will be posted. If no channel is specified, the default channel will be used.

### Message Templates

The following notification types are available:

- `huddle_created` - When a new huddle is created
- `huddle_started` - When a huddle is starting
- `huddle_reminder` - Reminder before huddle starts
- `feedback_requested` - When feedback is requested
- `huddle_completed` - When a huddle is completed

## Integration Points

### Huddle Creation

When a huddle is created, you can specify a Slack channel in the form. This channel will be used for all notifications related to that huddle.

### Automatic Notifications

The system can automatically post notifications for:
- Huddle creation
- Huddle start reminders
- Feedback requests
- Huddle completion with results

## Security

- Bot tokens are stored as environment variables
- The bot only has the minimum required permissions
- All API calls are logged for debugging
- Error handling prevents sensitive information leakage

## Troubleshooting

### Common Issues

1. **"Slack bot token not configured"**
   - Ensure `SLACK_BOT_TOKEN` environment variable is set
   - Verify the token starts with `xoxb-`

2. **"Failed to connect to Slack"**
   - Check if the bot token is valid
   - Verify the app is installed in your workspace
   - Check if the required scopes are granted

3. **"Failed to post message"**
   - Ensure the bot is invited to the target channel
   - Check if the channel name is correct (include `#` for public channels)
   - Verify the bot has `chat:write` permission

### Debugging

Enable debug logging by setting the Rails environment to development. The Slack service will log all API calls and responses.

## Future Enhancements

- Interactive message buttons for quick actions
- Slash commands for creating huddles
- User authentication via Slack OAuth
- Real-time message updates
- Channel-specific settings per organization 